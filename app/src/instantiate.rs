//! Instantiate a new stack from a guardrail-clean starter template. Rather than a
//! blank compose, `yd new` writes one template that passes the guardrails by
//! construction — pinned image, healthcheck, restart policy, and a resource
//! limit — placed in its own stack directory and set to the Draft lifecycle
//! state. (Workload "kind" was removed per decRemoveWorkloadKind; there is one
//! template regardless of workload.)

use crate::lifecycle::{self, LifecycleState};
use std::io;
use std::path::{Path, PathBuf};

/// Produce a starter compose for one service. The output passes `run_guardrails`
/// with no block-severity finding and no warn-level rule tripped: pinned image,
/// healthcheck, restart policy, and a resource limit are always present.
pub fn scaffold(service: &str) -> String {
    let mut s = String::new();
    s.push_str("# Yard Dog starter stack — set a real image, then edit before deploying.\n");
    s.push_str("services:\n");
    s.push_str(&format!("  {service}:\n"));
    s.push_str("    image: alpine:3.20\n");
    s.push_str("    restart: unless-stopped\n");
    s.push_str("    mem_limit: 256m\n");
    s.push_str("    healthcheck:\n");
    s.push_str("      test: [\"CMD\", \"true\"]  # TODO: a real healthcheck for this service\n");
    s.push_str("      interval: 30s\n");
    s.push_str("      timeout: 5s\n");
    s.push_str("      retries: 3\n");
    s
}

/// Create a new stack directory `root/name`, write the starter compose, and set
/// its lifecycle to Draft. Returns the compose path.
pub fn instantiate(root: &Path, name: &str, service: &str) -> io::Result<PathBuf> {
    if !crate::stacks::is_plain_name(name) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("invalid stack name '{name}' — must be a single path segment"),
        ));
    }
    let stack_dir = root.join(name);
    std::fs::create_dir_all(&stack_dir)?;
    let compose = stack_dir.join("docker-compose.yml");
    std::fs::write(&compose, scaffold(service))?;
    lifecycle::write_state(&stack_dir, LifecycleState::Draft)?;
    Ok(compose)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::guardrails::{run_guardrails, verdict};

    #[test]
    fn scaffold_is_guardrail_clean() {
        let yaml = scaffold("svc");
        assert!(yaml.contains("svc:"), "scaffold must define the service:\n{yaml}");
        assert!(yaml.contains("image:"), "scaffold must set an image:\n{yaml}");
        let findings = run_guardrails(&yaml);
        assert!(verdict(&findings), "scaffold must have no block finding: {findings:?}\n{yaml}");
        let rules: Vec<&str> = findings.iter().map(|f| f.rule.as_str()).collect();
        for r in ["no-healthcheck", "no-restart", "no-limits", "floating-tag"] {
            assert!(!rules.contains(&r), "scaffold tripped {r}:\n{yaml}");
        }
    }

    #[test]
    fn instantiate_writes_draft_stack() {
        let root = tempfile::tempdir().unwrap();
        let compose = instantiate(root.path(), "immich", "app").unwrap();
        assert!(compose.exists(), "compose file written");
        assert_eq!(compose, root.path().join("immich").join("docker-compose.yml"));
        let yaml = std::fs::read_to_string(&compose).unwrap();
        assert!(verdict(&run_guardrails(&yaml)), "instantiated stack is guardrail-clean");
        let stack_dir = root.path().join("immich");
        assert_eq!(lifecycle::read_state(&stack_dir), LifecycleState::Draft, "new stack starts in Draft");
    }
}
