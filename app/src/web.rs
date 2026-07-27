//! `yd serve` — a loopback-only browser control plane. It is a thin wrapper over
//! the same library the CLI uses (read/detail views) and over the `yd` binary
//! itself (actions, via an argument vector — never a shell — so there is no
//! command injection). Security posture (needSecureByDefault):
//!   * binds 127.0.0.1 ONLY (never 0.0.0.0);
//!   * rejects any request whose Host header is not a loopback name/address,
//!     which defeats DNS-rebinding attacks against a no-auth local server;
//!   * mutations are POST-only;
//!   * every path parameter is confined under the served root (no absolute
//!     paths, no `..`), so the API can never read or write outside it.

use crate::classify::{MountType, NetworkProbe, VolumeInfo, VolumeInspector};
use crate::drift::{self, DriftKind};
use crate::lifecycle::LifecycleState;
use crate::remediation::Issue;
use crate::{compose, gitver, guardrails, hostfs, lifecycle, preflight, registry, report, stacks, stats, updates, verify, workload};
use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use tiny_http::{Header, Method, Response, Server};

/// True if `host` (a Host header, possibly with a port) is a loopback address or
/// `localhost`. Real 127.0.0.0/8 and ::1 pass; a domain like `127.evil.com` does
/// not (it is not a parseable loopback IP).
pub fn host_is_loopback(host: &str) -> bool {
    let hostname = if let Some(rest) = host.strip_prefix('[') {
        // IPv6 literal: [::1]:port
        rest.split(']').next().unwrap_or("")
    } else {
        host.rsplit_once(':').map(|(h, _)| h).unwrap_or(host)
    };
    if hostname == "localhost" {
        return true;
    }
    hostname
        .parse::<std::net::IpAddr>()
        .map(|ip| ip.is_loopback())
        .unwrap_or(false)
}

/// Confine a client-supplied path under `root`: reject absolute paths and any
/// `..` component, then join. The result is guaranteed to be within `root`.
pub fn safe_join(root: &Path, rel: &str) -> Option<PathBuf> {
    use std::path::Component;
    let p = Path::new(rel);
    if rel.is_empty() {
        return None;
    }
    // Allow only plain relative components — reject `..`, and any absolute marker
    // (RootDir like "/etc", or a Windows drive Prefix like "C:\"). This holds on
    // every platform, where `is_absolute()` alone does not (e.g. "/x" on Windows).
    for c in p.components() {
        match c {
            Component::Normal(_) | Component::CurDir => {}
            _ => return None,
        }
    }
    Some(root.join(p))
}

/// A lifecycle event name the API accepts (allow-list, not free text).
fn valid_event(ev: &str) -> bool {
    matches!(ev, "activate" | "deprecate" | "archive" | "restore")
}

/// Whether a mutating (POST) request may proceed — the anti-CSRF gate. Requires
/// `Content-Type: application/json` (a non-"simple" type, so a cross-origin POST
/// triggers a CORS preflight the server never allows), and refuses any request
/// carrying an `Origin` that is not loopback. Together with the loopback bind and
/// Host allowlist this blocks a visited page from driving actions on the host.
pub fn mutation_allowed(content_type: Option<&str>, origin: Option<&str>) -> bool {
    let ct_ok = content_type
        .map(|c| c.trim().to_ascii_lowercase().starts_with("application/json"))
        .unwrap_or(false);
    if !ct_ok {
        return false;
    }
    match origin {
        None => true,
        Some(o) => {
            // Origin is "scheme://host[:port]"; check the host is loopback.
            let host = o.split("://").nth(1).unwrap_or(o);
            host_is_loopback(host)
        }
    }
}

// ---- JSON read views (pure over the library) ---------------------------------

fn json_escape(s: &str) -> String {
    serde_json::Value::String(s.to_string()).to_string()
}

/// JSON array of guardrail findings.
fn findings_json(findings: &[guardrails::Finding]) -> String {
    let items: Vec<String> = findings
        .iter()
        .map(|f| {
            let sev = match f.severity {
                guardrails::Severity::Block => "block",
                guardrails::Severity::Warn => "warn",
            };
            format!(
                "{{\"service\":{},\"rule\":{},\"severity\":{},\"message\":{}}}",
                json_escape(&f.service),
                json_escape(&f.rule),
                json_escape(sev),
                json_escape(&f.message)
            )
        })
        .collect();
    format!("[{}]", items.join(","))
}

// No-daemon probes: host-bind classification + existence (the core "is this a
// local path?" read) work without Docker; named-volume driver / network refinement
// is degraded to shape-based classification in v1.
struct NoVolumes;
impl VolumeInspector for NoVolumes {
    fn inspect(&self, _name: &str) -> Option<VolumeInfo> {
        None
    }
}
struct NoNet;
impl NetworkProbe for NoNet {
    fn fs_type(&self, _path: &str) -> Option<String> {
        None
    }
}

