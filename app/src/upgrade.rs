//! One-shot safe upgrade: back up, snapshot config in git, set the target image,
//! deploy, then regress on a failed healthcheck — and on a passing one either
//! accept or regress if not accepted. Composes the backup, gitver, and deploy
//! primitives; the Deployer/BackupHook traits keep it testable without Docker.

use crate::deploy::{BackupHook, Deployer};
use crate::gitver;
use std::io;
use std::path::Path;

#[derive(Debug, PartialEq, Eq)]
pub enum UpgradeOutcome {
    Upgraded,
    Regressed(String),
    Skipped,
    BackupFailed(String),
}

/// Rewrite a single service's `image` in the compose file, preserving the rest.
pub fn set_service_image(compose_path: &Path, service: &str, image: &str) -> io::Result<()> {
    let text = std::fs::read_to_string(compose_path)?;
    let mut doc: serde_yaml::Value = serde_yaml::from_str(&text)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e.to_string()))?;
    if let Some(svc) = doc
        .as_mapping_mut()
        .and_then(|m| m.get_mut("services"))
        .and_then(|v| v.as_mapping_mut())
        .and_then(|s| s.get_mut(service))
        .and_then(|v| v.as_mapping_mut())
    {
        svc.insert(
            serde_yaml::Value::from("image"),
            serde_yaml::Value::from(image),
        );
    }
    let out = serde_yaml::to_string(&doc)
        .map_err(|e| io::Error::new(io::ErrorKind::Other, e.to_string()))?;
    std::fs::write(compose_path, out)
}

/// Orchestrate a health-gated upgrade with regress-or-accept.
#[allow(clippy::too_many_arguments)]
pub fn safe_upgrade(
    _compose_path: &Path,
    _repo: &Path,
    _service: &str,
    _image: &str,
    _confirmed: bool,
    _accept: bool,
    _backup: &dyn BackupHook,
    _deployer: &dyn Deployer,
) -> io::Result<UpgradeOutcome> {
    if !_confirmed {
        return Ok(UpgradeOutcome::Skipped);
    }
    let stack_dir = _compose_path.parent().unwrap_or_else(|| Path::new("."));

    if let Err(e) = _backup.pre_change_backup(stack_dir) {
        return Ok(UpgradeOutcome::BackupFailed(e.to_string()));
    }

    // Remember the last-good commit, apply the new image, snapshot it.
    let prior = gitver::history(_repo)
        .ok()
        .and_then(|h| h.first().map(|(sha, _)| sha.clone()));
    set_service_image(_compose_path, _service, _image)?;
    gitver::snapshot(_repo, &format!("upgrade {_service} -> {_image}"))?;

    let regress = |reason: &str| -> io::Result<UpgradeOutcome> {
        if let Some(good) = &prior {
            gitver::restore(_repo, good)?;
        }
        Ok(UpgradeOutcome::Regressed(reason.to_string()))
    };

    match _deployer.deploy(stack_dir) {
        Ok(()) if _accept => Ok(UpgradeOutcome::Upgraded),
        Ok(()) => regress("healthy but not accepted"),
        Err(_) => regress("healthcheck failed"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::compose::parse_service_images;

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
    struct NoopBackup;
    impl BackupHook for NoopBackup {
        fn pre_change_backup(&self, _d: &Path) -> io::Result<()> {
            Ok(())
        }
    }

    fn repo_with_app() -> (tempfile::TempDir, std::path::PathBuf) {
        let dir = tempfile::tempdir().unwrap();
        gitver::init(dir.path()).unwrap();
        let compose = dir.path().join("docker-compose.yml");
        std::fs::write(&compose, "services:\n  app:\n    image: nginx:1.27\n  db:\n    image: postgres:16\n").unwrap();
        gitver::snapshot(dir.path(), "init").unwrap();
        (dir, compose)
    }

    fn app_image(compose: &Path) -> String {
        let yaml = std::fs::read_to_string(compose).unwrap();
        parse_service_images(&yaml).get("app").cloned().unwrap_or_default()
    }

    #[test]
    fn set_service_image_rewrites_only_that_service() {
        let (dir, compose) = repo_with_app();
        set_service_image(&compose, "app", "nginx:1.29").unwrap();
        let yaml = std::fs::read_to_string(&compose).unwrap();
        let imgs = parse_service_images(&yaml);
        assert_eq!(imgs.get("app").map(String::as_str), Some("nginx:1.29"));
        assert_eq!(imgs.get("db").map(String::as_str), Some("postgres:16"), "other service preserved");
        drop(dir);
    }

    #[test]
    fn upgrade_accepts_when_healthy_and_accepted() {
        let (dir, compose) = repo_with_app();
        let out = safe_upgrade(&compose, dir.path(), "app", "nginx:1.29", true, true, &NoopBackup, &OkDeployer).unwrap();
        assert_eq!(out, UpgradeOutcome::Upgraded);
        assert_eq!(app_image(&compose), "nginx:1.29", "upgrade kept");
    }

    #[test]
    fn upgrade_regresses_when_healthy_but_not_accepted() {
        let (dir, compose) = repo_with_app();
        let out = safe_upgrade(&compose, dir.path(), "app", "nginx:1.29", true, false, &NoopBackup, &OkDeployer).unwrap();
        assert!(matches!(out, UpgradeOutcome::Regressed(_)));
        assert_eq!(app_image(&compose), "nginx:1.27", "reverted to last-good");
    }

    #[test]
    fn upgrade_regresses_on_failed_healthcheck() {
        let (dir, compose) = repo_with_app();
        let out = safe_upgrade(&compose, dir.path(), "app", "nginx:1.29", true, true, &NoopBackup, &FailDeployer).unwrap();
        assert!(matches!(out, UpgradeOutcome::Regressed(_)));
        assert_eq!(app_image(&compose), "nginx:1.27", "reverted on failure");
    }

    #[test]
    fn upgrade_skips_without_confirmation() {
        let (dir, compose) = repo_with_app();
        let out = safe_upgrade(&compose, dir.path(), "app", "nginx:1.29", false, true, &NoopBackup, &OkDeployer).unwrap();
        assert_eq!(out, UpgradeOutcome::Skipped);
        assert_eq!(app_image(&compose), "nginx:1.27", "no change on dry run");
    }
}
