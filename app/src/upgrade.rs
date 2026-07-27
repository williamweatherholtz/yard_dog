//! One-shot safe upgrade: back up, snapshot config in git, set the target image,
//! deploy, then regress on a failed healthcheck — and on a passing one either
//! accept or regress if not accepted. Composes the backup, gitver, and deploy
//! primitives; the Deployer/BackupHook traits keep it testable without Docker.

use crate::deploy::{BackupHook, Deployer};
use crate::flow::{self, Change, Outcome};
use std::io;
use std::path::Path;

#[derive(Debug, PartialEq, Eq)]
pub enum UpgradeOutcome {
    Upgraded,
    Regressed(String),
    /// Upgrade failed and the rollback redeploy also failed — needs attention.
    RegressFailed(String),
    Skipped,
    Blocked(String),
    BackupFailed(String),
}

/// Return `yaml` with a single service's `image` rewritten, preserving the rest.
/// Pure over the text, so it also serves as a preview of what an upgrade will
/// deploy (e.g. for guardrail evaluation) without touching disk.
pub fn image_changed_yaml(yaml: &str, service: &str, image: &str) -> io::Result<String> {
    let mut doc: serde_yaml::Value = serde_yaml::from_str(yaml)
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
    serde_yaml::to_string(&doc).map_err(|e| io::Error::new(io::ErrorKind::Other, e.to_string()))
}

/// Rewrite a single service's `image` in the compose file, preserving the rest.
pub fn set_service_image(compose_path: &Path, service: &str, image: &str) -> io::Result<()> {
    let text = std::fs::read_to_string(compose_path)?;
    let out = image_changed_yaml(&text, service, image)?;
    std::fs::write(compose_path, out)
}

/// Orchestrate a health-gated upgrade with regress-or-accept. This is a thin
/// adapter over the shared lifecycle FSM (`flow::run`) — the only upgrade-specific
/// input is the target image; backup, snapshot, health-gate and regress are
/// identical to a plain deploy (see issDeployDup).
#[allow(clippy::too_many_arguments)]
pub fn safe_upgrade(
    compose_path: &Path,
    repo: &Path,
    service: &str,
    image: &str,
    confirmed: bool,
    accept: bool,
    backup: &dyn BackupHook,
    deployer: &dyn Deployer,
) -> io::Result<UpgradeOutcome> {
    let change = Change {
        compose_path,
        repo,
        image_change: Some((service, image)),
        confirmed,
        accept,
    };
    let mut trace = Vec::new();
    Ok(match flow::run(&change, backup, deployer, &mut trace)? {
        Outcome::Upgraded | Outcome::Deployed => UpgradeOutcome::Upgraded,
        Outcome::Regressed(r) => UpgradeOutcome::Regressed(r),
        Outcome::RegressFailed(r) => UpgradeOutcome::RegressFailed(r),
        Outcome::Skipped => UpgradeOutcome::Skipped,
        Outcome::Blocked(r) => UpgradeOutcome::Blocked(r),
        Outcome::BackupFailed(r) => UpgradeOutcome::BackupFailed(r),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::compose::parse_service_images;
    use crate::gitver;

    struct OkDeployer;
    impl Deployer for OkDeployer {
        fn deploy(&self, _d: &Path) -> io::Result<()> {
            Ok(())
        }
    }
    /// Fails the health-gate on the first deploy, then succeeds — so the rollback
    /// redeploy after a regress goes through.
    #[derive(Default)]
    struct FailThenOkDeployer {
        failed_once: std::cell::RefCell<bool>,
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
        let out = safe_upgrade(&compose, dir.path(), "app", "nginx:1.29", true, true, &NoopBackup, &FailThenOkDeployer::default()).unwrap();
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