/// Resolve relative host-bind sources (e.g. `./html`) against the stack directory
/// — as docker compose does — so existence checks are correct regardless of the
/// server's working directory. Named volumes (bare tokens) are left untouched.
fn resolve_bind_sources(mounts: Vec<compose::RawMount>, stack_dir: &Path) -> Vec<compose::RawMount> {
    mounts
        .into_iter()
        .map(|mut m| {
            if let Some(src) = &m.source {
                let is_host_path = src.starts_with("./") || src.starts_with("../") || src.starts_with('.') && src.contains('/') || src.contains('/');
                let is_absolute = src.starts_with('/') || src.starts_with('~');
                if is_host_path && !is_absolute {
                    m.source = Some(stack_dir.join(src).to_string_lossy().replace('\\', "/"));
                }
            }
            m
        })
        .collect()
}

fn mount_type_str(t: MountType) -> &'static str {
    match t {
        MountType::HostBind => "host-bind",
        MountType::NamedVolume => "named-volume",
        MountType::Anonymous => "anonymous",
        MountType::Network => "network",
    }
}

/// `GET /api/mounts?compose=REL` — mount typing + existence + remediation.
fn mounts_json(root: &Path, rel: &str) -> Option<String> {
    let p = safe_join(root, rel)?;
    let yaml = std::fs::read_to_string(&p).ok()?;
    let env: HashMap<String, String> = std::env::vars().collect();
    let stack_dir = p.parent().unwrap_or(root);
    let mounts = resolve_bind_sources(compose::parse_mounts(&yaml, &env).ok()?, stack_dir);
    let mut ids = HashMap::new();
    for (svc, (u, g)) in compose::parse_service_ids(&yaml, &env) {
        if let (Some(u), Some(g)) = (u, g) {
            ids.insert(svc, (u, g));
        }
    }
    let reports = report::build_report(&mounts, &NoVolumes, &NoNet, &hostfs::RealFs, &ids);
    let items: Vec<String> = reports
        .iter()
        .map(|m| {
            let exists = match &m.existence {
                Some(e) => e.exists.to_string(),
                None => "null".to_string(),
            };
            let rems: Vec<String> = m
                .remediations
                .iter()
                .map(|r| {
                    format!(
                        "{{\"summary\":{},\"command\":{}}}",
                        json_escape(&r.summary),
                        r.command.as_deref().map(json_escape).unwrap_or_else(|| "null".into())
                    )
                })
                .collect();
            format!(
                "{{\"service\":{},\"target\":{},\"source\":{},\"type\":\"{}\",\"exists\":{},\"issues\":{},\"remediations\":[{}]}}",
                json_escape(&m.service),
                json_escape(&m.target),
                m.source.as_deref().map(json_escape).unwrap_or_else(|| "null".into()),
                mount_type_str(m.mount_type),
                exists,
                m.issues.len(),
                rems.join(",")
            )
        })
        .collect();
    Some(format!("{{\"items\":[{}]}}", items.join(",")))
}

/// `GET /api/permissions?compose=REL` — security lens + ownership => compliance.
fn permissions_json(root: &Path, rel: &str) -> Option<String> {
    let p = safe_join(root, rel)?;
    let yaml = std::fs::read_to_string(&p).ok()?;
    let sec_rules = ["privileged", "docker-socket", "dangerous-cap", "host-network", "host-pid", "plaintext-secret"];
    let mut findings: Vec<String> = Vec::new();
    let mut compliant = true;
    for f in guardrails::run_guardrails(&yaml) {
        if sec_rules.contains(&f.rule.as_str()) {
            let sev = match f.severity {
                guardrails::Severity::Block => "block",
                guardrails::Severity::Warn => "warn",
            };
            if f.severity == guardrails::Severity::Block {
                compliant = false;
            }
            findings.push(format!(
                "{{\"severity\":\"{}\",\"rule\":{},\"service\":{},\"message\":{}}}",
                sev, json_escape(&f.rule), json_escape(&f.service), json_escape(&f.message)
            ));
        }
    }
    // ownership problems on bind paths
    let env: HashMap<String, String> = std::env::vars().collect();
    if let Ok(mounts) = compose::parse_mounts(&yaml, &env) {
        let mut ids = HashMap::new();
        for (svc, (u, g)) in compose::parse_service_ids(&yaml, &env) {
            if let (Some(u), Some(g)) = (u, g) {
                ids.insert(svc, (u, g));
            }
        }
        for m in report::build_report(&mounts, &NoVolumes, &NoNet, &hostfs::RealFs, &ids) {
            for iss in &m.issues {
                if let Issue::Ownership { path, .. } = iss {
                    compliant = false;
                    findings.push(format!(
                        "{{\"severity\":\"warn\",\"rule\":\"ownership\",\"service\":{},\"message\":{}}}",
                        json_escape(&m.service),
                        json_escape(&format!("ownership/permission issue on {path}"))
                    ));
                }
            }
        }
    }
    Some(format!("{{\"compliant\":{},\"findings\":[{}]}}", compliant, findings.join(",")))
}

