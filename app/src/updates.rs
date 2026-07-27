//! Safe container auto-update: detect when a service's image has a newer digest
//! than the running one, and produce a kind-gated plan. The apply itself routes
//! through the existing safe-deploy path; datastores default to notify-only.

use crate::workload::{classify, ServiceView, WorkloadKind};
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UpdateStatus {
    UpToDate,
    UpdateAvailable,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UpdatePolicy {
    AutoApply,
    NotifyOnly,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UpdateAction {
    Apply,
    Notify,
    None,
}

impl UpdateAction {
    pub fn as_str(&self) -> &'static str {
        match self {
            UpdateAction::Apply => "apply",
            UpdateAction::Notify => "notify",
            UpdateAction::None => "none",
        }
    }
}

/// Resolves the current remote digest of an image tag.
pub trait RegistryClient {
    fn remote_digest(&self, image: &str) -> Option<String>;
}

/// Compare the running digest to the remote digest.
pub fn update_status(running: Option<&str>, remote: Option<&str>) -> UpdateStatus {
    match (running, remote) {
        (Some(r), Some(x)) if r == x => UpdateStatus::UpToDate,
        (Some(_), Some(_)) => UpdateStatus::UpdateAvailable,
        _ => UpdateStatus::Unknown,
    }
}

/// Per-kind update policy: datastores (and unknowns) never auto-update.
pub fn update_policy(kind: WorkloadKind) -> UpdatePolicy {
    match kind {
        WorkloadKind::Datastore | WorkloadKind::Unknown => UpdatePolicy::NotifyOnly,
        _ => UpdatePolicy::AutoApply,
    }
}

/// A per-service entry in the update plan.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UpdateItem {
    pub service: String,
    pub status: UpdateStatus,
    pub kind: WorkloadKind,
    pub action: UpdateAction,
}

/// Build the update plan for a set of services.
pub fn build_update_plan(
    services: &[ServiceView],
    running_digests: &HashMap<String, String>,
    registry: &dyn RegistryClient,
) -> Vec<UpdateItem> {
    services
        .iter()
        .map(|v| {
            let running = running_digests.get(&v.name).map(|s| s.as_str());
            let remote = v.image.as_deref().and_then(|img| registry.remote_digest(img));
            let status = update_status(running, remote.as_deref());
            let kind = classify(v);
            let action = match status {
                UpdateStatus::UpdateAvailable => match update_policy(kind) {
                    UpdatePolicy::AutoApply => UpdateAction::Apply,
                    UpdatePolicy::NotifyOnly => UpdateAction::Notify,
                },
                _ => UpdateAction::None,
            };
            UpdateItem {
                service: v.name.clone(),
                status,
                kind,
                action,
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    struct FixedReg(HashMap<String, String>);
    impl RegistryClient for FixedReg {
        fn remote_digest(&self, image: &str) -> Option<String> {
            self.0.get(image).cloned()
        }
    }

    fn svc(name: &str, image: &str, ports: &[&str]) -> ServiceView {
        ServiceView {
            name: name.into(),
            image: Some(image.into()),
            ports: ports.iter().map(|s| s.to_string()).collect(),
            ..Default::default()
        }
    }

    #[test]
    fn update_status_compares_digests() {
        assert_eq!(update_status(Some("a"), Some("a")), UpdateStatus::UpToDate);
        assert_eq!(update_status(Some("a"), Some("b")), UpdateStatus::UpdateAvailable);
        assert_eq!(update_status(None, Some("b")), UpdateStatus::Unknown);
        assert_eq!(update_status(Some("a"), None), UpdateStatus::Unknown);
    }

    #[test]
    fn policy_never_auto_updates_datastores() {
        assert_eq!(update_policy(WorkloadKind::Datastore), UpdatePolicy::NotifyOnly);
        assert_eq!(update_policy(WorkloadKind::Unknown), UpdatePolicy::NotifyOnly);
        assert_eq!(update_policy(WorkloadKind::Web), UpdatePolicy::AutoApply);
        assert_eq!(update_policy(WorkloadKind::Worker), UpdatePolicy::AutoApply);
    }

    #[test]
    fn plan_notifies_datastore_and_skips_uptodate() {
        let services = vec![svc("db", "postgres:16", &[]), svc("web", "nginx:1.27", &["80:80"])];
        let running = HashMap::from([
            ("db".to_string(), "old".to_string()),
            ("web".to_string(), "same".to_string()),
        ]);
        let reg = FixedReg(HashMap::from([
            ("postgres:16".to_string(), "new".to_string()),
            ("nginx:1.27".to_string(), "same".to_string()),
        ]));

        let plan = build_update_plan(&services, &running, &reg);
        let db = plan.iter().find(|i| i.service == "db").unwrap();
        assert_eq!(db.status, UpdateStatus::UpdateAvailable);
        assert_eq!(db.kind, WorkloadKind::Datastore);
        assert_eq!(db.action, UpdateAction::Notify, "datastore update is notify-only");

        let web = plan.iter().find(|i| i.service == "web").unwrap();
        assert_eq!(web.status, UpdateStatus::UpToDate);
        assert_eq!(web.action, UpdateAction::None);
    }
}
