//! A single go/no-go preflight for a stack: aggregate the guardrail findings and
//! the lifecycle state into one verdict, using the SAME rules the deploy flow
//! enforces (block-severity finding OR Archived => not ready). One answer to
//! "is this stack ready to deploy?" instead of correlating several commands.

use crate::guardrails::{run_guardrails, Severity};
use crate::lifecycle::LifecycleState;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Preflight {
    pub blocks: usize,
    pub warns: usize,
    pub lifecycle: LifecycleState,
    pub ready: bool,
}

/// Assess a stack's readiness from its compose text and lifecycle state.
pub fn assess(yaml: &str, lifecycle: LifecycleState) -> Preflight {
    let findings = run_guardrails(yaml);
    let blocks = findings.iter().filter(|f| f.severity == Severity::Block).count();
    let warns = findings.iter().filter(|f| f.severity == Severity::Warn).count();
    // Same rules the deploy flow enforces: any block, an archived stack, OR a
    // compose with no services (which the FSM Blocks) is not deploy-ready — so
    // doctor can't say READY on a file `deploy` would refuse.
    let has_services = !crate::workload::parse_services(yaml).is_empty();
    let ready = blocks == 0 && lifecycle != LifecycleState::Archived && has_services;
    Preflight { blocks, warns, lifecycle, ready }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CLEAN: &str = "services:\n  web:\n    image: nginx:1.27\n    restart: unless-stopped\n    mem_limit: 256m\n    healthcheck:\n      test: [\"CMD\", \"true\"]\n";
    const FLOATING: &str = "services:\n  web:\n    image: nginx:latest\n";

    #[test]
    fn clean_stack_is_ready_with_no_blocks() {
        let p = assess(CLEAN, LifecycleState::Active);
        assert_eq!(p.blocks, 0);
        assert!(p.ready, "a clean active stack is ready: {p:?}");
    }

    #[test]
    fn blocking_finding_makes_it_not_ready() {
        let p = assess(FLOATING, LifecycleState::Active);
        assert!(p.blocks > 0, "floating tag is a block");
        assert!(!p.ready, "a block-severity finding must fail preflight");
    }

    #[test]
    fn warns_are_counted_but_do_not_fail() {
        // no healthcheck/restart/limits are warns, not blocks
        let p = assess("services:\n  web:\n    image: nginx:1.27\n", LifecycleState::Active);
        assert_eq!(p.blocks, 0);
        assert!(p.warns >= 3, "expected the missing-healthcheck/restart/limits warns: {p:?}");
        assert!(p.ready, "warns alone do not block readiness");
    }

    #[test]
    fn archived_is_not_ready_even_when_clean() {
        let p = assess(CLEAN, LifecycleState::Archived);
        assert_eq!(p.blocks, 0);
        assert!(!p.ready, "an archived stack is never deploy-ready");
    }

    #[test]
    fn compose_with_no_services_is_not_ready() {
        // deploy Blocks "no services declared"; doctor must agree, not say READY.
        let p = assess("networks:\n  default: {}\n", LifecycleState::Active);
        assert_eq!(p.blocks, 0, "no guardrail blocks fire on a serviceless compose");
        assert!(!p.ready, "a compose with no services is not deploy-ready");
    }

    #[test]
    fn draft_active_deprecated_clean_are_ready() {
        for s in [LifecycleState::Draft, LifecycleState::Active, LifecycleState::Deprecated] {
            assert!(assess(CLEAN, s).ready, "{s:?} clean stack should be ready");
        }
    }
}
