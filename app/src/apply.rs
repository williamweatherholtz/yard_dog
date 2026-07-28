//! Applying a remediation to the host filesystem — but ONLY on explicit
//! confirmation. Mutating operations sit behind [`HostFsMut`] so the
//! confirmation gate and action dispatch are unit-testable without touching the
//! real filesystem. Yard Dog never mutates a host path without confirmation.

use crate::remediation::Issue;
use std::io;

/// A concrete, applicable fix.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FixAction {
    CreateDir {
        path: String,
        owner: Option<(u32, u32)>,
    },
    Chown {
        path: String,
        uid: u32,
        gid: u32,
    },
    Chmod {
        path: String,
        mode: u32,
    },
}

/// Result of an apply attempt.
#[derive(Debug, PartialEq, Eq)]
pub enum ApplyOutcome {
    Applied,
    /// Not confirmed — nothing was done.
    Skipped,
    Failed(String),
}

/// Mutating host-filesystem operations. Implementors perform real side effects.
pub trait HostFsMut {
    fn create_dir(&self, path: &str, owner: Option<(u32, u32)>) -> io::Result<()>;
    fn chown(&self, path: &str, uid: u32, gid: u32) -> io::Result<()>;
    fn chmod(&self, path: &str, mode: u32) -> io::Result<()>;
}

/// Apply `action` — but only when `confirmed`. Without confirmation the function
/// performs no side effect and returns [`ApplyOutcome::Skipped`].
/// Critical system paths yd will never create/chown/chmod, even on explicit
/// confirmation — a typo or hostile compose naming `/etc` as a bind source must
/// not let `yd fix` chown it. Exact-match only, so legitimate data binds under a
/// subpath (e.g. `/etc/myapp`, `/srv/data`, `/var/lib/x`) are unaffected.
const PROTECTED_PATHS: &[&str] = &[
    "/", "/etc", "/usr", "/bin", "/sbin", "/boot", "/lib", "/lib64", "/sys",
    "/proc", "/dev", "/run", "/var/run", "/root", "/usr/bin", "/usr/sbin", "/usr/lib",
];

fn action_path(a: &FixAction) -> &str {
    match a {
        FixAction::CreateDir { path, .. }
        | FixAction::Chown { path, .. }
        | FixAction::Chmod { path, .. } => path,
    }
}

/// True for a critical system root. Normalises separators AND lexically resolves
/// `.`/`..`/duplicate slashes first, so `/etc/.`, `//etc`, and `/etc/../etc` are
/// all recognised as `/etc` (the string-level bypass the first version missed).
pub fn is_protected_path(path: &str) -> bool {
    let s = path.replace('\\', "/");
    let mut parts: Vec<&str> = Vec::new();
    for seg in s.split('/') {
        match seg {
            "" | "." => {}            // dedupe slashes, drop current-dir
            ".." => {
                parts.pop();
            } // resolve parent lexically
            _ => parts.push(seg),
        }
    }
    let norm = format!("/{}", parts.join("/"));
    PROTECTED_PATHS.contains(&norm.as_str())
}

pub fn apply_fix(action: &FixAction, confirmed: bool, fs: &dyn HostFsMut) -> ApplyOutcome {
    if !confirmed {
        return ApplyOutcome::Skipped;
    }
    let path = action_path(action);
    if is_protected_path(path) {
        return ApplyOutcome::Failed(format!("refusing to modify protected system path {path}"));
    }
    let result = match action {
        FixAction::CreateDir { path, owner } => fs.create_dir(path, *owner),
        FixAction::Chown { path, uid, gid } => fs.chown(path, *uid, *gid),
        FixAction::Chmod { path, mode } => fs.chmod(path, *mode),
    };
    match result {
        Ok(()) => ApplyOutcome::Applied,
        Err(e) => ApplyOutcome::Failed(e.to_string()),
    }
}

/// Derive the concrete fix action(s) for a detected issue. `expected` is the
/// container's `(PUID, PGID)` when known. Type mismatches have no safe automatic
/// action (the operator must decide) and return none.
pub fn actions_for(issue: &Issue, expected: Option<(u32, u32)>) -> Vec<FixAction> {
    match issue {
        Issue::MissingPath { path } => vec![FixAction::CreateDir {
            path: path.clone(),
            owner: expected,
        }],
        Issue::Ownership { issue: _, path } => match expected {
            Some((uid, gid)) => vec![FixAction::Chown {
                path: path.clone(),
                uid,
                gid,
            }],
            None => Vec::new(),
        },
        Issue::TypeMismatch { .. } => Vec::new(),
    }
}

/// The real mutating filesystem. Ownership/permission ops are POSIX-only.
pub struct RealFsMut;

/// Refuse to mutate a path whose final component is a symlink. chown/chmod follow
/// symlinks at the OS level, so a bind source replaced by a symlink → /etc would
/// let a confirmed `yd fix` chown the target and slip past the (string-based)
/// protected-path guard. The fix path should only touch real data dirs/files.
#[cfg(unix)]
fn refuse_symlink(path: &str) -> io::Result<()> {
    match std::fs::symlink_metadata(path) {
        Ok(m) if m.file_type().is_symlink() => Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            format!("refusing to modify {path}: it is a symlink (would follow to its target)"),
        )),
        _ => Ok(()),
    }
}

