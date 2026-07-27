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
    /// The change failed AND the rollback redeploy also failed — the live stack
    /// is in a bad state and needs operator attention.
    RegressFailed(String),
    /// The upgrade target service has no image to change — nothing was applied.
    NoSuchService(String),
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
    // Lifecycle gate: an archived stack is retired — refuse to resurrect it via
    // a deploy/upgrade. The operator must explicitly `yd lifecycle ... restore`.
    if crate::lifecycle::read_state(stack_dir) == crate::lifecycle::LifecycleState::Archived {
        return Ok(Outcome::Blocked(
            "stack is archived — restore it (yd lifecycle --event restore) before deploying".into(),
        ));
    }
    let yaml = std::fs::read_to_string(change.compose_path).unwrap_or_default();
    // For an upgrade, evaluate what will actually be deployed (post-Apply), not
    // the stale on-disk image — else a floating tag / secret the upgrade would
    // introduce is missed, and a violation the upgrade fixes wrongly blocks.
    let effective = match change.image_change {
        Some((service, image)) => match crate::upgrade::try_image_change(&yaml, service, image) {
            Some(changed) => changed,
            // No image line for this service — fail loudly before any side effect
            // instead of snapshotting/deploying an unchanged config as an "upgrade".
            None => {
                return Ok(Outcome::NoSuchService(format!(
                    "service '{service}' has no image to upgrade"
                )))
            }
        },
        None => yaml.clone(),
    };
    let findings = run_guardrails(&effective);
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
    // commit AND redeploy it, so the *running* stack — not just the file on
    // disk — returns to the good version. If the rollback redeploy itself fails,
    // the stack is in a bad state: report RegressFailed rather than a clean roll.
    trace.push(Phase::Regress);
    let reason = match health {
        Ok(()) => "healthy but not accepted".to_string(),
        Err(e) => e.to_string(),
    };
    if let Some(good) = prior {
        gitver::restore(change.repo, &good)?;
        if let Err(e) = deployer.deploy(stack_dir) {
            return Ok(Outcome::RegressFailed(format!(
                "{reason}; rollback redeploy failed: {e}"
            )));
        }
    }
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
    /// Fails its first `fail_until` calls, then succeeds; counts every call.
    struct CountingDeployer {
        calls: RefCell<usize>,
        fail_until: usize,
    }
    impl CountingDeployer {
        fn new(fail_until: usize) -> Self {
            Self { calls: RefCell::new(0), fail_until }
        }
    }
    impl Deployer for CountingDeployer {
        fn deploy(&self, _d: &Path) -> io::Result<()> {
            let mut c = self.calls.borrow_mut();
            let n = *c;
            *c += 1;
            if n < self.fail_until {
                Err(io::Error::new(io::ErrorKind::Other, "unhealthy"))
            } else {
                Ok(())
            }
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
    fn upgrade_to_a_floating_tag_is_blocked_on_post_apply_content() {
        // The current compose is clean (pinned tag); the upgrade would introduce
        // a floating :latest tag. Guardrails must evaluate what is actually being
        // deployed (post-Apply), so this is blocked before any deploy.
        let (dir, compose) = repo("services:\n  app:\n    image: nginx:1.27\n");
        let spy = SpyDeployer::default();
        let ch = Change {
            compose_path: &compose,
            repo: dir.path(),
            image_change: Some(("app", "nginx:latest")),
            confirmed: true,
            accept: true,
        };
        let mut trace = Vec::new();
        let out = run(&ch, &NoopBackup, &spy, &mut trace).unwrap();
        assert!(matches!(out, Outcome::Blocked(_)), "got {out:?}");
        assert!(!*spy.called.borrow(), "must not deploy a blocked upgrade");
        assert_eq!(trace, vec![Phase::Guardrails]);
    }

    #[test]
    fn upgrade_of_absent_service_fails_loudly() {
        // A typo'd (or build-only) service has no image line — the upgrade must
        // NOT silently report success. Nothing is deployed and nothing changes.
        let (dir, compose) = repo("services:\n  app:\n    image: nginx:1.27\n");
        let spy = SpyDeployer::default();
        let ch = Change {
            compose_path: &compose,
            repo: dir.path(),
            image_change: Some(("typo", "nginx:1.29")),
            confirmed: true,
            accept: true,
        };
        let mut trace = Vec::new();
        let out = run(&ch, &NoopBackup, &spy, &mut trace).unwrap();
        assert!(matches!(out, Outcome::NoSuchService(_)), "got {out:?}");
        assert!(!*spy.called.borrow(), "must not deploy when the change cannot apply");
        assert!(std::fs::read_to_string(&compose).unwrap().contains("nginx:1.27"), "compose unchanged");
    }

    #[test]
    fn upgrade_that_fixes_a_floating_tag_is_not_blocked() {
        // The current compose has a floating tag (would block a plain deploy);
        // the upgrade pins it. Evaluating post-Apply content, the fix proceeds.
        let (dir, compose) = repo("services:\n  app:\n    image: nginx:latest\n");
        let ch = Change {
            compose_path: &compose,
            repo: dir.path(),
            image_change: Some(("app", "nginx:1.29")),
            confirmed: true,
            accept: true,
        };
        let mut trace = Vec::new();
        let out = run(&ch, &NoopBackup, &OkDeployer, &mut trace).unwrap();
        assert_eq!(out, Outcome::Upgraded, "a floating-tag fix must not be blocked");
    }

    #[test]
    fn archived_stack_is_blocked_before_any_side_effect() {
        use crate::lifecycle::{write_state, LifecycleState};
        let (dir, compose) = repo("services:\n  app:\n    image: nginx:1.27\n");
        write_state(dir.path(), LifecycleState::Archived).unwrap();
        let spy = SpyDeployer::default();
        let mut trace = Vec::new();
        // plain deploy
        let out = run(&change(&compose, dir.path()), &NoopBackup, &spy, &mut trace).unwrap();
        assert!(matches!(out, Outcome::Blocked(_)), "archived must block: {out:?}");
        assert!(!*spy.called.borrow(), "must not deploy an archived stack");
        assert_eq!(trace, vec![Phase::Guardrails]);
        // upgrade too
        let ch = Change {
            compose_path: &compose,
            repo: dir.path(),
            image_change: Some(("app", "nginx:1.29")),
            confirmed: true,
            accept: true,
        };
        let mut t2 = Vec::new();
        let out2 = run(&ch, &NoopBackup, &spy, &mut t2).unwrap();
        assert!(matches!(out2, Outcome::Blocked(_)), "archived upgrade must block");
    }

    #[test]
    fn deprecated_and_active_are_not_gated_by_lifecycle() {
        use crate::lifecycle::{write_state, LifecycleState};
        for state in [LifecycleState::Active, LifecycleState::Deprecated, LifecycleState::Draft] {
            let (dir, compose) = repo("services:\n  app:\n    image: nginx:1.27\n");
            write_state(dir.path(), state).unwrap();
            let mut trace = Vec::new();
            let out = run(&change(&compose, dir.path()), &NoopBackup, &OkDeployer, &mut trace).unwrap();
            assert_eq!(out, Outcome::Deployed, "{state:?} must not be lifecycle-blocked");
        }
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
    fn unhealthy_deploy_regresses_and_redeploys_last_good() {
        // Health fails on the first deploy; the rollback redeploy (second call)
        // succeeds, so the live stack is actually returned to the good version.
        let (dir, compose) = repo("services:\n  app:\n    image: nginx:1.27\n");
        std::fs::write(&compose, "services:\n  app:\n    image: nginx:1.29\n").unwrap();
        let deployer = CountingDeployer::new(1);
        let mut trace = Vec::new();
        let out = run(&change(&compose, dir.path()), &NoopBackup, &deployer, &mut trace).unwrap();
        assert!(matches!(out, Outcome::Regressed(_)));
        assert_eq!(*trace.last().unwrap(), Phase::Regress);
        assert_eq!(*deployer.calls.borrow(), 2, "regress must redeploy the restored config");
    }

    #[test]
    fn regress_that_cannot_redeploy_reports_failure() {
        // When even the rollback redeploy fails, the operator must be told the
        // stack is in a bad state (RegressFailed), not that it rolled back cleanly.
        let (dir, compose) = repo("services:\n  app:\n    image: nginx:1.27\n");
        std::fs::write(&compose, "services:\n  app:\n    image: nginx:1.29\n").unwrap();
        let deployer = CountingDeployer::new(usize::MAX);
        let mut trace = Vec::new();
        let out = run(&change(&compose, dir.path()), &NoopBackup, &deployer, &mut trace).unwrap();
        assert!(matches!(out, Outcome::RegressFailed(_)), "got {out:?}");
        assert_eq!(*deployer.calls.borrow(), 2, "attempted the rollback redeploy");
    }
}
