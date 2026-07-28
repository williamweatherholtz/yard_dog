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

/// Running service -> container-name map, via `docker compose ps`.
pub fn running_names_via_docker(compose: &Path) -> Option<HashMap<String, String>> {
    let out = std::process::Command::new("docker")
        .args(["compose", "-f"])
        .arg(compose)
        .args(["ps", "--format", "json"])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&out.stdout);
    let mut map = HashMap::new();
    let mut insert = |v: &serde_json::Value| {
        if let (Some(svc), Some(name)) = (v.get("Service").and_then(|x| x.as_str()), v.get("Name").and_then(|x| x.as_str())) {
            map.insert(svc.to_string(), name.to_string());
        }
    };
    let trimmed = text.trim();
    if let Ok(serde_json::Value::Array(items)) = serde_json::from_str::<serde_json::Value>(trimmed) {
        for it in &items {
            insert(it);
        }
    } else {
        for line in trimmed.lines().filter(|l| !l.trim().is_empty()) {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(line) {
                insert(&v);
            }
        }
    }
    Some(map)
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
    match serde_json::from_str::<serde_json::Value>(trimmed) {
        // a JSON array of objects
        Ok(serde_json::Value::Array(items)) => items.iter().for_each(&mut insert),
        // a single (possibly pretty-printed, multi-line) object
        Ok(v @ serde_json::Value::Object(_)) => insert(&v),
        // otherwise newline-delimited JSON objects
        _ => {
            for line in trimmed.lines() {
                if line.trim().is_empty() {
                    continue;
                }
                if let Ok(v) = serde_json::from_str::<serde_json::Value>(line) {
                    insert(&v);
                }
            }
        }
    }
    map
}

/// Canonicalize an image ref for comparison: drop a default `docker.io[/library]/`
/// prefix and make an implicit `:latest` explicit, so declared vs running don't
/// falsely differ on registry qualification or an omitted tag.
pub fn normalize_image(img: &str) -> String {
    // Strip any of Docker Hub's equivalent host prefixes, plus the implicit
    // `library/` namespace for official images.
    let mut s = img;
    for host in ["index.docker.io/", "registry-1.docker.io/", "docker.io/"] {
        if let Some(r) = s.strip_prefix(host) {
            s = r;
            break;
        }
    }
    s = s.strip_prefix("library/").unwrap_or(s);
    // A digest pins the exact image. If a tag is also present (`repo:tag@sha256:…`),
    // the digest is authoritative — drop the tag so `repo:1.2@sha` and `repo@sha`
    // (same digest) don't read as drift.
    if let Some((before, digest)) = s.split_once('@') {
        // Drop a tag only if it's on the final path component (`name:tag`), so a
        // registry `host:port` colon is preserved.
        let (path, name) = match before.rsplit_once('/') {
            Some((p, n)) => (Some(p), n),
            None => (None, before),
        };
        let name = name.split_once(':').map(|(n, _)| n).unwrap_or(name);
        let repo = match path {
            Some(p) => format!("{p}/{name}"),
            None => name.to_string(),
        };
        return format!("{repo}@{digest}");
    }
    let last = s.rsplit('/').next().unwrap_or(s);
    if last.contains(':') {
        s.to_string()
    } else {
        format!("{s}:latest")
    }
}

/// Parse an image ref into `(repo, tag, digest)` after stripping Hub prefixes.
/// A tag/digest is only recognized on the final path component (so a registry
/// `host:port` colon is preserved). Tag defaults to `latest` ONLY when neither a
/// tag nor a digest is present.
fn parse_image_ref(img: &str) -> (String, Option<String>, Option<String>) {
    let mut s = img;
    for host in ["index.docker.io/", "registry-1.docker.io/", "docker.io/"] {
        if let Some(r) = s.strip_prefix(host) {
            s = r;
            break;
        }
    }
    s = s.strip_prefix("library/").unwrap_or(s);
    let (before, digest) = match s.split_once('@') {
        Some((b, d)) => (b, Some(d.to_string())),
        None => (s, None),
    };
    let (path, name) = match before.rsplit_once('/') {
        Some((p, n)) => (Some(p), n),
        None => (None, before),
    };
    let (name_only, tag) = match name.split_once(':') {
        Some((n, t)) => (n, Some(t.to_string())),
        None => (name, None),
    };
    let repo = match path {
        Some(p) => format!("{p}/{name_only}"),
        None => name_only.to_string(),
    };
    let tag = match (tag, &digest) {
        (Some(t), _) => Some(t),
        (None, None) => Some("latest".to_string()), // implicit tag, only when no digest
        (None, Some(_)) => None,
    };
    (repo, tag, digest)
}

/// Whether a declared and a running image ref denote the same image, tolerating
/// asymmetry: a tag-only declared ref (`nginx:1.27`) matches a digest-qualified
/// running ref (`nginx:1.27@sha256:…`). Digests win when BOTH carry one (a
/// same-tag re-push with a new digest is real drift); otherwise compare tags;
/// otherwise (one tag-only, the other digest-only) we can't prove drift, so match.
pub fn images_match(declared: &str, running: &str) -> bool {
    let d = parse_image_ref(declared);
    let r = parse_image_ref(running);
    if d.0 != r.0 {
        return false;
    }
    if let (Some(a), Some(b)) = (&d.2, &r.2) {
        return a == b;
    }
    if let (Some(a), Some(b)) = (&d.1, &r.1) {
        return a == b;
    }
    true
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
            Some(running_image) if !images_match(declared_image, running_image) => out.push(DriftItem {
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

    #[test]
    fn normalize_image_equates_hub_prefixes_and_tag_plus_digest() {
        // fully-qualified Hub hostnames normalize to the short form
        assert_eq!(normalize_image("index.docker.io/library/nginx:1.27"), normalize_image("nginx:1.27"));
        assert_eq!(normalize_image("registry-1.docker.io/library/redis:7"), normalize_image("redis:7"));
        // a tag alongside a digest reduces to the digest (authoritative)
        assert_eq!(normalize_image("repo:1.2@sha256:abc"), normalize_image("repo@sha256:abc"));
        // a private-registry host:port colon is preserved, not mistaken for a tag
        assert_eq!(normalize_image("myreg:5000/app:1.2@sha256:abc"), "myreg:5000/app@sha256:abc");
        // genuinely different images still differ
        assert_ne!(normalize_image("nginx:1.27"), normalize_image("nginx:1.28"));
    }

    #[test]
    fn images_match_tolerates_asymmetric_digest() {
        // tag-only declared vs digest-qualified running (same tag) => NOT drift
        assert!(images_match("nginx:1.27", "nginx:1.27@sha256:abc"));
        assert!(images_match("nginx:1.27", "docker.io/library/nginx:1.27@sha256:abc"));
        // both carry a digest: a same-tag re-push with a new digest IS drift
        assert!(!images_match("repo:1.2@sha256:aaa", "repo:1.2@sha256:bbb"));
        assert!(images_match("repo:1.2@sha256:aaa", "repo@sha256:aaa"));
        // different tags are drift
        assert!(!images_match("nginx:1.27", "nginx:1.28"));
        // tag-only vs digest-only (no shared dimension) — can't prove drift => match
        assert!(images_match("nginx:1.27", "nginx@sha256:abc"));
        // different repos are always drift
        assert!(!images_match("nginx:1.27", "redis:1.27"));
    }

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
