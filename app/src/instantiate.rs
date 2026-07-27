//! Instantiate a new stack from a workload kind. Rather than a blank compose,
//! the operator starts from a kind-appropriate template that passes the
//! guardrails by construction — pinned image, healthcheck, restart policy, a
//! resource limit, and (for a datastore) a named volume — placed in its own
//! stack directory and set to the Draft lifecycle state.

use crate::lifecycle::{self, LifecycleState};
use crate::workload::WorkloadKind;
use std::io;
use std::path::{Path, PathBuf};

/// A guardrail-clean starter image (pinned) for each kind.
fn starter_image(kind: WorkloadKind) -> &'static str {
    match kind {
        WorkloadKind::Datastore => "postgres:16",
        WorkloadKind::Web => "nginx:1.27",
        WorkloadKind::Proxy => "traefik:3.1",
        WorkloadKind::Worker | WorkloadKind::Cron | WorkloadKind::Unknown => "alpine:3.20",
    }
}

/// Produce a starter compose for one service of `kind`. The output passes
/// `run_guardrails` with no block-severity finding: pinned image, healthcheck,
/// restart policy, and a resource limit are always present; a datastore also
/// gets a named volume for durable data.
pub fn scaffold(kind: WorkloadKind, service: &str) -> String {
    let image = starter_image(kind);
    let mut s = String::new();
    s.push_str("# Yard Dog starter stack — edit before deploying.\n");
    s.push_str(&format!("# kind: {}\n", kind.as_str()));
    s.push_str("services:\n");
    s.push_str(&format!("  {service}:\n"));
    s.push_str(&format!("    image: {image}\n"));
    s.push_str("    restart: unless-stopped\n");
    s.push_str("    mem_limit: 256m\n");
    s.push_str("    healthcheck:\n");
    s.push_str("      test: [\"CMD\", \"true\"]  # TODO: a real healthcheck for this service\n");
    s.push_str("      interval: 30s\n");
    s.push_str("      timeout: 5s\n");
    s.push_str("      retries: 3\n");
    if matches!(kind, WorkloadKind::Datastore) {
        s.push_str("    volumes:\n");
        s.push_str(&format!("      - {service}-data:/var/lib/{service}\n"));
        s.push_str("volumes:\n");
        s.push_str(&format!("  {service}-data:\n"));
    }
    s
}

/// Create a new stack directory `root/name`, write the starter compose, and set
/// its lifecycle to Draft. Returns the compose path.
pub fn instantiate(
    root: &Path,
    name: &str,
    kind: WorkloadKind,
    service: &str,
) -> io::Result<PathBuf> {
    let stack_dir = root.join(name);
    std::fs::create_dir_all(&stack_dir)?;
    let compose = stack_dir.join("docker-compose.yml");
    std::fs::write(&compose, scaffold(kind, service))?;
    lifecycle::write_state(&stack_dir, LifecycleState::Draft)?;
    Ok(compose)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::guardrails::{run_guardrails, verdict};

    const KINDS: [WorkloadKind; 5] = [
        WorkloadKind::Datastore,
        WorkloadKind::Web,
        WorkloadKind::Worker,
        WorkloadKind::Cron,
        WorkloadKind::Proxy,
    ];

    #[test]
    fn scaffold_is_guardrail_clean_for_every_kind() {
        for kind in KINDS {
            let yaml = scaffold(kind, "svc");
            assert!(yaml.contains("svc:"), "{kind:?} scaffold must define the service:\n{yaml}");
            assert!(yaml.contains("image:"), "{kind:?} scaffold must set an image:\n{yaml}");
            let findings = run_guardrails(&yaml);
            assert!(
                verdict(&findings),
                "{kind:?} scaffold must have no block finding: {findings:?}\n{yaml}"
            );
            // The warn-level rules must also be satisfied by a good template.
            let rules: Vec<&str> = findings.iter().map(|f| f.rule.as_str()).collect();
            for r in ["no-healthcheck", "no-restart", "no-limits", "floating-tag"] {
                assert!(!rules.contains(&r), "{kind:?} scaffold tripped {r}:\n{yaml}");
            }
        }
    }

    #[test]
    fn datastore_gets_a_named_volume_web_does_not() {
        let db = scaffold(WorkloadKind::Datastore, "db");
        assert!(db.contains("volumes:"), "datastore needs a named volume:\n{db}");
        assert!(db.contains("db-data"), "datastore volume should be named for the service:\n{db}");
        let web = scaffold(WorkloadKind::Web, "web");
        assert!(!web.contains("volumes:"), "a web service should not add a volume:\n{web}");
    }

    #[test]
    fn instantiate_writes_draft_stack() {
        let root = tempfile::tempdir().unwrap();
        let compose = instantiate(root.path(), "immich", WorkloadKind::Datastore, "db").unwrap();
        assert!(compose.exists(), "compose file written");
        assert_eq!(compose, root.path().join("immich").join("docker-compose.yml"));
        let yaml = std::fs::read_to_string(&compose).unwrap();
        assert!(verdict(&run_guardrails(&yaml)), "instantiated stack is guardrail-clean");
        let stack_dir = root.path().join("immich");
        assert_eq!(lifecycle::read_state(&stack_dir), LifecycleState::Draft, "new stack starts in Draft");
    }
}
