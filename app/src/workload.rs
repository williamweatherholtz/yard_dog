//! Classify each service into a workload kind — datastore / web / worker / cron /
//! proxy / unknown. Two-tier: an authored `yarddog.kind` label wins; otherwise a
//! heuristic infers from image, ports, restart policy, etc. The kind drives
//! kind-specific behaviour (backup profile, update policy, guardrails).

use crate::backup::detect_db_engine;
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WorkloadKind {
    Datastore,
    Web,
    Worker,
    Cron,
    Proxy,
    Unknown,
}

impl WorkloadKind {
    pub fn as_str(&self) -> &'static str {
        match self {
            WorkloadKind::Datastore => "datastore",
            WorkloadKind::Web => "web",
            WorkloadKind::Worker => "worker",
            WorkloadKind::Cron => "cron",
            WorkloadKind::Proxy => "proxy",
            WorkloadKind::Unknown => "unknown",
        }
    }
    pub fn parse(s: &str) -> Option<WorkloadKind> {
        match s.trim().to_ascii_lowercase().as_str() {
            "datastore" | "database" | "db" => Some(WorkloadKind::Datastore),
            "web" | "frontend" | "api" => Some(WorkloadKind::Web),
            "worker" => Some(WorkloadKind::Worker),
            "cron" | "batch" => Some(WorkloadKind::Cron),
            "proxy" | "gateway" => Some(WorkloadKind::Proxy),
            "unknown" => Some(WorkloadKind::Unknown),
            _ => None,
        }
    }
}

/// The signals used to classify one service.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ServiceView {
    pub name: String,
    pub image: Option<String>,
    pub ports: Vec<String>,
    pub has_persistent_mount: bool,
    pub has_healthcheck: bool,
    pub restart: Option<String>,
    pub label_kind: Option<String>,
}

const PROXY_IMAGES: &[&str] = &["traefik", "caddy", "haproxy", "nginx-proxy-manager"];
const DATA_PORTS: &[&str] = &["5432", "5433", "3306", "6379", "27017"];

fn repo_of(image: &str) -> String {
    let last = image.rsplit('/').next().unwrap_or(image);
    last.split(':').next().unwrap_or(last).to_ascii_lowercase()
}

fn container_port(p: &str) -> String {
    p.rsplit(':')
        .next()
        .unwrap_or(p)
        .split('/')
        .next()
        .unwrap_or("")
        .to_string()
}

fn has_web_port(view: &ServiceView) -> bool {
    view.ports
        .iter()
        .any(|p| matches!(container_port(p).as_str(), "80" | "443" | "8080"))
}

/// Infer the workload kind from signals (no label).
pub fn heuristic_kind(view: &ServiceView) -> WorkloadKind {
    let is_db = view
        .image
        .as_deref()
        .map(|img| detect_db_engine(img, &HashMap::new()).is_some())
        .unwrap_or(false)
        || view
            .ports
            .iter()
            .any(|p| DATA_PORTS.contains(&container_port(p).as_str()));
    if is_db {
        return WorkloadKind::Datastore;
    }

    let is_proxy_img = view
        .image
        .as_deref()
        .map(|img| {
            let repo = repo_of(img);
            PROXY_IMAGES.iter().any(|p| repo.contains(p))
        })
        .unwrap_or(false);
    if is_proxy_img && has_web_port(view) {
        return WorkloadKind::Proxy;
    }

    if view.restart.as_deref() == Some("no") {
        return WorkloadKind::Cron;
    }
    if !view.ports.is_empty() {
        return WorkloadKind::Web;
    }
    if view.restart.is_some() {
        return WorkloadKind::Worker;
    }
    WorkloadKind::Unknown
}

/// The effective kind: an authored label wins, else the heuristic.
pub fn classify(view: &ServiceView) -> WorkloadKind {
    view.label_kind
        .as_deref()
        .and_then(WorkloadKind::parse)
        .unwrap_or_else(|| heuristic_kind(view))
}

/// `Some((authored, heuristic))` when an authored label disagrees with the heuristic.
pub fn disagreement(view: &ServiceView) -> Option<(WorkloadKind, WorkloadKind)> {
    let authored = view.label_kind.as_deref().and_then(WorkloadKind::parse)?;
    let heuristic = heuristic_kind(view);
    (authored != heuristic).then_some((authored, heuristic))
}