/// `GET /api/backups?compose=REL` — recovery points + verify status. A backup
/// dest holds its manifest.json at its root (that dest IS one recovery point);
/// a dest that instead contains timestamped subdirs is treated as many.
fn backups_json(root: &Path, rel: &str) -> Option<String> {
    let p = safe_join(root, rel)?;
    let base = p.parent()?.join(".yd-backups");
    let mut items: Vec<String> = Vec::new();

    let report_point = |dir: &Path, name: &str| -> Option<String> {
        let m = std::fs::read_to_string(dir.join("manifest.json"))
            .ok()
            .and_then(|s| serde_json::from_str::<verify::Manifest>(&s).ok())?;
        let findings = verify::verify(dir, &m).unwrap_or_default();
        Some(format!(
            "{{\"name\":{},\"entries\":{},\"issues\":{},\"ok\":{}}}",
            json_escape(name), m.entries.len(), findings.len(), findings.is_empty()
        ))
    };

    // The dest itself is a recovery point when it has a manifest at its root.
    if let Some(pt) = report_point(&base, ".yd-backups") {
        items.push(pt);
    } else if let Ok(rd) = std::fs::read_dir(&base) {
        // else treat manifest-bearing subdirs as recovery points.
        for entry in rd.flatten() {
            if entry.file_type().map(|t| t.is_dir()).unwrap_or(false) {
                let name = entry.file_name().to_string_lossy().to_string();
                if let Some(pt) = report_point(&entry.path(), &name) {
                    items.push(pt);
                }
            }
        }
    }
    Some(format!("{{\"items\":[{}]}}", items.join(",")))
}

/// `GET /api/git` — the monorepo's remote status (remote URL + ahead/behind).
fn git_status_json(root: &Path) -> String {
    let remote = gitver::remote_url(root);
    let (ahead, behind) = if remote.is_some() {
        gitver::ahead_behind(root).map(|(a, b)| (a as i64, b as i64)).unwrap_or((-1, -1))
    } else {
        (-1, -1)
    };
    format!(
        "{{\"remote\":{},\"ahead\":{},\"behind\":{}}}",
        remote.map(|u| json_escape(&u)).unwrap_or_else(|| "null".into()),
        ahead,
        behind
    )
}

/// A plausible git remote URL (https/ssh/scp-style or a local path); rejects
/// control characters. Auth itself is the operator's system git, not stored here.
fn valid_remote_url(url: &str) -> bool {
    if url.is_empty() || url.chars().any(|c| c.is_control()) {
        return false;
    }
    url.starts_with("https://")
        || url.starts_with("http://")
        || url.starts_with("ssh://")
        || url.starts_with("git@")
        || url.starts_with("git://")
        || url.starts_with("file://")
        || Path::new(url).is_absolute() // a local / NAS-mounted bare repo path
}

/// `GET /api/stats?compose=REL` — per-service live CPU/memory (docker stats).
fn stats_json(root: &Path, rel: &str) -> Option<String> {
    let p = safe_join(root, rel)?;
    let names = drift::running_names_via_docker(&p).unwrap_or_default();
    let by_name = stats::stats_via_docker(&names.values().cloned().collect::<Vec<_>>());
    let items: Vec<String> = names
        .iter()
        .map(|(svc, name)| {
            let (cpu, mem) = by_name.get(name).map(|s| (s.cpu.clone(), s.mem.clone())).unwrap_or_default();
            format!("{{\"service\":{},\"cpu\":{},\"mem\":{}}}", json_escape(svc), json_escape(&cpu), json_escape(&mem))
        })
        .collect();
    Some(format!("{{\"items\":[{}]}}", items.join(",")))
}

/// `GET /api/compose?compose=REL` — the raw compose text for the editor.
fn compose_text_json(root: &Path, rel: &str) -> Option<String> {
    let p = safe_join(root, rel)?;
    let yaml = std::fs::read_to_string(&p).ok()?;
    Some(format!("{{\"yaml\":{}}}", json_escape(&yaml)))
}

/// The stack's path relative to the (mono)repo root, from a compose rel path.
fn stack_rel(compose_rel: &str) -> PathBuf {
    Path::new(compose_rel).parent().map(|p| p.to_path_buf()).unwrap_or_else(|| PathBuf::from("."))
}

