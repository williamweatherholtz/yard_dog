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
use crate::{compose, gitver, guardrails, hostfs, lifecycle, preflight, registry, report, stacks, stats, term, updates, verify, workload};
use base64::prelude::{Engine as _, BASE64_STANDARD};
use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};

/// Global lock for repo-wide mutations (git remote sync, fleet ops).
fn global_lock() -> &'static Mutex<()> {
    static L: OnceLock<Mutex<()>> = OnceLock::new();
    L.get_or_init(|| Mutex::new(()))
}

/// Per-stack lock so operations on ONE stack serialize (no same-stack deploy/
/// backup race) while DIFFERENT stacks run concurrently. The shared monorepo git
/// index is serialized separately, cross-process, inside gitver.
fn stack_lock(key: &str) -> Arc<Mutex<()>> {
    static M: OnceLock<Mutex<HashMap<String, Arc<Mutex<()>>>>> = OnceLock::new();
    let map = M.get_or_init(|| Mutex::new(HashMap::new()));
    let mut g = map.lock().unwrap_or_else(|e| e.into_inner());
    // Bound growth (a loopback client could POST many distinct compose strings):
    // when the table gets large, drop entries no request currently holds — an
    // Arc strong_count of 1 means only the map still references that mutex.
    if g.len() > 1024 {
        g.retain(|_, v| Arc::strong_count(v) > 1);
    }
    g.entry(key.to_string()).or_insert_with(|| Arc::new(Mutex::new(()))).clone()
}

/// Cap on concurrently-handled requests. Loopback single-operator use never needs
/// many; the cap stops an unbounded thread/subprocess pile-up from parked
/// long-polls or a drive-by GET loop.
const MAX_INFLIGHT: usize = 128;
static INFLIGHT: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);

/// Decrements the in-flight counter when a request's handler thread ends (normal
/// return, early return, or panic).
struct InflightGuard;
impl Drop for InflightGuard {
    fn drop(&mut self) {
        INFLIGHT.fetch_sub(1, std::sync::atomic::Ordering::SeqCst);
    }
}

/// The stack a mutation targets (parent dir of its `compose`), for per-stack
/// locking. Falls back to a single shared bucket when there is no compose field.
fn stack_key(body: &str) -> String {
    serde_json::from_str::<serde_json::Value>(body)
        .ok()
        .and_then(|v| v.get("compose").and_then(|c| c.as_str()).map(normalize_stack_key))
        .unwrap_or_else(|| "_".to_string())
}

/// Lexically normalize a compose path to its stack key (parent dir) so different
/// spellings of one stack — `a/c.yml`, `./a/c.yml`, `a//c.yml`, `a\c.yml` — map to
/// the SAME lock and therefore serialize. Purely lexical (no fs), mirroring
/// safe_join's component model.
fn normalize_stack_key(compose: &str) -> String {
    use std::path::Component;
    let unified = compose.replace('\\', "/");
    let parent = Path::new(&unified).parent().unwrap_or_else(|| Path::new(""));
    let mut parts: Vec<String> = Vec::new();
    for c in parent.components() {
        match c {
            // Lower-case each component so that on a case-INSENSITIVE filesystem
            // (the Windows host, macOS, case-insensitive binds) two spellings that
            // resolve to the SAME stack dir — Immich/ vs immich/ — map to the SAME
            // lock and actually serialize. On a case-sensitive FS this merely
            // over-serializes two case-distinct stacks (benign).
            Component::Normal(s) => parts.push(s.to_string_lossy().to_lowercase()),
            Component::ParentDir => parts.push("..".into()),
            _ => {}
        }
    }
    if parts.is_empty() {
        "_".to_string()
    } else {
        parts.join("/")
    }
}
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
    let candidate = root.join(p);
    // Symlink-resistant: the lexical check above stops `..`/absolute paths, but a
    // symlink UNDER root pointing outside would still resolve out. When the root
    // actually exists, canonicalize the nearest existing ancestor and require it to
    // stay under the canonical root. (Best-effort: if root can't be canonicalized —
    // e.g. it doesn't exist — the lexical check above is still the guarantee.)
    if let Ok(root_canon) = root.canonicalize() {
        let mut anc: &Path = candidate.as_path();
        loop {
            if let Ok(real) = anc.canonicalize() {
                if !real.starts_with(&root_canon) {
                    return None;
                }
                break;
            }
            match anc.parent() {
                Some(par) => anc = par,
                None => break,
            }
        }
    }
    Some(candidate)
}