/// Extract a [`ServiceView`] per service from a compose document.
pub fn parse_services(yaml: &str) -> Vec<ServiceView> {
    let mut out = Vec::new();
    let Ok(doc) = serde_yaml::from_str::<serde_yaml::Value>(yaml) else {
        return out;
    };
    let Some(services) = doc.get("services").and_then(|v| v.as_mapping()) else {
        return out;
    };
    for (name, svc) in services {
        let ports = svc
            .get("ports")
            .and_then(|v| v.as_sequence())
            .map(|seq| {
                seq.iter()
                    .filter_map(|p| match p {
                        serde_yaml::Value::String(s) => Some(s.clone()),
                        serde_yaml::Value::Number(n) => Some(n.to_string()),
                        _ => None,
                    })
                    .collect()
            })
            .unwrap_or_default();
        let has_persistent_mount = svc
            .get("volumes")
            .and_then(|v| v.as_sequence())
            .map(|s| !s.is_empty())
            .unwrap_or(false);
        out.push(ServiceView {
            name: name.as_str().unwrap_or_default().to_string(),
            image: svc.get("image").and_then(|v| v.as_str()).map(String::from),
            ports,
            has_persistent_mount,
            has_healthcheck: svc.get("healthcheck").is_some(),
            restart: svc.get("restart").and_then(|v| v.as_str()).map(String::from),
            label_kind: label_kind(svc),
        });
    }
    out
}

fn label_kind(svc: &serde_yaml::Value) -> Option<String> {
    let labels = svc.get("labels")?;
    let want = ["yarddog.kind", "x-yarddog.kind"];
    if let Some(map) = labels.as_mapping() {
        for key in want {
            if let Some(v) = map.get(serde_yaml::Value::from(key)).and_then(|v| v.as_str()) {
                return Some(v.to_string());
            }
        }
    } else if let Some(seq) = labels.as_sequence() {
        for item in seq {
            if let Some(s) = item.as_str() {
                if let Some((k, v)) = s.split_once('=') {
                    if want.contains(&k.trim()) {
                        return Some(v.trim().to_string());
                    }
                }
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    fn view(image: Option<&str>, ports: &[&str], restart: Option<&str>) -> ServiceView {
        ServiceView {
            name: "s".into(),
            image: image.map(String::from),
            ports: ports.iter().map(|s| s.to_string()).collect(),
            has_persistent_mount: false,
            has_healthcheck: false,
            restart: restart.map(String::from),
            label_kind: None,
        }
    }

    #[test]
    fn heuristic_classifies_the_common_kinds() {
        assert_eq!(heuristic_kind(&view(Some("postgres:16"), &[], None)), WorkloadKind::Datastore);
        assert_eq!(
            heuristic_kind(&view(Some("traefik:v3"), &["80:80", "443:443"], None)),
            WorkloadKind::Proxy
        );
        assert_eq!(heuristic_kind(&view(Some("nginx:1.27"), &["8080:80"], None)), WorkloadKind::Web);
        assert_eq!(
            heuristic_kind(&view(Some("myworker:1"), &[], Some("unless-stopped"))),
            WorkloadKind::Worker
        );
        assert_eq!(heuristic_kind(&view(Some("backup-job:1"), &[], Some("no"))), WorkloadKind::Cron);
        assert_eq!(heuristic_kind(&view(Some("mystery:1"), &[], None)), WorkloadKind::Unknown);
    }

    #[test]
    fn label_overrides_heuristic_and_disagreement_is_surfaced() {
        let mut v = view(Some("postgres:16"), &[], None); // heuristic = Datastore
        v.label_kind = Some("web".into());
        assert_eq!(classify(&v), WorkloadKind::Web, "authored label wins");
        assert_eq!(
            disagreement(&v),
            Some((WorkloadKind::Web, WorkloadKind::Datastore))
        );

        let mut agree = view(Some("postgres:16"), &[], None);
        agree.label_kind = Some("datastore".into());
        assert_eq!(disagreement(&agree), None);
    }

    #[test]
    fn parse_services_extracts_signals() {
        let yaml = "services:\n  db:\n    image: postgres:16\n    healthcheck:\n      test: [\"CMD\", \"true\"]\n    labels:\n      yarddog.kind: datastore\n  web:\n    image: nginx:1.27\n    ports:\n      - \"8080:80\"\n    restart: unless-stopped\n";
        let views = parse_services(yaml);
        let db = views.iter().find(|v| v.name == "db").unwrap();
        assert_eq!(db.image.as_deref(), Some("postgres:16"));
        assert!(db.has_healthcheck);
        assert_eq!(db.label_kind.as_deref(), Some("datastore"));
        let web = views.iter().find(|v| v.name == "web").unwrap();
        assert_eq!(web.ports, vec!["8080:80".to_string()]);
        assert_eq!(web.restart.as_deref(), Some("unless-stopped"));
    }
}
