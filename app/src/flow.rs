//! The deploy/upgrade lifecycle as an explicit finite state machine, shared by
//! `safe_deploy` and `safe_upgrade`. Phases advance one at a time with guarded
//! transitions, so the flow is inspectable (a recorded `trace`) and invalid
//! orderings are not expressible ad-hoc. It runs guardrails first (blocking on
//! block-severity, surfacing warnings) and gates on a real healthcheck.

use crate::deploy::{BackupHook, Deployer};
use crate::gitver;
use crate::guardrails::{run_guardrails, verdict, Severity};
use crate::upgrade::set_service_image;
use std::io;
use std::path::Path;

/// The `docker compose up` args used for a health-gated deploy. `--wait` makes
/// the deploy return only once containers are HEALTHY (not merely started), so
/// the health-gate is real.
pub fn compose_up_args() -> Vec<&'static str> {
    vec!["compose", "up", "-d", "--wait"]
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Phase {
    Guardrails,
    Backup,
    Apply,
    Snapshot,
    Health,
    Decide,
    Regress,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Outcome {
    Deployed,
    Upgraded,
    Regressed(String),
    Skipped,
    Blocked(String),
    BackupFailed(String),
}

/// A requested change: a plain deploy (`image_change = None`) or a service image
/// upgrade (`Some((service, image))`).
pub struct Change<'a> {
    pub compose_path: &'a Path,
    pub repo: &'a Path,
    pub image_change: Option<(&'a str, &'a str)>,
    pub confirmed: bool,
    pub accept: bool,
}

/// Drive `change` through the lifecycle FSM. Each phase is entered only from its
/// predecessor, and every visited phase is appended to `trace` so the run is
/// inspectable. Terminal outcomes short-circuit before later phases are entered,
/// so e.g. a block-severity guardrail finding can never reach Apply/Health.
pub fn run(
    change: &Change,
    backup: &dyn BackupHook,
    deployer: &dyn Deployer,
    trace: &mut Vec<Phase>,
) -> io::Result<Outcome> {
    // Unconfirmed changes never touch the stack (and leave no trace/snapshot).
    if !change.confirmed {
        return Ok(Outcome::Skipped);
    }
    let stack_dir = change.compose_path.parent().unwrap_or_else(|| Path::new("."));

    // Guardrails: surface warnings, refuse to proceed on any block-severity
    // finding (floating tag, plaintext secret). An operator is thereby told when
    // a healthcheck is desired but absent — the health-gate is otherwise a no-op.
    trace.push(Phase::Guardrails);
    let yaml = std::fs::read_to_string(change.compose_path).unwrap_or_default();
    let findings = run_guardrails(&yaml);
    if !verdict(&findings) {
        let blockers: Vec<String> = findings
            .iter()
            .filter(|f| f.severity == Severity::Block)
            .map(|f| format!("{}: {}", f.service, f.message))
            .collect();
        return Ok(Outcome::Blocked(blockers.join("; ")));
    }

    // Recovery point first — abort if it fails, before anything is changed.
    trace.push(Phase::Backup);
    if let Err(e) = backup.pre_change_backup(stack_dir) {
        return Ok(Outcome::BackupFailed(e.to_string()));
    }

    // Prior last-good = current HEAD, captured before the new snapshot.
    let prior = gitver::history(change.repo)
        .ok()
        .and_then(|h| h.first().map(|(sha, _)| sha.clone()));

    // Apply the change (an upgrade edits the service image; a plain deploy is a
    // no-op edit), then snapshot exactly what is about to be deployed.
    trace.push(Phase::Apply);
    if let Some((service, image)) = change.image_change {
        set_service_image(change.compose_path, service, image)?;
    }
    trace.push(Phase::Snapshot);
    gitver::snapshot(change.repo, "yd flow snapshot")?;

    // Health-gate: the Deployer waits for containers to become HEALTHY; `Err`
    // means unhealthy/timed-out.
    trace.push(Phase::Health);
    let health = deployer.deploy(stack_dir);

    trace.push(Phase::Decide);
    let healthy = health.is_ok();
    if healthy && change.accept {
        return Ok(if change.image_change.is_some() {
            Outcome::Upgraded
        } else {
            Outcome::Deployed
        });
    }

    // Regress: unhealthy, or healthy-but-not-accepted. Restore the last-good
    // commit so a failed change leaves the stack as it was.
    trace.push(Phase::Regress);
    if let Some(good) = prior {
        gitver::restore(change.repo, &good)?;
    }
    let reason = match health {
        Ok(()) => "healthy but not accepted".to_string(),
        Err(e) => e.to_string(),
    };
    Ok(Outcome::Regressed(reason))
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
    struct NoopBackup;
    impl BackupHook for NoopBackup {
        fn pre_change_backup(&self, _d: &Path) -> io::Result<()> {
            Ok(())
        }
    }

    fn repo(compose_body: &str) -> (tempfile::TempDir, std::path::PathBuf) {
        let dir = tempfile::tempdir().unwrap();
        gitver::init(dir.path()).unwrap();
        let compose = dir.path().join("docker-compose.yml");
        std::fs::write(&compose, compose_body).unwrap();
        gitver::snapshot(dir.path(), "init").unwrap();
        (dir, compose)
    }

    fn change<'a>(compose: &'a Path, repo: &'a Path) -> Change<'a> {
        Change {
            compose_path: compose,
            repo,
            image_change: None,
            confirmed: true,
            accept: true,
        }
    }

    #[test]
    fn deploy_up_args_wait_for_health() {
        assert!(compose_up_args().contains(&"--wait"), "gate must wait for health");
    }

    #[test]
    fn healthy_deploy_walks_the_full_fsm() {
        let (dir, compose) = repo("services:\n  app:\n    image: nginx:1.27\n");
        let mut trace = Vec::new();
        let out = run(&change(&compose, dir.path()), &NoopBackup, &OkDeployer, &mut trace).unwrap();
        assert_eq!(out, Outcome::Deployed);
        assert_eq!(
            trace,
            vec![
                Phase::Guardrails,
                Phase::Backup,
                Phase::Apply,
                Phase::Snapshot,
                Phase::Health,
                Phase::Decide
            ]
        );
    }

    #[test]
    fn plaintext_secret_blocks_before_deploy() {
        let (dir, compose) = repo(
            "services:\n  db:\n    image: postgres:16\n    environment:\n      POSTGRES_PASSWORD: hunter2\n",
        );
        let spy = SpyDeployer::default();
        let mut trace = Vec::new();
        let out = run(&change(&compose, dir.path()), &NoopBackup, &spy, &mut trace).unwrap();
        assert!(matches!(out, Outcome::Blocked(_)), "block on a plaintext secret");
        assert!(!*spy.called.borrow(), "must not deploy when blocked");
        assert_eq!(trace, vec![Phase::Guardrails]);
    }

    #[test]
    fn unhealthy_deploy_regresses() {
        let (dir, compose) = repo("services:\n  app:\n    image: nginx:1.27\n");
        let mut trace = Vec::new();
        let out = run(&change(&compose, dir.path()), &NoopBackup, &FailDeployer, &mut trace).unwrap();
        assert!(matches!(out, Outcome::Regressed(_)));
        assert_eq!(*trace.last().unwrap(), Phase::Regress);
    }
}