/// `GET /api/history?compose=REL` — snapshots for the stack, newest-first.
fn history_json(root: &Path, rel: &str) -> Option<String> {
    safe_join(root, rel)?; // reject paths outside root
    let items: Vec<String> = gitver::history_scoped(root, &stack_rel(rel))
        .unwrap_or_default()
        .iter()
        .map(|(sha, msg)| format!("{{\"sha\":{},\"message\":{}}}", json_escape(sha), json_escape(msg)))
        .collect();
    Some(format!("{{\"items\":[{}]}}", items.join(",")))
}

/// `GET /api/diff?compose=REL&from=SHA[&to=SHA]` — unified diff of the config.
fn diff_json(root: &Path, query: &str) -> Option<String> {
    let rel = query_param(query, "compose")?;
    let from = query_param(query, "from")?;
    let to = query_param(query, "to");
    safe_join(root, &rel)?;
    let d = gitver::diff_scoped(root, &stack_rel(&rel), &from, to.as_deref()).unwrap_or_default();
    Some(format!("{{\"diff\":{}}}", json_escape(&d)))
}

/// `GET /api/stacks` — the stacks discovered under root, each with lifecycle.
fn stacks_json(root: &Path) -> String {
    let list = stacks::discover_stacks(root).unwrap_or_default();
    let items: Vec<String> = list
        .iter()
        .map(|s| {
            let rel = s
                .compose_path
                .strip_prefix(root)
                .unwrap_or(&s.compose_path)
                .to_string_lossy()
                .replace('\\', "/");
            let dir = s.compose_path.parent().unwrap_or(root);
            let state = lifecycle::read_state(dir);
            let yaml = std::fs::read_to_string(&s.compose_path).unwrap_or_default();
            let n = workload::parse_services(&yaml).len();
            let findings = guardrails::run_guardrails(&yaml);
            let blocks = findings.iter().filter(|f| f.severity == guardrails::Severity::Block).count();
            let warns = findings.iter().filter(|f| f.severity == guardrails::Severity::Warn).count();
            format!(
                "{{\"name\":{},\"compose\":{},\"lifecycle\":{},\"services\":{},\"blocks\":{},\"warns\":{}}}",
                json_escape(&s.name),
                json_escape(&rel),
                json_escape(state.as_str()),
                n,
                blocks,
                warns
            )
        })
        .collect();
    format!("{{\"root\":{},\"stacks\":[{}]}}", json_escape(&root.to_string_lossy()), items.join(","))
}

/// `GET /api/stack?compose=REL` — detail: services, guardrails, preflight, state.
fn stack_detail_json(root: &Path, rel: &str) -> Option<String> {
    let compose = safe_join(root, rel)?;
    let yaml = std::fs::read_to_string(&compose).ok()?;
    let dir = compose.parent().unwrap_or(root);
    let state = lifecycle::read_state(dir);
    let services: Vec<String> = workload::parse_services(&yaml)
        .iter()
        .map(|s| {
            let kind = workload::classify(s);
            format!(
                "{{\"name\":{},\"image\":{},\"kind\":{}}}",
                json_escape(&s.name),
                json_escape(s.image.as_deref().unwrap_or("")),
                json_escape(kind.as_str())
            )
        })
        .collect();
    let findings: Vec<String> = guardrails::run_guardrails(&yaml)
        .iter()
        .map(|f| {
            let sev = match f.severity {
                guardrails::Severity::Block => "block",
                guardrails::Severity::Warn => "warn",
            };
            format!(
                "{{\"service\":{},\"rule\":{},\"severity\":{},\"message\":{}}}",
                json_escape(&f.service),
                json_escape(&f.rule),
                json_escape(sev),
                json_escape(&f.message)
            )
        })
        .collect();
    let p = preflight::assess(&yaml, state);
    Some(format!(
        "{{\"compose\":{},\"lifecycle\":{},\"ready\":{},\"blocks\":{},\"warns\":{},\"services\":[{}],\"guardrails\":[{}]}}",
        json_escape(rel),
        json_escape(state.as_str()),
        p.ready,
        p.blocks,
        p.warns,
        services.join(","),
        findings.join(",")
    ))
}

// ---- action handlers (exec the yd binary; no shell) --------------------------

/// Path to this binary, so the server invokes the same `yd` it ships with.
fn yd_bin() -> PathBuf {
    std::env::current_exe().unwrap_or_else(|_| PathBuf::from("yd"))
}

/// Run `yd` (or docker) with a fixed arg vector; return a JSON result object.
fn run_tool(program: &Path, args: &[String]) -> String {
    match std::process::Command::new(program).args(args).output() {
        Ok(out) => format!(
            "{{\"ok\":{},\"exit\":{},\"stdout\":{},\"stderr\":{}}}",
            out.status.success(),
            out.status.code().unwrap_or(-1),
            json_escape(&String::from_utf8_lossy(&out.stdout)),
            json_escape(&String::from_utf8_lossy(&out.stderr))
        ),
        Err(e) => format!("{{\"ok\":false,\"exit\":-1,\"stdout\":\"\",\"stderr\":{}}}", json_escape(&e.to_string())),
    }
}

