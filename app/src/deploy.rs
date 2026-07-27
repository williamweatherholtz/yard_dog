//! Safe deployment: snapshot the config, run a pre-change backup hook, deploy,
//! and roll back to the previous last-good config if the deploy fails. The
//! Deployer and BackupHook are traits so the orchestration is testable without
//! Docker.

use crate::stacks::{list_history, rollback_config, snapshot_config};
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
    Skipped,
    BackupFailed(String),
}

/// Deploy safely: only when `confirmed`; back up first (abort if that fails),
/// snapshot the config, deploy, and roll back to the prior version on failure.
pub fn safe_deploy(
    compose_path: &Path,
    history_dir: &Path,
    confirmed: bool,
    backup: &dyn BackupHook,
    deployer: &dyn Deployer,
) -> io::Result<DeployOutcome> {
    if !confirmed {
        return Ok(DeployOutcome::Skipped);
    }
    let stack_dir = compose_path.parent().unwrap_or_else(|| Path::new("."));

    // Recovery point first — abort if it fails.
    if let Err(e) = backup.pre_change_backup(stack_dir) {
        return Ok(DeployOutcome::BackupFailed(e.to_string()));
    }

    // Remember the prior last-good, then snapshot the config being deployed.
    let prior = list_history(history_dir)?.first().cloned();
    let _version = snapshot_config(compose_path, history_dir)?;

    match deployer.deploy(stack_dir) {
        Ok(()) => Ok(DeployOutcome::Deployed),
        Err(_) => {
            if let Some(good) = prior {
                rollback_config(history_dir, &good, compose_path, true)?;
            }
            Ok(DeployOutcome::RolledBack)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;

    struct OkDeployer;
    impl Deployer for OkDeployer {
        fn deploy(&self, _d: &Path) -> io::Result<()> {
            Ok(())
        }
    }
    struct FailDeployer;
    impl Deployer for FailDeployer {
        fn deploy(&self, _d: &Path) -> io::Result<()> {
            Err(io::Error::new(io::ErrorKind::Other, "unhealthy"))
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

    #[test]
    fn success_snapshots_and_backs_up() {
        let dir = tempfile::tempdir().unwrap();
        let compose = dir.path().join("docker-compose.yml");
        std::fs::write(&compose, "v1").unwrap();
        let history = dir.path().join(".history");
        let backup = RecBackup::default();

        let out = safe_deploy(&compose, &history, true, &backup, &OkDeployer).unwrap();
        assert_eq!(out, DeployOutcome::Deployed);
        assert!(*backup.called.borrow(), "pre-change backup must run");
        assert_eq!(list_history(&history).unwrap(), vec!["1"]);
    }

    #[test]
    fn failure_rolls_back_to_last_good() {
        let dir = tempfile::tempdir().unwrap();
        let compose = dir.path().join("docker-compose.yml");
        std::fs::write(&compose, "good").unwrap();
        let history = dir.path().join(".history");
        snapshot_config(&compose, &history).unwrap(); // version 1 = "good"
        std::fs::write(&compose, "broken").unwrap();

        let out = safe_deploy(&compose, &history, true, &RecBackup::default(), &FailDeployer).unwrap();
        assert_eq!(out, DeployOutcome::RolledBack);
        assert_eq!(
            std::fs::read_to_string(&compose).unwrap(),
            "good",
            "a failed deploy must restore the last-good config"
        );
    }

    #[test]
    fn backup_failure_aborts_before_deploy() {
        let dir = tempfile::tempdir().unwrap();
        let compose = dir.path().join("docker-compose.yml");
        std::fs::write(&compose, "v1").unwrap();
        let history = dir.path().join(".history");
        let spy = SpyDeployer::default();

        let out = safe_deploy(&compose, &history, true, &FailBackup, &spy).unwrap();
        assert!(matches!(out, DeployOutcome::BackupFailed(_)));
        assert!(!*spy.called.borrow(), "deploy must not run if backup failed");
    }

    #[test]
    fn skipped_without_confirmation() {
        let dir = tempfile::tempdir().unwrap();
        let compose = dir.path().join("docker-compose.yml");
        std::fs::write(&compose, "v1").unwrap();
        let history = dir.path().join(".history");
        let out = safe_deploy(&compose, &history, false, &RecBackup::default(), &OkDeployer).unwrap();
        assert_eq!(out, DeployOutcome::Skipped);
        assert!(list_history(&history).unwrap().is_empty());
    }
}
