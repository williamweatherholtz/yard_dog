//! Turn detected path problems into ranked, **print-only** remediation
//! suggestions. Yard Dog never applies a fix implicitly here — it proposes,
//! ranked best-first, and (in a later increment) applies only on explicit
//! operator confirmation. This module is the preventative-guidance core.

use crate::hostfs::PathKind;
use crate::ownership::OwnershipIssue;

/// A detected problem with a mount's host path.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Issue {
    /// The host path does not exist.
    MissingPath { path: String },
    /// The host path exists but is the wrong kind for the mount.
    TypeMismatch {
        path: String,
        found: PathKind,
        expected_dir: bool,
    },
    /// An ownership/permission problem on the host path.
    Ownership { issue: OwnershipIssue, path: String },
}

/// A single suggested fix. `command` is a suggestion to show the operator —
/// never executed by this module.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Remediation {
    /// 1 = best; strictly increasing within a suggestion list.
    pub rank: u8,
    pub summary: String,
    pub command: Option<String>,
}

/// Produce ranked, print-only remediation suggestions for an issue.
pub fn remediations_for(issue: &Issue) -> Vec<Remediation> {
    match issue {
        Issue::MissingPath { path } => ranked(vec![
            (
                format!("Create {path} yourself with the container's owner — Yard Dog will not create it for you"),
                Some(format!("mkdir -p {path} && sudo chown <PUID>:<PGID> {path}")),
            ),
            (
                "If the source path is a typo, correct it in the compose file".to_string(),
                None,
            ),
        ]),
        Issue::TypeMismatch {
            path,
            found,
            expected_dir,
        } => {
            let want = if *expected_dir { "directory" } else { "file" };
            let got = kind_word(*found);
            ranked(vec![
                (
                    format!("The mount expects a {want} but {path} is a {got}; remove or rename it and recreate it as a {want}"),
                    Some(format!("mv {path} {path}.bak")),
                ),
                (
                    format!("Or change the compose mount so its target matches a {got}"),
                    None,
                ),
            ])
        }
        Issue::Ownership { issue, path } => match issue {
            OwnershipIssue::RootOwned => ranked(vec![
                (
                    format!("{path} is root-owned; chown it to the container's PUID/PGID so a non-root process can write"),
                    Some(format!("sudo chown <PUID>:<PGID> {path}")),
                ),
                (
                    "Or run the container as root (not recommended)".to_string(),
                    None,
                ),
            ]),
            OwnershipIssue::UidMismatch { found, expected } => ranked(vec![(
                format!("Owner uid {found} does not match the container PUID {expected}; align them"),
                Some(format!("sudo chown {expected} {path}")),
            )]),
            OwnershipIssue::GidMismatch { found, expected } => ranked(vec![(
                format!("Owner gid {found} does not match the container PGID {expected}; align them"),
                Some(format!("sudo chgrp {expected} {path}")),
            )]),
        },
    }
}

fn ranked(items: Vec<(String, Option<String>)>) -> Vec<Remediation> {
    items
        .into_iter()
        .enumerate()
        .map(|(i, (summary, command))| Remediation {
            rank: (i + 1) as u8,
            summary,
            command,
        })
        .collect()
}

fn kind_word(kind: PathKind) -> &'static str {
    match kind {
        PathKind::Directory => "directory",
        PathKind::File => "file",
        PathKind::Symlink => "symlink",
        PathKind::Other => "special file",
        PathKind::Missing => "missing",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_path_suggests_creation_with_owner() {
        let r = remediations_for(&Issue::MissingPath {
            path: "/srv/data".into(),
        });
        assert!(!r.is_empty());
        assert_eq!(r[0].rank, 1);
        assert!(r[0].summary.to_lowercase().contains("create"));
        assert!(r[0].command.as_ref().unwrap().contains("/srv/data"));
    }

    #[test]
    fn root_owned_suggests_chown() {
        let r = remediations_for(&Issue::Ownership {
            issue: OwnershipIssue::RootOwned,
            path: "/srv/data".into(),
        });
        assert!(r
            .iter()
            .any(|x| x.command.as_deref().map_or(false, |c| c.contains("chown"))));
    }

    #[test]
    fn type_mismatch_calls_out_the_conflict() {
        let r = remediations_for(&Issue::TypeMismatch {
            path: "/srv/conf".into(),
            found: PathKind::Directory,
            expected_dir: false,
        });
        assert!(!r.is_empty());
        let s = r[0].summary.to_lowercase();
        assert!(s.contains("file") && s.contains("director"));
    }

    #[test]
    fn suggestions_are_ranked_from_one() {
        let r = remediations_for(&Issue::MissingPath { path: "/x".into() });
        for (i, rem) in r.iter().enumerate() {
            assert_eq!(rem.rank as usize, i + 1);
        }
    }
}