fn field<'a>(v: &'a serde_json::Value, k: &str) -> Option<&'a str> {
    v.get(k).and_then(|x| x.as_str())
}

/// Dispatch a POST action. Returns (status, json body).
fn handle_action(root: &Path, path: &str, body: &str) -> (u16, String) {
    let Ok(v) = serde_json::from_str::<serde_json::Value>(body) else {
        return (400, "{\"error\":\"invalid json\"}".into());
    };
    let yd = yd_bin();
    let bad = |m: &str| (400u16, format!("{{\"error\":{}}}", json_escape(m)));
    let compose_abs = |rel: &str| safe_join(root, rel).map(|p| p.to_string_lossy().to_string());

    match path {
        "/api/deploy" => {
            let Some(rel) = field(&v, "compose") else { return bad("compose required") };
            let Some(abs) = compose_abs(rel) else { return bad("path outside root") };
            (200, run_tool(&yd, &["deploy".into(), abs, "--yes".into()]))
        }
        "/api/down" => {
            let Some(rel) = field(&v, "compose") else { return bad("compose required") };
            let Some(abs) = compose_abs(rel) else { return bad("path outside root") };
            (200, run_tool(Path::new("docker"), &["compose".into(), "-f".into(), abs, "down".into()]))
        }
        "/api/upgrade" => {
            let (Some(rel), Some(service), Some(image)) = (field(&v, "compose"), field(&v, "service"), field(&v, "image")) else {
                return bad("compose, service, image required");
            };
            let Some(abs) = compose_abs(rel) else { return bad("path outside root") };
            let repo = Path::new(&abs).parent().map(|p| p.to_string_lossy().to_string()).unwrap_or(abs.clone());
            (200, run_tool(&yd, &["upgrade".into(), abs, "--repo".into(), repo, "--service".into(), service.into(), "--image".into(), image.into(), "--yes".into()]))
        }
        "/api/lifecycle" => {
            let (Some(rel), Some(event)) = (field(&v, "compose"), field(&v, "event")) else {
                return bad("compose, event required");
            };
            if !valid_event(event) {
                return bad("invalid event");
            }
            let Some(abs) = compose_abs(rel) else { return bad("path outside root") };
            let repo = Path::new(&abs).parent().map(|p| p.to_string_lossy().to_string()).unwrap_or(abs);
            (200, run_tool(&yd, &["lifecycle".into(), "--repo".into(), repo, "--event".into(), event.into()]))
        }
        "/api/backup" => {
            let Some(rel) = field(&v, "compose") else { return bad("compose required") };
            let dest = field(&v, "dest").unwrap_or(".yd-backups");
            if safe_join(root, dest).is_none() {
                return bad("dest outside root");
            }
            let Some(abs) = compose_abs(rel) else { return bad("path outside root") };
            (200, run_tool(&yd, &["backup".into(), abs, "--run".into(), "--dest".into(), dest.into()]))
        }
        // Live validation for the editor: guardrails + preflight over posted YAML,
        // no write. Lifecycle is treated as Draft (the gate is not about the text).
        "/api/validate" => {
            let yaml = field(&v, "yaml").unwrap_or("");
            let findings = guardrails::run_guardrails(yaml);
            let p = preflight::assess(yaml, LifecycleState::Draft);
            (200, format!(
                "{{\"ready\":{},\"blocks\":{},\"warns\":{},\"guardrails\":{}}}",
                p.ready, p.blocks, p.warns, findings_json(&findings)
            ))
        }
        // Save the edited compose and snapshot it (git). Does not deploy.
        "/api/save" => {
            let (Some(rel), Some(yaml)) = (field(&v, "compose"), field(&v, "yaml")) else {
                return bad("compose and yaml required");
            };
            let Some(abs) = safe_join(root, rel) else { return bad("path outside root") };
            let dir = match abs.parent() {
                Some(d) => d.to_path_buf(),
                None => return bad("bad path"),
            };
            let sr = stack_rel(rel);
            let result = (|| -> std::io::Result<String> {
                std::fs::create_dir_all(&dir)?;
                std::fs::write(&abs, yaml)?;
                gitver::ensure_repo(root)?;
                gitver::snapshot_scoped(root, &sr, "yd ui edit")
            })();
            match result {
                Ok(sha) => (200, format!("{{\"ok\":true,\"sha\":{}}}", json_escape(&sha))),
                Err(e) => (200, format!("{{\"ok\":false,\"error\":{}}}", json_escape(&e.to_string()))),
            }
        }
        // Restore a past snapshot (snapshots current first). Does not redeploy.
        "/api/restore" => {
            let (Some(rel), Some(sha)) = (field(&v, "compose"), field(&v, "sha")) else {
                return bad("compose and sha required");
            };
            if safe_join(root, rel).is_none() {
                return bad("path outside root");
            }
            let sr = stack_rel(rel);
            let result = (|| -> std::io::Result<String> {
                gitver::ensure_repo(root)?;
                gitver::snapshot_scoped(root, &sr, "yd ui pre-restore")?;
                gitver::restore_scoped(root, &sr, sha)
            })();
            match result {
                Ok(new_sha) => (200, format!("{{\"ok\":true,\"sha\":{}}}", json_escape(&new_sha))),
                Err(e) => (200, format!("{{\"ok\":false,\"error\":{}}}", json_escape(&e.to_string()))),
            }
        }
        // Git remote sync on the monorepo root (auth is the operator's system git).
        "/api/git/connect" => {
            let Some(url) = field(&v, "url") else { return bad("url required") };
            if !valid_remote_url(url) {
                return bad("not a valid git remote URL (https/ssh/git@)");
            }
            match gitver::set_remote(root, url) {
                Ok(()) => (200, "{\"ok\":true}".into()),
                Err(e) => (200, format!("{{\"ok\":false,\"error\":{}}}", json_escape(&e.to_string()))),
            }
        }
        "/api/git/push" => match gitver::push(root) {
            Ok(out) => (200, format!("{{\"ok\":true,\"stdout\":{}}}", json_escape(&out))),
            Err(e) => (200, format!("{{\"ok\":false,\"stderr\":{}}}", json_escape(&e.to_string()))),
        },
        "/api/git/pull" => match gitver::pull(root) {
            Ok(out) => (200, format!("{{\"ok\":true,\"stdout\":{}}}", json_escape(&out))),
            Err(e) => (200, format!("{{\"ok\":false,\"stderr\":{}}}", json_escape(&e.to_string()))),
        },
        _ => (404, "{\"error\":\"unknown action\"}".into()),
    }
}

