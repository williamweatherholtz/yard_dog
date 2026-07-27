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
    /// The target service has no image line to upgrade — nothing was applied.
    NoSuchService(String),
    Skipped,
    Blocked(String),
    BackupFailed(String),
}

/// Return `yaml` with a single service's `image` rewritten, preserving the rest
/// of the file byte-for-byte (comments, key order, quoting). A surgical, line-
/// oriented edit rather than a serde round-trip — the compose lives on disk and
/// is git-versioned, so noisy reformatting and lost comments are unacceptable.
/// Being pure over the text, it also previews what an upgrade will deploy (e.g.
/// for guardrail evaluation) without touching disk.
pub fn image_changed_yaml(yaml: &str, service: &str, image: &str) -> io::Result<String> {
    Ok(try_image_change(yaml, service, image).unwrap_or_else(|| yaml.to_string()))
}

/// Like `image_changed_yaml`, but returns `None` when the target service has no
/// image line to change (an absent or build-only service) — so callers can fail
/// loudly instead of silently applying nothing.
pub fn try_image_change(yaml: &str, service: &str, image: &str) -> Option<String> {
    let indent_of = |l: &str| l.len() - l.trim_start().len();
    let mut out: Vec<String> = Vec::new();
    let mut services_indent: Option<usize> = None;
    let mut target_indent: Option<usize> = None;
    let mut replaced = false;

    for line in yaml.lines() {
        let trimmed = line.trim_start();
        let indent = indent_of(line);
        let structural = !trimmed.is_empty() && !trimmed.starts_with('#');

        // Enter the top-level `services:` mapping.
        if services_indent.is_none() {
            if structural && trimmed == "services:" {
                services_indent = Some(indent);
            }
            out.push(line.to_string());
            continue;
        }
        let svc_indent = services_indent.unwrap();

        // A structural line at or above `services:` indent ends the block.
        if structural && indent <= svc_indent {
            services_indent = None;
            target_indent = None;
            out.push(line.to_string());
            continue;
        }

        match target_indent {
            // Looking for the target service's header.
            None => {
                if structural
                    && indent > svc_indent
                    && trimmed
                        .strip_suffix(':')
                        .map(|h| h.trim_matches('"').trim_matches('\''))
                        == Some(service)
                {
                    target_indent = Some(indent);
                }
                out.push(line.to_string());
            }
            // Inside the target service block.
            Some(t_indent) => {
                if structural && indent <= t_indent {
                    // Left the target service; re-check this same line as a header.
                    target_indent = None;
                    if indent > svc_indent && trimmed
                        .strip_suffix(':')
                        .map(|h| h.trim_matches('"').trim_matches('\''))
                        == Some(service) {
                        target_indent = Some(indent);
                    }
                    out.push(line.to_string());
                } else if !replaced && trimmed.starts_with("image:") {
                    let after = &trimmed["image:".len()..];
                    let comment = after.find('#').map(|i| after[i..].to_string());
                    let indent_str = &line[..indent];
                    out.push(match comment {
                        Some(c) => format!("{indent_str}image: {image}  {c}"),
                        None => format!("{indent_str}image: {image}"),
                    });
                    replaced = true;
                } else {
                    out.push(line.to_string());
                }
            }
        }
    }

    if !replaced {
        return None;
    }
    let mut result = out.join("\n");
    if yaml.ends_with('\n') {
        result.push('\n');
    }
    Some(result)
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
        Outcome::NoSuchService(r) => UpgradeOutcome::NoSuchService(r),
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
    fn image_change_preserves_comments_and_formatting() {
        let yaml = "# my stack\nservices:\n  app:\n    image: nginx:1.27  # pinned\n    restart: unless-stopped\n  db:\n    image: postgres:16\n";
        let out = image_changed_yaml(yaml, "app", "nginx:1.29").unwrap();
        assert!(out.contains("# my stack"), "top-of-file comment preserved:\n{out}");
        assert!(out.contains("image: nginx:1.29"), "image updated:\n{out}");
        assert!(out.contains("# pinned"), "inline comment preserved:\n{out}");
        assert!(out.contains("restart: unless-stopped"), "sibling key preserved");
        assert!(out.contains("image: postgres:16"), "other service untouched");
        assert!(!out.contains("nginx:1.27"), "old image gone");
    }

    #[test]
    fn image_change_handles_a_quoted_service_name() {
        // A quoted service key is legal YAML; the edit must still find it (the
        // old serde round-trip did), else the upgrade silently no-ops.
        let yaml = "services:\n  \"app\":\n    image: nginx:1.27\n";
        let out = image_changed_yaml(yaml, "app", "nginx:1.29").unwrap();
        assert!(out.contains("image: nginx:1.29"), "quoted-key service updated:\n{out}");
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
    fn upgrade_of_unknown_service_is_no_such_service() {
        let (dir, compose) = repo_with_app();
        let out = safe_upgrade(&compose, dir.path(), "nope", "x:1", true, true, &NoopBackup, &OkDeployer).unwrap();
        assert!(matches!(out, UpgradeOutcome::NoSuchService(_)), "got {out:?}");
        assert_eq!(app_image(&compose), "nginx:1.27", "no change on an unknown-service upgrade");
    }

    #[test]
    fn upgrade_skips_without_confirmation() {
        let (dir, compose) = repo_with_app();
        let out = safe_upgrade(&compose, dir.path(), "app", "nginx:1.29", false, true, &NoopBackup, &OkDeployer).unwrap();
        assert_eq!(out, UpgradeOutcome::Skipped);
        assert_eq!(app_image(&compose), "nginx:1.27", "no change on dry run");
    }
}