impl HostFsMut for RealFsMut {
    fn create_dir(&self, path: &str, owner: Option<(u32, u32)>) -> io::Result<()> {
        std::fs::create_dir_all(path)?;
        #[cfg(unix)]
        if let Some((uid, gid)) = owner {
            refuse_symlink(path)?;
            std::os::unix::fs::chown(path, Some(uid), Some(gid))?;
        }
        #[cfg(not(unix))]
        let _ = owner;
        Ok(())
    }

    fn chown(&self, path: &str, uid: u32, gid: u32) -> io::Result<()> {
        #[cfg(unix)]
        {
            refuse_symlink(path)?;
            std::os::unix::fs::chown(path, Some(uid), Some(gid))
        }
        #[cfg(not(unix))]
        {
            let _ = (path, uid, gid);
            Err(io::Error::new(
                io::ErrorKind::Unsupported,
                "chown is POSIX-only",
            ))
        }
    }

    fn chmod(&self, path: &str, mode: u32) -> io::Result<()> {
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            refuse_symlink(path)?;
            std::fs::set_permissions(path, std::fs::Permissions::from_mode(mode))
        }
        #[cfg(not(unix))]
        {
            let _ = (path, mode);
            Err(io::Error::new(
                io::ErrorKind::Unsupported,
                "chmod is POSIX-only",
            ))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ownership::OwnershipIssue;
    use std::cell::RefCell;

    #[derive(Default)]
    struct RecordingFs {
        calls: RefCell<Vec<String>>,
    }
    impl HostFsMut for RecordingFs {
        fn create_dir(&self, path: &str, owner: Option<(u32, u32)>) -> io::Result<()> {
            self.calls
                .borrow_mut()
                .push(format!("create_dir {path} {owner:?}"));
            Ok(())
        }
        fn chown(&self, path: &str, uid: u32, gid: u32) -> io::Result<()> {
            self.calls
                .borrow_mut()
                .push(format!("chown {path} {uid}:{gid}"));
            Ok(())
        }
        fn chmod(&self, path: &str, mode: u32) -> io::Result<()> {
            self.calls
                .borrow_mut()
                .push(format!("chmod {path} {mode:o}"));
            Ok(())
        }
    }

    #[test]
    fn missing_path_maps_to_create_dir_with_owner() {
        let action = actions_for(
            &Issue::MissingPath {
                path: "/srv/data".into(),
            },
            Some((1000, 1000)),
        );
        assert_eq!(
            action,
            vec![FixAction::CreateDir {
                path: "/srv/data".into(),
                owner: Some((1000, 1000)),
            }]
        );
    }

    #[test]
    fn root_owned_maps_to_chown_when_ids_known() {
        let action = actions_for(
            &Issue::Ownership {
                issue: OwnershipIssue::RootOwned,
                path: "/srv/data".into(),
            },
            Some((1000, 1000)),
        );
        assert_eq!(
            action,
            vec![FixAction::Chown {
                path: "/srv/data".into(),
                uid: 1000,
                gid: 1000,
            }]
        );
    }

    #[test]
    fn refuses_protected_system_paths_even_when_confirmed() {
        let fs = RecordingFs::default();
        // includes non-canonical bypass forms that the string-match missed before
        for p in ["/etc", "/", "/var/run", "/usr/bin", "/etc/", "/etc/.", "//etc", "/etc/../etc", "/./etc", "/etc/../.."] {
            let action = FixAction::Chown { path: p.into(), uid: 0, gid: 0 };
            assert!(
                matches!(apply_fix(&action, true, &fs), ApplyOutcome::Failed(_)),
                "must refuse {p}"
            );
        }
        assert!(fs.calls.borrow().is_empty(), "no fs call for a protected path");
        // a legitimate data subpath is still allowed
        assert!(is_protected_path("/etc"));
        assert!(!is_protected_path("/etc/myapp"));
        assert!(!is_protected_path("/srv/data"));
        assert!(!is_protected_path("/var/lib/postgresql"));
    }

    #[test]
    fn does_nothing_without_confirmation() {
        let fs = RecordingFs::default();
        let action = FixAction::Chown {
            path: "/srv/data".into(),
            uid: 1000,
            gid: 1000,
        };
        let outcome = apply_fix(&action, false, &fs);
        assert_eq!(outcome, ApplyOutcome::Skipped);
        assert!(
            fs.calls.borrow().is_empty(),
            "no filesystem action may happen without confirmation"
        );
    }

    #[test]
    fn applies_the_action_when_confirmed() {
        let fs = RecordingFs::default();
        let action = FixAction::Chown {
            path: "/srv/data".into(),
            uid: 1000,
            gid: 1000,
        };
        let outcome = apply_fix(&action, true, &fs);
        assert_eq!(outcome, ApplyOutcome::Applied);
        assert_eq!(fs.calls.borrow().as_slice(), ["chown /srv/data 1000:1000"]);
    }
}
