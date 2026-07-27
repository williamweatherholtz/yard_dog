//! Detect drift between the declared compose (intended) and the running stack.
//! The diff is pure; the running-state fetch (docker) plugs into the
//! [`RunningState`] seam. Surfacing declared-vs-running drift is what keeps the
//! tool from silently misreporting state after out-of-band changes.

use crate::compose::parse_service_images;
use std::collections::HashMap;

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
