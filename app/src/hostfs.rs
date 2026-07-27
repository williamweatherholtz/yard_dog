//! Host-filesystem probing for bind/network mounts: existence, directory-vs-file
//! type, and ownership/permissions — all behind the [`HostFs`] trait so the
//! logic is testable against fixtures. The real implementation is strictly
//! read-only: Yard Dog NEVER creates a missing host path (the Portainer footgun).

/// What a host path currently is on disk.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PathKind {
    Directory,
    File,
    Symlink,
    Other,
    Missing,
}

/// Ownership and permission bits of a host path (POSIX).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PathMeta {
    pub uid: u32,
    pub gid: u32,
    pub mode: u32,
}

/// Read-only host-filesystem access. Implementors MUST NOT create or mutate.
pub trait HostFs {
    fn kind(&self, path: &str) -> PathKind;
    fn metadata(&self, path: &str) -> Option<PathMeta>;
}

/// Whether a resolved host path exists and what it currently is.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExistenceReport {
    pub exists: bool,
    pub kind: PathKind,
}

/// Report a host path's existence and kind — a pure read, never a creation.
pub fn check_existence(source: &str, fs: &dyn HostFs) -> ExistenceReport {
    let kind = fs.kind(source);
    ExistenceReport {
        exists: kind != PathKind::Missing,
        kind,
    }
}

/// The real, read-only host filesystem (uses `symlink_metadata`, never follows
/// into creation). Ownership/permission bits are POSIX-only.
pub struct RealFs;

impl HostFs for RealFs {
    fn kind(&self, path: &str) -> PathKind {
        match std::fs::symlink_metadata(path) {
            Err(_) => PathKind::Missing,
            Ok(m) => {
                let ft = m.file_type();
                if ft.is_symlink() {
                    PathKind::Symlink
                } else if ft.is_dir() {
                    PathKind::Directory
                } else if ft.is_file() {
                    PathKind::File
                } else {
                    PathKind::Other
                }
            }
        }
    }

    fn metadata(&self, path: &str) -> Option<PathMeta> {
        let m = std::fs::symlink_metadata(path).ok()?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::MetadataExt;
            Some(PathMeta {
                uid: m.uid(),
                gid: m.gid(),
                mode: m.mode(),
            })
        }
        #[cfg(not(unix))]
        {
            let _ = m; // ownership bits are POSIX-only
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    struct StubFs {
        kinds: HashMap<String, PathKind>,
    }
    impl HostFs for StubFs {
        fn kind(&self, path: &str) -> PathKind {
            self.kinds.get(path).copied().unwrap_or(PathKind::Missing)
        }
        fn metadata(&self, _path: &str) -> Option<PathMeta> {
            None
        }
    }

    #[test]
    fn reports_existence_and_kind() {
        let fs = StubFs {
            kinds: HashMap::from([("/srv/data".to_string(), PathKind::Directory)]),
        };

        let present = check_existence("/srv/data", &fs);
        assert!(present.exists);
        assert_eq!(present.kind, PathKind::Directory);

        let absent = check_existence("/srv/missing", &fs);
        assert!(!absent.exists, "a missing path must be reported as absent");
        assert_eq!(absent.kind, PathKind::Missing);
    }

    #[test]
    fn never_creates_a_missing_path() {
        let dir = tempfile::tempdir().unwrap();
        let missing = dir.path().join("does-not-exist");
        let missing_str = missing.to_str().unwrap();

        let report = check_existence(missing_str, &RealFs);

        assert!(!report.exists);
        assert_eq!(report.kind, PathKind::Missing);
        assert!(
            !missing.exists(),
            "check_existence must not create the host path"
        );

        // and an existing directory is reported as such
        let here = check_existence(dir.path().to_str().unwrap(), &RealFs);
        assert!(here.exists);
        assert_eq!(here.kind, PathKind::Directory);
    }
}