const UI_HTML: &str = include_str!("ui.html");

fn header(name: &str, value: &str) -> Header {
    Header::from_bytes(name.as_bytes(), value.as_bytes()).unwrap()
}

fn json_response(status: u16, body: String) -> Response<io::Cursor<Vec<u8>>> {
    Response::from_string(body)
        .with_status_code(status)
        .with_header(header("Content-Type", "application/json"))
}

/// Start the loopback control-plane server. Never binds anything but 127.0.0.1.
pub fn serve(port: u16, root: &Path) -> io::Result<()> {
    let root = root.canonicalize().unwrap_or_else(|_| root.to_path_buf());
    // The served root IS the monorepo (decGitVersioning): one repo, per-stack
    // snapshots scoped by path. Initialise it once on startup, with an initial
    // commit so remote sync (push) works immediately.
    let _ = gitver::ensure_repo(&root);
    if gitver::history(&root).map(|h| h.is_empty()).unwrap_or(true) {
        let _ = gitver::snapshot(&root, "yd: initialize config repo");
    }
    let server = Server::http(("127.0.0.1", port))
        .map_err(|e| io::Error::new(io::ErrorKind::Other, format!("cannot bind 127.0.0.1:{port}: {e}")))?;
    println!("Yard Dog control plane on http://127.0.0.1:{port}  (loopback only — Ctrl-C to stop)");
    println!("serving stacks under {}", root.display());

    for mut request in server.incoming_requests() {
        // Security: refuse any non-loopback Host (DNS-rebinding defense).
        let host_ok = request
            .headers()
            .iter()
            .find(|h| h.field.equiv("Host"))
            .map(|h| host_is_loopback(h.value.as_str()))
            .unwrap_or(false);
        if !host_ok {
            let _ = request.respond(json_response(403, "{\"error\":\"forbidden host\"}".into()));
            continue;
        }

        let method = request.method().clone();
        let url = request.url().to_string();
        let path = url.split('?').next().unwrap_or("").to_string();
        let query = url.split_once('?').map(|(_, q)| q.to_string()).unwrap_or_default();

        let response: Response<io::Cursor<Vec<u8>>> = match (&method, path.as_str()) {
            (Method::Get, "/") | (Method::Get, "/index.html") => Response::from_string(UI_HTML)
                .with_header(header("Content-Type", "text/html; charset=utf-8")),
            (Method::Get, "/api/stacks") => json_response(200, stacks_json(&root)),
            (Method::Get, "/api/stack") => {
                match query_param(&query, "compose").and_then(|rel| stack_detail_json(&root, &rel)) {
                    Some(body) => json_response(200, body),
                    None => json_response(404, "{\"error\":\"not found or outside root\"}".into()),
                }
            }
            (Method::Get, "/api/drift") => match query_param(&query, "compose").and_then(|r| drift_json(&root, &r)) {
                Some(b) => json_response(200, b),
                None => json_response(400, "{\"error\":\"compose required or outside root\"}".into()),
            },
            (Method::Get, "/api/updates") => match query_param(&query, "compose").and_then(|r| updates_json(&root, &r)) {
                Some(b) => json_response(200, b),
                None => json_response(400, "{\"error\":\"compose required or outside root\"}".into()),
            },
            (Method::Get, "/api/compose") => match query_param(&query, "compose").and_then(|r| compose_text_json(&root, &r)) {
                Some(b) => json_response(200, b),
                None => json_response(404, "{\"error\":\"not found or outside root\"}".into()),
            },
            (Method::Get, "/api/history") => match query_param(&query, "compose").and_then(|r| history_json(&root, &r)) {
                Some(b) => json_response(200, b),
                None => json_response(400, "{\"error\":\"compose required or outside root\"}".into()),
            },
            (Method::Get, "/api/diff") => match diff_json(&root, &query) {
                Some(b) => json_response(200, b),
                None => json_response(400, "{\"error\":\"compose + from required\"}".into()),
            },
            (Method::Get, "/api/mounts") => match query_param(&query, "compose").and_then(|r| mounts_json(&root, &r)) {
                Some(b) => json_response(200, b),
                None => json_response(400, "{\"error\":\"compose required or outside root\"}".into()),
            },
            (Method::Get, "/api/permissions") => match query_param(&query, "compose").and_then(|r| permissions_json(&root, &r)) {
                Some(b) => json_response(200, b),
                None => json_response(400, "{\"error\":\"compose required or outside root\"}".into()),
            },
            (Method::Get, "/api/backups") => match query_param(&query, "compose").and_then(|r| backups_json(&root, &r)) {
                Some(b) => json_response(200, b),
                None => json_response(400, "{\"error\":\"compose required or outside root\"}".into()),
            },
            (Method::Get, "/api/git") => json_response(200, git_status_json(&root)),
            (Method::Get, "/api/stats") => match query_param(&query, "compose").and_then(|r| stats_json(&root, &r)) {
                Some(b) => json_response(200, b),
                None => json_response(400, "{\"error\":\"compose required or outside root\"}".into()),
            },
            (Method::Get, "/api/logs") => {
                match query_param(&query, "compose").and_then(|r| safe_join(&root, &r)) {
                    Some(abs) => {
                        let tail = query_param(&query, "tail").unwrap_or_else(|| "200".into());
                        json_response(200, run_tool(Path::new("docker"), &["compose".into(), "-f".into(), abs.to_string_lossy().to_string(), "logs".into(), "--no-color".into(), "--tail".into(), tail]))
                    }
                    None => json_response(400, "{\"error\":\"compose required or outside root\"}".into()),
                }
            }
            (Method::Post, p) if p.starts_with("/api/") => {
                // Anti-CSRF: require an application/json body and a loopback (or
                // absent) Origin, so a visited page cannot drive actions here.
                // Read the headers into owned values before borrowing the body.
                let mut content_type = None;
                let mut origin = None;
                for h in request.headers() {
                    if h.field.equiv("Content-Type") {
                        content_type = Some(h.value.as_str().to_string());
                    } else if h.field.equiv("Origin") {
                        origin = Some(h.value.as_str().to_string());
                    }
                }
                if !mutation_allowed(content_type.as_deref(), origin.as_deref()) {
                    json_response(415, "{\"error\":\"mutations require application/json from a loopback origin\"}".into())
                } else {
                    let mut body = String::new();
                    let _ = request.as_reader().read_to_string(&mut body);
                    let (status, json) = handle_action(&root, p, &body);
                    json_response(status, json)
                }
            }
            // A mutating verb reaching a GET-only route (or vice versa).
            (_, p) if p.starts_with("/api/") => json_response(405, "{\"error\":\"method not allowed\"}".into()),
            _ => json_response(404, "{\"error\":\"not found\"}".into()),
        };
        let _ = request.respond(response);
    }
    Ok(())
}

