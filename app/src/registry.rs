//! Resolve the current remote digest of a public image tag from a container
//! registry (Docker Hub and GHCR), so `yd updates` can tell when a service's
//! tag has been re-pushed upstream. The image-reference parsing and URL building
//! are pure (unit-tested); the HTTP is a thin `ureq` adapter validated live.

use crate::updates::RegistryClient;

/// A parsed image reference split into the pieces the registry API needs.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ImageRef {
    /// API host, e.g. "registry-1.docker.io" or "ghcr.io".
    pub api_host: String,
    /// Host used to fetch a pull token (Docker Hub uses a separate auth host).
    pub token_url: String,
    /// Repository path, e.g. "library/nginx" or "immich-app/immich-server".
    pub repository: String,
    /// Tag, e.g. "1.27-alpine" (defaults to "latest").
    pub tag: String,
}

/// Parse a compose image string into an [`ImageRef`]. Supports Docker Hub
/// (implicit `docker.io`, official images get the `library/` prefix) and any
/// explicit registry host such as `ghcr.io`. Returns `None` for a digest-pinned
/// reference (nothing to check) or an unparseable string.
pub fn parse_image_ref(image: &str) -> Option<ImageRef> {
    let image = image.trim();
    if image.is_empty() || image.contains('@') {
        // digest-pinned (image@sha256:...) — already exact, no tag to check
        return None;
    }
    // Split an optional registry host off the front: the first path segment is a
    // registry only if it looks like a host (has a dot or colon, or is localhost).
    let (host, remainder) = match image.split_once('/') {
        Some((first, rest)) if first.contains('.') || first.contains(':') || first == "localhost" => {
            (Some(first.to_string()), rest.to_string())
        }
        _ => (None, image.to_string()),
    };

    // Split the tag (a ':' whose remainder has no '/').
    let (repo, tag) = match remainder.rsplit_once(':') {
        Some((r, t)) if !t.contains('/') && !t.is_empty() => (r.to_string(), t.to_string()),
        _ => (remainder.clone(), "latest".to_string()),
    };
    if repo.is_empty() {
        return None;
    }

    match host {
        None => {
            // Docker Hub. Official images (no namespace) live under library/.
            let repository = if repo.contains('/') { repo } else { format!("library/{repo}") };
            Some(ImageRef {
                api_host: "registry-1.docker.io".into(),
                token_url: format!(
                    "https://auth.docker.io/token?service=registry.docker.io&scope=repository:{repository}:pull"
                ),
                repository,
                tag,
            })
        }
        Some(h) if h == "docker.io" || h == "index.docker.io" => {
            let repository = if repo.contains('/') { repo } else { format!("library/{repo}") };
            Some(ImageRef {
                api_host: "registry-1.docker.io".into(),
                token_url: format!(
                    "https://auth.docker.io/token?service=registry.docker.io&scope=repository:{repository}:pull"
                ),
                repository,
                tag,
            })
        }
        Some(h) => {
            // GHCR and other token-per-host registries: token is served from the
            // registry host itself at /token.
            Some(ImageRef {
                token_url: format!("https://{h}/token?scope=repository:{repo}:pull"),
                api_host: h,
                repository: repo,
                tag,
            })
        }
    }
}

impl ImageRef {
    /// The manifest URL whose `Docker-Content-Digest` header is the tag's digest.
    pub fn manifest_url(&self) -> String {
        format!("https://{}/v2/{}/manifests/{}", self.api_host, self.repository, self.tag)
    }
}

const MANIFEST_ACCEPT: &str = "application/vnd.oci.image.index.v1+json, \
application/vnd.docker.distribution.manifest.list.v2+json, \
application/vnd.oci.image.manifest.v1+json, \
application/vnd.docker.distribution.manifest.v2+json";

/// A [`RegistryClient`] that fetches remote digests over HTTPS (public images).
pub struct HttpRegistryClient;

/// An agent with connect + read timeouts, so a slow/hostile registry can't hang
/// a request-serving thread indefinitely.
fn agent() -> ureq::Agent {
    ureq::AgentBuilder::new()
        .timeout_connect(std::time::Duration::from_secs(5))
        .timeout(std::time::Duration::from_secs(15))
        .build()
}

