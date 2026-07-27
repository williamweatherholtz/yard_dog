//! Ownership / permission analysis for host bind paths.
//!
//! Surfaces the two most-reported self-hosting footguns: a **root-owned** bind
//! directory (which a non-root container cannot write) and a **PUID/PGID
//! mismatch** between the path's owner and the identity the container runs as.

use crate::hostfs::PathMeta;

/// A single ownership/permission problem found on a bind path.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OwnershipIssue {
    /// The path is owned by root (uid 0) — breaks non-root containers.
    RootOwned,
    /// The path's owner uid differs from the container's expected PUID.
    UidMismatch { found: u32, expected: u32 },
    /// The path's owner gid differs from the container's expected PGID.
    GidMismatch { found: u32, expected: u32 },
}

/// Analyse a path's ownership against the container's expected PUID/PGID.
///
/// `expected` is `Some((puid, pgid))` when the stack declares them (e.g. the
/// LinuxServer PUID/PGID env vars); `None` when unknown.
pub fn detect_ownership(meta: &PathMeta, expected: Option<(u32, u32)>) -> Vec<OwnershipIssue> {
    let mut issues = Vec::new();
    if meta.uid == 0 {
        issues.push(OwnershipIssue::RootOwned);
    }
    if let Some((puid, pgid)) = expected {
        if meta.uid != puid {
            issues.push(OwnershipIssue::UidMismatch {
                found: meta.uid,
                expected: puid,
            });
        }
        if meta.gid != pgid {
            issues.push(OwnershipIssue::GidMismatch {
                found: meta.gid,
                expected: pgid,
            });
        }
    }
    issues
}

#[cfg(test)]
mod tests {
    use super::*;

    fn meta(uid: u32, gid: u32) -> PathMeta {
        PathMeta {
            uid,
            gid,
            mode: 0o755,
        }
    }

    #[test]
    fn flags_root_owned_directory() {
        let issues = detect_ownership(&meta(0, 0), None);
        assert_eq!(issues, vec![OwnershipIssue::RootOwned]);
    }

    #[test]
    fn clean_when_owner_matches_expected() {
        let issues = detect_ownership(&meta(1000, 1000), Some((1000, 1000)));
        assert!(issues.is_empty());
    }

    #[test]
    fn flags_puid_pgid_mismatch() {
        let issues = detect_ownership(&meta(1000, 1000), Some((1000, 100)));
        assert_eq!(
            issues,
            vec![OwnershipIssue::GidMismatch {
                found: 1000,
                expected: 100
            }]
        );
    }

    #[test]
    fn root_owned_and_mismatched_reports_all() {
        let issues = detect_ownership(&meta(0, 0), Some((1000, 1000)));
        assert_eq!(
            issues,
            vec![
                OwnershipIssue::RootOwned,
                OwnershipIssue::UidMismatch {
                    found: 0,
                    expected: 1000
                },
                OwnershipIssue::GidMismatch {
                    found: 0,
                    expected: 1000
                },
            ]
        );
    }
}