fn query_param(query: &str, key: &str) -> Option<String> {
    query.split('&').find_map(|pair| {
        let (k, v) = pair.split_once('=')?;
        if k == key {
            Some(percent_decode(v))
        } else {
            None
        }
    })
}

/// Minimal percent-decoding for query values (enough for file paths).
fn percent_decode(s: &str) -> String {
    let bytes = s.replace('+', " ");
    let mut out = Vec::new();
    let mut it = bytes.bytes().peekable();
    while let Some(b) = it.next() {
        if b == b'%' {
            let hi = it.next();
            let lo = it.next();
            if let (Some(h), Some(l)) = (hi, lo) {
                if let (Some(h), Some(l)) = ((h as char).to_digit(16), (l as char).to_digit(16)) {
                    out.push((h * 16 + l) as u8);
                    continue;
                }
            }
        } else {
            out.push(b);
        }
    }
    String::from_utf8_lossy(&out).to_string()
}

/// `GET /api/drift?compose=REL` — structured declared-vs-running drift.
fn drift_json(root: &Path, rel: &str) -> Option<String> {
    let compose = safe_join(root, rel)?;
    let yaml = std::fs::read_to_string(&compose).ok()?;
    let declared = compose::parse_service_images(&yaml);
    match drift::running_images_via_docker(&compose) {
        None => Some("{\"available\":false,\"items\":[]}".into()),
        Some(running) => {
            let items: Vec<String> = drift::detect_drift(&declared, &running)
                .iter()
                .map(|i| {
                    let (kind, extra) = match &i.kind {
                        DriftKind::Missing => ("missing", String::new()),
                        DriftKind::Unexpected => ("unexpected", String::new()),
                        DriftKind::ImageChanged { declared, running } => (
                            "changed",
                            format!(",\"declared\":{},\"running\":{}", json_escape(declared), json_escape(running)),
                        ),
                    };
                    format!("{{\"service\":{},\"kind\":\"{}\"{}}}", json_escape(&i.service), kind, extra)
                })
                .collect();
            Some(format!("{{\"available\":true,\"items\":[{}]}}", items.join(",")))
        }
    }
}