/// Reject registry hosts that resolve to loopback/private/link-local space, so a
/// crafted `image:` (e.g. `169.254.169.254/x` or `localhost:9000/x`) can't turn
/// the update check into an SSRF against internal services / cloud metadata.
pub fn host_is_public(host: &str) -> bool {
    let hostname = if host.starts_with('[') {
        host.trim_start_matches('[').split(']').next().unwrap_or(host)
    } else if let Some((h, p)) = host.rsplit_once(':') {
        if !h.is_empty() && p.chars().all(|c| c.is_ascii_digit()) { h } else { host }
    } else {
        host
    };
    let lower = hostname.to_ascii_lowercase();
    if lower == "localhost" || lower.ends_with(".localhost") {
        return false;
    }
    if let Ok(ip) = hostname.parse::<std::net::IpAddr>() {
        if ip.is_loopback() || ip.is_unspecified() {
            return false;
        }
        match ip {
            std::net::IpAddr::V4(v4) => {
                if v4.is_private() || v4.is_link_local() {
                    return false; // 10/8, 172.16/12, 192.168/16, 169.254/16
                }
            }
            std::net::IpAddr::V6(v6) => {
                let seg0 = v6.segments()[0];
                if (seg0 & 0xfe00) == 0xfc00 || (seg0 & 0xffc0) == 0xfe80 {
                    return false; // ULA fc00::/7, link-local fe80::/10
                }
            }
        }
    }
    true
}

impl HttpRegistryClient {
    fn fetch_digest(image: &str) -> Option<String> {
        let r = parse_image_ref(image)?;
        if !host_is_public(&r.api_host) {
            return None; // SSRF guard — never dial internal/loopback registries
        }
        let ag = agent();
        // Anonymous pull token.
        let body = ag.get(&r.token_url).call().ok()?.into_string().ok()?;
        let token = serde_json::from_str::<serde_json::Value>(&body)
            .ok()?
            .get("token")
            .and_then(|t| t.as_str())
            .map(|s| s.to_string())?;
        // The digest is returned in a header; a HEAD is enough.
        let resp = ag
            .head(&r.manifest_url())
            .set("Authorization", &format!("Bearer {token}"))
            .set("Accept", MANIFEST_ACCEPT)
            .call()
            .ok()?;
        resp.header("Docker-Content-Digest").map(|s| s.to_string())
    }
}

impl RegistryClient for HttpRegistryClient {
    fn remote_digest(&self, image: &str) -> Option<String> {
        Self::fetch_digest(image)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_docker_hub_official_image() {
        let r = parse_image_ref("nginx:1.27-alpine").unwrap();
        assert_eq!(r.api_host, "registry-1.docker.io");
        assert_eq!(r.repository, "library/nginx");
        assert_eq!(r.tag, "1.27-alpine");
        assert_eq!(r.manifest_url(), "https://registry-1.docker.io/v2/library/nginx/manifests/1.27-alpine");
        assert!(r.token_url.contains("auth.docker.io"));
        assert!(r.token_url.contains("repository:library/nginx:pull"));
    }

    #[test]
    fn parses_docker_hub_namespaced_image_and_default_tag() {
        let r = parse_image_ref("linuxserver/sonarr").unwrap();
        assert_eq!(r.repository, "linuxserver/sonarr", "namespaced repo keeps its namespace");
        assert_eq!(r.tag, "latest", "no tag defaults to latest");
    }

    #[test]
    fn parses_ghcr_image() {
        let r = parse_image_ref("ghcr.io/immich-app/immich-server:v1.100.0").unwrap();
        assert_eq!(r.api_host, "ghcr.io");
        assert_eq!(r.repository, "immich-app/immich-server");
        assert_eq!(r.tag, "v1.100.0");
        assert_eq!(r.manifest_url(), "https://ghcr.io/v2/immich-app/immich-server/manifests/v1.100.0");
        assert!(r.token_url.starts_with("https://ghcr.io/token?"));
    }

    #[test]
    fn digest_pinned_reference_has_nothing_to_check() {
        assert!(parse_image_ref("nginx@sha256:abc123").is_none());
        assert!(parse_image_ref("").is_none());
    }

    // Live network test (opt-in): proves the Docker Hub AND GHCR token+manifest
    // flow returns a real digest. Run with:
    //   cargo test --lib -- --ignored registry::tests::remote_digest_live
    #[test]
    #[ignore = "requires network"]
    fn remote_digest_live_resolves_dockerhub_and_ghcr() {
        let c = HttpRegistryClient;
        let hub = c.remote_digest("nginx:1.27-alpine");
        assert!(hub.as_deref().map(|d| d.starts_with("sha256:")).unwrap_or(false), "docker hub digest: {hub:?}");
        let ghcr = c.remote_digest("ghcr.io/astral-sh/uv:latest");
        assert!(ghcr.as_deref().map(|d| d.starts_with("sha256:")).unwrap_or(false), "ghcr digest: {ghcr:?}");
    }
}