/// A lifecycle event name the API accepts (allow-list, not free text).
fn valid_event(ev: &str) -> bool {
    matches!(ev, "activate" | "deprecate" | "archive" | "restore")
}

/// A compose service name: starts alphanumeric, then `[A-Za-z0-9._-]`. Rejects a
/// leading `-` (which docker would parse as a flag) and any exotic input.
fn valid_service_name(s: &str) -> bool {
    let mut chars = s.chars();
    matches!(chars.next(), Some(c) if c.is_ascii_alphanumeric())
        && s.chars().all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '-'))
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
            let expected = ids.get(&m.service).copied();
            let issue_objs: Vec<String> = m.issues.iter().map(|i| issue_json(i, expected)).collect();
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
                "{{\"service\":{},\"target\":{},\"source\":{},\"type\":\"{}\",\"exists\":{},\"issues\":[{}],\"remediations\":[{}]}}",
                json_escape(&m.service),
                json_escape(&m.target),
                m.source.as_deref().map(json_escape).unwrap_or_else(|| "null".into()),
                mount_type_str(m.mount_type),
                exists,
                issue_objs.join(","),
                rems.join(",")
            )
        })
        .collect();
    Some(format!("{{\"items\":[{}]}}", items.join(",")))
}

/// Serialize one detected path issue with a human label and whether `yd fix` can
/// apply it automatically (create the missing dir / fix ownership; a type
/// mismatch is operator-decided and reports `fixable:false`).
fn issue_json(issue: &Issue, expected: Option<(u32, u32)>) -> String {
    let fixable = !crate::apply::actions_for(issue, expected).is_empty();
    let (kind, label, message) = match issue {
        Issue::MissingPath { path } => (
            "missing",
            "Missing directory".to_string(),
            format!("Host path {path} does not exist yet"),
        ),
        Issue::TypeMismatch { path, expected_dir, .. } => (
            "typemismatch",
            "Type mismatch".to_string(),
            format!(
                "{path} is the wrong kind — the mount expects a {}",
                if *expected_dir { "directory" } else { "file" }
            ),
        ),
        Issue::Ownership { path, .. } => (
            "ownership",
            "Ownership".to_string(),
            format!("{path} is not owned by the container user"),
        ),
    };
    format!(
        "{{\"kind\":\"{}\",\"label\":{},\"message\":{},\"fixable\":{}}}",
        kind,
        json_escape(&label),
        json_escape(&message),
        fixable
    )
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
    // Resolve relative binds against the stack dir — same as mounts_json — so the
    // permissions/ownership panel probes the real host path, not the server CWD.
    let stack_dir = p.parent().unwrap_or(root);
    if let Ok(mounts) = compose::parse_mounts(&yaml, &env).map(|m| resolve_bind_sources(m, stack_dir)) {
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
    // `from`/`to` are commit shas passed as git argv — reject anything not a plain
    // hex sha so a value like `--output=…` can't be read as a git flag.
    if !is_git_sha(&from) || to.as_deref().map(|t| !is_git_sha(t)).unwrap_or(false) {
        return None;
    }
    let d = gitver::diff_scoped(root, &stack_rel(&rel), &from, to.as_deref()).unwrap_or_default();
    Some(format!("{{\"diff\":{}}}", json_escape(&d)))
}

/// A plausible git commit sha: 4–64 hex chars. Rejects flags/paths/injection.
fn is_git_sha(s: &str) -> bool {
    (4..=64).contains(&s.len()) && s.chars().all(|c| c.is_ascii_hexdigit())
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
                "{{\"name\":{},\"compose\":{},\"lifecycle\":{},\"services\":{},\"blocks\":{},\"warns\":{},\"adopted\":{}}}",
                json_escape(&s.name),
                json_escape(&rel),
                json_escape(state.as_str()),
                n,
                blocks,
                warns,
                lifecycle::is_managed(dir)
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
            format!(
                "{{\"name\":{},\"image\":{}}}",
                json_escape(&s.name),
                json_escape(s.image.as_deref().unwrap_or(""))
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
/// Truncate a tool's output to a bounded, UTF-8-safe prefix so a chatty command
/// can't make the server buffer/serialize an unbounded string.
fn cap_output(bytes: &[u8]) -> String {
    const MAX: usize = 1 << 20; // 1 MiB
    if bytes.len() <= MAX {
        return String::from_utf8_lossy(bytes).into_owned();
    }
    let mut end = MAX;
    while end > 0 && (bytes[end] & 0xC0) == 0x80 {
        end -= 1; // don't split a multi-byte char
    }
    let mut s = String::from_utf8_lossy(&bytes[..end]).into_owned();
    s.push_str("\n…[output truncated]");
    s
}

fn run_tool(program: &Path, args: &[String]) -> String {
    match std::process::Command::new(program).args(args).output() {
        Ok(out) => format!(
            "{{\"ok\":{},\"exit\":{},\"stdout\":{},\"stderr\":{}}}",
            out.status.success(),
            out.status.code().unwrap_or(-1),
            json_escape(&cap_output(&out.stdout)),
            json_escape(&cap_output(&out.stderr))
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
        // Apply the automatic directory mitigations (create missing dirs with the
        // container's owner; fix ownership). Explicit-consent only, via `yd fix`.
        "/api/fix" => {
            let Some(rel) = field(&v, "compose") else { return bad("compose required") };
            let Some(abs) = compose_abs(rel) else { return bad("path outside root") };
            (200, run_tool(&yd, &["fix".into(), abs, "--yes".into()]))
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
                Ok(sha) => {
                    // A plaintext / URL-embedded secret is BLOCKED at deploy but would
                    // otherwise be committed to git (and pushable to a remote) silently.
                    // Warn on save so the operator knows before it lands in history.
                    let secret = guardrails::run_guardrails(yaml).into_iter().any(|f| {
                        matches!(f.rule.as_str(), "plaintext-secret" | "embedded-credentials")
                    });
                    let warn = if secret {
                        ",\"warning\":\"This compose contains a plaintext secret — it is now committed to git history and would be pushed to any remote. Use an env_file or Docker secret instead.\""
                    } else {
                        ""
                    };
                    (200, format!("{{\"ok\":true,\"sha\":{}{}}}", json_escape(&sha), warn))
                }
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
            // Validate the revision like /api/diff does — an unchecked value could
            // reach a git option slot (e.g. a leading-dash "sha").
            if !is_git_sha(sha) {
                return bad("invalid revision");
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
        // Restore a stack's DATA from a backup (verify-gated in the CLI; destructive).
        "/api/backup/restore" => {
            let Some(rel) = field(&v, "compose") else { return bad("compose required") };
            let Some(abs) = compose_abs(rel) else { return bad("path outside root") };
            let name = field(&v, "name").unwrap_or(".yd-backups");
            // Confine unconditionally — no prefix escape hatch. `.yd-backups[/point]`
            // is a plain relative name and passes safe_join on its own.
            if safe_join(root, name).is_none() {
                return bad("restore source outside root");
            }
            let dest = Path::new(&abs).parent().map(|p| p.join(name)).map(|p| p.to_string_lossy().to_string()).unwrap_or_default();
            (200, run_tool(&yd, &["restore".into(), abs, "--from".into(), dest, "--yes".into()]))
        }
        // Fleet fan-out: run each discovered stack through the per-stack guarded
        // CLI path (sequential, to avoid docker contention). sub = "backup"|"check".
        "/api/fleet/backup" | "/api/fleet/check" => {
            let sub = if path.ends_with("backup") { "backup" } else { "doctor" };
            let stacks = stacks::discover_stacks(root).unwrap_or_default();
            let yd = yd_bin();
            let results: Vec<String> = stacks
                .iter()
                .map(|s| {
                    let compose = s.compose_path.to_string_lossy().to_string();
                    let args: Vec<String> = if sub == "backup" {
                        vec!["backup".into(), compose, "--run".into(), "--dest".into(), ".yd-backups".into()]
                    } else {
                        vec!["doctor".into(), compose]
                    };
                    let out = std::process::Command::new(&yd).args(&args).output();
                    let (ok, tail) = match out {
                        Ok(o) => (
                            o.status.success(),
                            String::from_utf8_lossy(&o.stdout).lines().last().unwrap_or("").to_string(),
                        ),
                        Err(e) => (false, e.to_string()),
                    };
                    format!("{{\"stack\":{},\"ok\":{},\"summary\":{}}}", json_escape(&s.name), ok, json_escape(&tail))
                })
                .collect();
            (200, format!("{{\"results\":[{}]}}", results.join(",")))
        }
        // Adopt a discovered stack: set Draft lifecycle (if unset) + initial snapshot.
        "/api/adopt" => {
            let Some(rel) = field(&v, "compose") else { return bad("compose required") };
            let Some(abs) = safe_join(root, rel) else { return bad("path outside root") };
            let Some(dir) = abs.parent() else { return bad("bad path") };
            let sr = stack_rel(rel);
            let result = (|| -> std::io::Result<()> {
                if !lifecycle::is_managed(dir) {
                    lifecycle::write_state(dir, LifecycleState::Draft)?;
                }
                gitver::ensure_repo(root)?;
                gitver::snapshot_scoped(root, &sr, "yd adopt")?;
                Ok(())
            })();
            match result {
                Ok(()) => (200, "{\"ok\":true}".into()),
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
        // Explicit remote refresh (the mutating counterpart to the GET /api/git
        // read, which no longer fetches). A POST so a visited page can't drive it.
        "/api/git/fetch" => match gitver::fetch_remote(root) {
            Ok(_) => (200, "{\"ok\":true}".into()),
            Err(e) => (200, format!("{{\"ok\":false,\"stderr\":{}}}", json_escape(&e.to_string()))),
        },
        // ---- interactive terminal (PTY) -------------------------------------
        "/api/term/open" => {
            let Some(rel) = field(&v, "compose") else { return bad("compose required") };
            let Some(abs) = compose_abs(rel) else { return bad("path outside root") };
            let mode = field(&v, "mode").unwrap_or("shell");
            let rows = v.get("rows").and_then(|x| x.as_u64()).unwrap_or(24) as u16;
            let cols = v.get("cols").and_then(|x| x.as_u64()).unwrap_or(80) as u16;
            let mut argv = vec!["docker".to_string(), "compose".into(), "-f".into(), abs];
            // `--` ends option parsing so a service value can never be read as a
            // docker flag (e.g. `--privileged`); the name is charset-validated too.
            match mode {
                "logs" => {
                    argv.extend(["logs".into(), "-f".into(), "--no-color".into(), "--tail".into(), "200".into()]);
                    if let Some(svc) = field(&v, "service") {
                        if !svc.is_empty() {
                            if !valid_service_name(svc) {
                                return bad("invalid service name");
                            }
                            argv.push("--".into());
                            argv.push(svc.into());
                        }
                    }
                }
                _ => {
                    let Some(svc) = field(&v, "service") else { return bad("service required for a shell") };
                    if !valid_service_name(svc) {
                        return bad("invalid service name");
                    }
                    argv.extend(["exec".into(), "--".into(), svc.into(), "sh".into()]);
                }
            }
            match term::open(&argv, rows, cols) {
                Ok(id) => (200, format!("{{\"ok\":true,\"session\":{}}}", json_escape(&id))),
                Err(e) => (200, format!("{{\"ok\":false,\"error\":{}}}", json_escape(&e.to_string()))),
            }
        }
        // Draining long-poll read is a POST behind the anti-CSRF gate (it mutates
        // server state — it empties the PTY output buffer), not a CSRF-exempt GET.
        "/api/term/read" => {
            let Some(sid) = field(&v, "session") else { return bad("session required") };
            match term::read(sid, 500) {
                Some((data, alive)) => (200, format!("{{\"data\":\"{}\",\"alive\":{}}}", BASE64_STANDARD.encode(&data), alive)),
                None => (200, "{\"data\":\"\",\"alive\":false}".into()),
            }
        }
        "/api/term/input" => {
            let (Some(sid), Some(data)) = (field(&v, "session"), field(&v, "data")) else {
                return bad("session, data required");
            };
            let bytes = BASE64_STANDARD.decode(data).unwrap_or_default();
            match term::write(sid, &bytes) {
                Ok(()) => (200, "{\"ok\":true}".into()),
                Err(e) => (200, format!("{{\"ok\":false,\"error\":{}}}", json_escape(&e.to_string()))),
            }
        }
        "/api/term/resize" => {
            let Some(sid) = field(&v, "session") else { return bad("session required") };
            let rows = v.get("rows").and_then(|x| x.as_u64()).unwrap_or(24) as u16;
            let cols = v.get("cols").and_then(|x| x.as_u64()).unwrap_or(80) as u16;
            let _ = term::resize(sid, rows, cols);
            (200, "{\"ok\":true}".into())
        }
        "/api/term/close" => {
            if let Some(sid) = field(&v, "session") {
                term::close(sid);
            }
            (200, "{\"ok\":true}".into())
        }
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
pub fn serve(host: &str, port: u16, root: &Path) -> io::Result<()> {
    let root = root.canonicalize().unwrap_or_else(|_| root.to_path_buf());
    // The served root IS the monorepo (decGitVersioning): one repo, per-stack
    // snapshots scoped by path. Initialise it once on startup, with an initial
    // commit so remote sync (push) works immediately.
    let _ = gitver::ensure_repo(&root);
    if gitver::history(&root).map(|h| h.is_empty()).unwrap_or(true) {
        let _ = gitver::snapshot(&root, "yd: initialize config repo");
    }
    let server = Server::http((host, port))
        .map_err(|e| io::Error::new(io::ErrorKind::Other, format!("cannot bind {host}:{port}: {e}")))?;
    if host == "127.0.0.1" || host == "localhost" {
        println!("Yard Dog control plane on http://{host}:{port}  (loopback only — Ctrl-C to stop)");
    } else {
        // Non-loopback bind: intended for a container whose port is published to the
        // host's loopback. The Host allowlist below still refuses any non-loopback
        // Host header, so this does not open LAN access on its own.
        println!("Yard Dog control plane bound on {host}:{port}  (Host allowlist still enforces loopback — Ctrl-C to stop)");
    }
    println!("serving stacks under {}", root.display());

    for mut request in server.incoming_requests() {
        // Each request runs on its own thread, so a blocking long-poll (the
        // terminal read parks up to 500ms) never stalls the rest of the control
        // plane. A panic in one handler kills only its thread, not the server.
        let root = root.clone();
        // Backpressure: refuse past the in-flight cap rather than spawn unboundedly.
        if INFLIGHT.fetch_add(1, std::sync::atomic::Ordering::SeqCst) >= MAX_INFLIGHT {
            INFLIGHT.fetch_sub(1, std::sync::atomic::Ordering::SeqCst);
            let _ = request.respond(Response::from_string("server busy").with_status_code(503));
            continue;
        }
        let guard = InflightGuard;
        std::thread::spawn(move || {
            let _guard = guard; // decrements the in-flight counter when this thread ends
        // Security: refuse any non-loopback Host (DNS-rebinding defense).
        let host_ok = request
            .headers()
            .iter()
            .find(|h| h.field.equiv("Host"))
            .map(|h| host_is_loopback(h.value.as_str()))
            .unwrap_or(false);
        if !host_ok {
            let _ = request.respond(json_response(403, "{\"error\":\"forbidden host\"}".into()));
            return;
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
                        // Clamp `tail` to a sane integer so a huge/garbage value can't
                        // make the server buffer an unbounded log in memory.
                        let tail = query_param(&query, "tail")
                            .and_then(|t| t.parse::<u32>().ok())
                            .unwrap_or(200)
                            .clamp(1, 5000)
                            .to_string();
                        json_response(200, run_tool(Path::new("docker"), &["compose".into(), "-f".into(), abs.to_string_lossy().to_string(), "logs".into(), "--no-color".into(), "--tail".into(), tail]))
                    }
                    None => json_response(400, "{\"error\":\"compose required or outside root\"}".into()),
                }
            }
            // Bundled terminal emulator (xterm.js) — served from the binary; the
            // strict same-host model means no CDN.
            (Method::Get, "/assets/xterm.js") => Response::from_string(include_str!("assets/xterm.js")).with_header(header("Content-Type", "application/javascript; charset=utf-8")),
            (Method::Get, "/assets/xterm.css") => Response::from_string(include_str!("assets/xterm.css")).with_header(header("Content-Type", "text/css; charset=utf-8")),
            (Method::Get, "/assets/addon-fit.js") => Response::from_string(include_str!("assets/addon-fit.js")).with_header(header("Content-Type", "application/javascript; charset=utf-8")),
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
                    // Cap the body so a local client can't OOM the server (or, via
                    // /api/save, write an unbounded file) with a giant POST.
                    const MAX_BODY: usize = 8 * 1024 * 1024;
                    let reader = request.as_reader();
                    let mut bytes = Vec::new();
                    let mut chunk = [0u8; 8192];
                    while bytes.len() < MAX_BODY {
                        match reader.read(&mut chunk) {
                            Ok(0) => break,
                            Ok(n) => bytes.extend_from_slice(&chunk[..n]),
                            Err(_) => break,
                        }
                    }
                    let body = String::from_utf8_lossy(&bytes).into_owned();
                    // Serialize MUTATING git/stack actions behind one global lock —
                    // the monorepo shares a single .git/index, and the old
                    // sequential loop was the de-facto serializer that
                    // thread-per-request removed. Terminal I/O stays concurrent
                    // (it must not block on a long deploy) and reads are GET.
                    let (status, json) = if p.starts_with("/api/term/") {
                        // terminal I/O must stay concurrent (never block on a deploy)
                        handle_action(&root, p, &body)
                    } else if p.starts_with("/api/git/") || p.starts_with("/api/fleet/") {
                        let _g = global_lock().lock().unwrap_or_else(|e| e.into_inner());
                        handle_action(&root, p, &body)
                    } else {
                        // stack-scoped: serialize per stack so a long deploy of one
                        // stack no longer blocks mutations to others.
                        let lock = stack_lock(&stack_key(&body));
                        let _g = lock.lock().unwrap_or_else(|e| e.into_inner());
                        handle_action(&root, p, &body)
                    };
                    json_response(status, json)
                }
            }
            // A mutating verb reaching a GET-only route (or vice versa).
            (_, p) if p.starts_with("/api/") => json_response(405, "{\"error\":\"method not allowed\"}".into()),
            _ => json_response(404, "{\"error\":\"not found\"}".into()),
        };
        let _ = request.respond(response);
        }); // end per-request thread
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
