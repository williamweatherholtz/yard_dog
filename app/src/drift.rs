//! Detect drift between the declared compose (intended) and the running stack.
//! The diff is pure; the running-state fetch (docker) plugs into the
//! [`RunningState`] seam. Surfacing declared-vs-running drift is what keeps the
//! tool from silently misreporting state after out-of-band changes.

use crate::compose::parse_service_images;
use std::collections::HashMap;
use std::path::Path;

/// The running service->image map for a compose, via `docker compose ps`. `None`
/// when the daemon is unreachable; an empty map means nothing is running.
pub fn running_images_via_docker(compose: &Path) -> Option<HashMap<String, String>> {
    let out = std::process::Command::new("docker")
        .args(["compose", "-f"])
        .arg(compose)
        .args(["ps", "--format", "json"])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    Some(parse_compose_ps(&String::from_utf8_lossy(&out.stdout)))
}

/// Parse `docker compose ps --format json` output (newline-delimited JSON
/// objects, or a JSON array) into a running service->image map. Pure over the
/// text so the docker shell-out stays a thin adapter.
pub fn parse_compose_ps(output: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    let mut insert = |v: &serde_json::Value| {
        if let (Some(svc), Some(img)) = (v.get("Service").and_then(|x| x.as_str()), v.get("Image").and_then(|x| x.as_str())) {
            map.insert(svc.to_string(), img.to_string());
        }
    };
    let trimmed = output.trim();
    if let Ok(serde_json::Value::Array(items)) = serde_json::from_str::<serde_json::Value>(trimmed) {
        for it in &items {
            insert(it);
        }
    } else {
        for line in trimmed.lines() {
            if line.trim().is_empty() {
                continue;
            }
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(line) {
                insert(&v);
            }
        }
    }
    map
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DriftKind {
    /// Declared in compose but not running.
    Missing,
    /// Running but not declared in compose.
    Unexpected,
    /// Running a different image than declared.
    ImageChanged { declared: String, running: String },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DriftItem {
    pub service: String,
    pub kind: DriftKind,
}

/// Resolves the currently-running service→image map (e.g. via docker).
pub trait RunningState {
    fn running_images(&self) -> Option<HashMap<String, String>>;
}

/// Compare declared images to running images and report drift.
pub fn detect_drift(
    declared: &HashMap<String, String>,
    running: &HashMap<String, String>,
) -> Vec<DriftItem> {
    let mut out = Vec::new();
    for (service, declared_image) in declared {
        match running.get(service) {
            None => out.push(DriftItem {
                service: service.clone(),
                kind: DriftKind::Missing,
            }),
            Some(running_image) if running_image != declared_image => out.push(DriftItem {
                service: service.clone(),
                kind: DriftKind::ImageChanged {
                    declared: declared_image.clone(),
                    running: running_image.clone(),
                },
            }),
            _ => {}
        }
    }
    for service in running.keys() {
        if !declared.contains_key(service) {
            out.push(DriftItem {
                service: service.clone(),
                kind: DriftKind::Unexpected,
            });
        }
    }
    out.sort_by(|a, b| a.service.cmp(&b.service));
    out
}

/// Build declared images from `yaml` and diff against the running state.
/// Returns `None` when the running state is unavailable.
pub fn drift_report(yaml: &str, state: &dyn RunningState) -> Option<Vec<DriftItem>> {
    let running = state.running_images()?;
    let declared = parse_service_images(yaml);
    Some(detect_drift(&declared, &running))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn map(pairs: &[(&str, &str)]) -> HashMap<String, String> {
        pairs.iter().map(|(k, v)| (k.to_string(), v.to_string())).collect()
    }

    #[test]
    fn parse_compose_ps_extracts_service_images() {
        // real `docker compose ps --format json` shape (newline-delimited)
        let ndjson = "{\"Service\":\"web\",\"Image\":\"nginx:1.27-alpine\",\"State\":\"running\"}\n{\"Service\":\"db\",\"Image\":\"postgres:16\",\"State\":\"running\"}";
        let m = parse_compose_ps(ndjson);
        assert_eq!(m.get("web").map(String::as_str), Some("nginx:1.27-alpine"));
        assert_eq!(m.get("db").map(String::as_str), Some("postgres:16"));
        assert_eq!(m.len(), 2);
        // a JSON array is also accepted
        let arr = "[{\"Service\":\"a\",\"Image\":\"img:1\"}]";
        assert_eq!(parse_compose_ps(arr).get("a").map(String::as_str), Some("img:1"));
        // no running containers => empty map (not a crash)
        assert!(parse_compose_ps("").is_empty());
    }

    #[test]
    fn detect_drift_reports_missing_unexpected_and_changed() {
        let declared = map(&[("app", "nginx:1.27"), ("db", "postgres:16")]);
        let running = map(&[("app", "nginx:1.20"), ("extra", "redis:7")]);
        let d = detect_drift(&declared, &running);

        assert!(d.iter().any(|i| i.service == "app" && matches!(i.kind, DriftKind::ImageChanged { .. })));
        assert!(d.iter().any(|i| i.service == "db" && i.kind == DriftKind::Missing));
        assert!(d.iter().any(|i| i.service == "extra" && i.kind == DriftKind::Unexpected));
        assert_eq!(d.len(), 3);

        assert!(detect_drift(&declared, &declared).is_empty(), "no drift when identical");
    }

    #[test]
    fn drift_report_builds_declared_and_handles_unavailable() {
        struct Fixed(Option<HashMap<String, String>>);
        impl RunningState for Fixed {
            fn running_images(&self) -> Option<HashMap<String, String>> {
                self.0.clone()
            }
        }
        let yaml = "services:\n  app:\n    image: nginx:1.27\n";
        let running = Fixed(Some(map(&[("app", "nginx:1.20")])));
        let d = drift_report(yaml, &running).unwrap();
        assert!(d.iter().any(|i| i.service == "app" && matches!(i.kind, DriftKind::ImageChanged { .. })));

        assert!(drift_report(yaml, &Fixed(None)).is_none(), "unavailable running state => None");
    }
}