/// `GET /api/updates?compose=REL` — structured per-service update status.
fn updates_json(root: &Path, rel: &str) -> Option<String> {
    let compose = safe_join(root, rel)?;
    let yaml = std::fs::read_to_string(&compose).ok()?;
    let services = workload::parse_services(&yaml);
    let mut running = std::collections::HashMap::new();
    for s in &services {
        if let Some(img) = &s.image {
            if let Some(d) = updates::local_image_digest(img) {
                running.insert(s.name.clone(), d);
            }
        }
    }
    let plan = updates::build_update_plan(&services, &running, &registry::HttpRegistryClient);
    let items: Vec<String> = plan
        .iter()
        .map(|it| {
            format!(
                "{{\"service\":{},\"status\":{},\"action\":{}}}",
                json_escape(&it.service),
                json_escape(&format!("{:?}", it.status)),
                json_escape(it.action.as_str())
            )
        })
        .collect();
    Some(format!("{{\"items\":[{}]}}", items.join(",")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn loopback_hosts_are_allowed_others_rejected() {
        assert!(host_is_loopback("127.0.0.1"));
        assert!(host_is_loopback("127.0.0.1:8770"));
        assert!(host_is_loopback("localhost"));
        assert!(host_is_loopback("localhost:8770"));
        assert!(host_is_loopback("[::1]:8770"));
        assert!(host_is_loopback("127.5.6.7"), "all of 127.0.0.0/8 is loopback");
        // not loopback:
        assert!(!host_is_loopback("127.evil.com"), "a domain starting 127. is not a loopback IP");
        assert!(!host_is_loopback("evil.com"));
        assert!(!host_is_loopback("192.168.1.10:8770"));
        assert!(!host_is_loopback("10.0.0.1"));
    }

    #[test]
    fn safe_join_confines_to_root() {
        let root = Path::new("/srv/stacks");
        assert!(safe_join(root, "immich/docker-compose.yml").is_some());
        // traversal + absolute are refused
        assert!(safe_join(root, "../etc/passwd").is_none());
        assert!(safe_join(root, "a/../../b").is_none());
        assert!(safe_join(root, "/etc/passwd").is_none());
    }

    #[test]
    fn only_known_lifecycle_events_are_accepted() {
        for ok in ["activate", "deprecate", "archive", "restore"] {
            assert!(valid_event(ok));
        }
        assert!(!valid_event("rm -rf"));
        assert!(!valid_event(""));
    }

    #[test]
    fn mutation_gate_requires_json_and_loopback_origin() {
        // a same-origin JSON request from the UI is allowed
        assert!(mutation_allowed(Some("application/json"), Some("http://127.0.0.1:8770")));
        assert!(mutation_allowed(Some("application/json; charset=utf-8"), None));
        assert!(mutation_allowed(Some("application/json"), Some("http://localhost:8770")));
        // a drive-by "simple" cross-site POST (text/plain) is refused
        assert!(!mutation_allowed(Some("text/plain"), None));
        assert!(!mutation_allowed(Some("text/plain;charset=UTF-8"), Some("https://evil.com")));
        assert!(!mutation_allowed(None, None));
        // JSON but from a non-loopback Origin is refused
        assert!(!mutation_allowed(Some("application/json"), Some("https://evil.com")));
    }

    #[test]
    fn actions_reject_paths_outside_root() {
        let root = Path::new("/srv/stacks");
        let (status, _) = handle_action(root, "/api/deploy", "{\"compose\":\"../../etc/x.yml\"}");
        assert_eq!(status, 400);
        let (status, _) = handle_action(root, "/api/lifecycle", "{\"compose\":\"a.yml\",\"event\":\"boom\"}");
        assert_eq!(status, 400, "invalid event rejected");
    }
}
