//! Safe deployment: run a pre-change backup, snapshot the config in git, deploy,
//! and roll back to the previous last-good commit if the deploy fails. Config
//! versioning is delegated to `gitver` (decGitVersioning); Deployer and
//! BackupHook are traits so the orchestration is testable without Docker.

use crate::flow::{self, Change, Outcome};
use std::io;
use std::path::Path;

/// Applies a stack (e.g. `docker compose up`). `Ok` = healthy, `Err` = failed.
pub trait Deployer {
    fn deploy(&self, stack_dir: &Path) -> io::Result<()>;
}

/// Takes a recovery point before a change is applied.
pub trait BackupHook {
    fn pre_change_backup(&self, stack_dir: &Path) -> io::Result<()>;
}

/// The result of a safe-deploy attempt.
#[derive(Debug, PartialEq, Eq)]
pub enum DeployOutcome {
    Deployed,
    RolledBack,
    /// Deploy failed and the rollback redeploy also failed — needs attention.
    RollbackFailed(String),
    Skipped,
    Blocked(String),
    BackupFailed(String),
}

/// Deploy safely: only when `confirmed`; run guardrails, back up first (abort if
/// that fails), snapshot the config in the git repo `repo_dir`, health-gate the
/// deploy, and on failure restore the prior last-good commit. A thin adapter
/// over the shared lifecycle FSM (`flow::run`) — a deploy is an upgrade with no
/// image change, always accepted when healthy (see issDeployDup).
pub fn safe_deploy(
    compose_path: &Path,
    repo_dir: &Path,
    confirmed: bool,
    backup: &dyn BackupHook,
    deployer: &dyn Deployer,
) -> io::Result<DeployOutcome> {
    let change = Change {
        compose_path,
        repo: repo_dir,
        image_change: None,
        confirmed,
        accept: true,
    };
    let mut trace = Vec::new();
    Ok(match flow::run(&change, backup, deployer, &mut trace)? {
        Outcome::Deployed | Outcome::Upgraded => DeployOutcome::Deployed,
        Outcome::Regressed(_) => DeployOutcome::RolledBack,
        Outcome::RegressFailed(r) => DeployOutcome::RollbackFailed(r),
        Outcome::Skipped => DeployOutcome::Skipped,
        Outcome::Blocked(r) => DeployOutcome::Blocked(r),
        Outcome::BackupFailed(r) => DeployOutcome::BackupFailed(r),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::gitver;
    use std::cell::RefCell;

    struct OkDeployer;
    impl Deployer for OkDeployer {
        fn deploy(&self, _d: &Path) -> io::Result<()> {
            Ok(())
        }
    }
    /// Fails the first deploy (the health-gate), then succeeds — so the rollback
    /// redeploy after a regress goes through.
    #[derive(Default)]
    struct FailThenOkDeployer {
        failed_once: RefCell<bool>,
    }
    impl Deployer for FailThenOkDeployer {
        fn deploy(&self, _d: &Path) -> io::Result<()> {
            let mut f = self.failed_once.borrow_mut();
            if *f {
                Ok(())
            } else {
                *f = true;
                Err(io::Error::new(io::ErrorKind::Other, "unhealthy"))
            }
        }
    }
    #[derive(Default)]
    struct SpyDeployer {
        called: RefCell<bool>,
    }
    impl Deployer for SpyDeployer {
        fn deploy(&self, _d: &Path) -> io::Result<()> {
            *self.called.borrow_mut() = true;
            Ok(())
        }
    }
    #[derive(Default)]
    struct RecBackup {
        called: RefCell<bool>,
    }
    impl BackupHook for RecBackup {
        fn pre_change_backup(&self, _d: &Path) -> io::Result<()> {
            *self.called.borrow_mut() = true;
            Ok(())
        }
    }
    struct FailBackup;
    impl BackupHook for FailBackup {
        fn pre_change_backup(&self, _d: &Path) -> io::Result<()> {
            Err(io::Error::new(io::ErrorKind::Other, "backup failed"))
        }
    }

    fn repo() -> (tempfile::TempDir, std::path::PathBuf) {
        let dir = tempfile::tempdir().unwrap();
        gitver::init(dir.path()).unwrap();
        let compose = dir.path().join("docker-compose.yml");
        (dir, compose)
    }

    #[test]
    fn success_snapshots_and_backs_up() {
        let (dir, compose) = repo();
        std::fs::write(&compose, "v1").unwrap();
        let backup = RecBackup::default();
        let out = safe_deploy(&compose, dir.path(), true, &backup, &OkDeployer).unwrap();
        assert_eq!(out, DeployOutcome::Deployed);
        assert!(*backup.called.borrow(), "pre-change backup must run");
        assert_eq!(gitver::history(dir.path()).unwrap().len(), 1);
    }

    #[test]
    fn failure_rolls_back_to_last_good() {
        let (dir, compose) = repo();
        std::fs::write(&compose, "good").unwrap();
        gitver::snapshot(dir.path(), "good").unwrap();
        std::fs::write(&compose, "broken").unwrap();

        let out = safe_deploy(&compose, dir.path(), true, &RecBackup::default(), &FailThenOkDeployer::default()).unwrap();
        assert_eq!(out, DeployOutcome::RolledBack);
        assert_eq!(
            std::fs::read_to_string(&compose).unwrap(),
            "good",
            "a failed deploy must restore the last-good config"
        );
    }

    #[test]
    fn backup_failure_aborts_before_deploy() {
        let (dir, compose) = repo();
        std::fs::write(&compose, "v1").unwrap();
        let spy = SpyDeployer::default();
        let out = safe_deploy(&compose, dir.path(), true, &FailBackup, &spy).unwrap();
        assert!(matches!(out, DeployOutcome::BackupFailed(_)));
        assert!(!*spy.called.borrow(), "deploy must not run if backup failed");
    }

    #[test]
    fn skipped_without_confirmation() {
        let (dir, compose) = repo();
        std::fs::write(&compose, "v1").unwrap();
        let out = safe_deploy(&compose, dir.path(), false, &RecBackup::default(), &OkDeployer).unwrap();
        assert_eq!(out, DeployOutcome::Skipped);
        assert!(gitver::history(dir.path()).unwrap_or_default().is_empty());
    }
}
