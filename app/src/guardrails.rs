//! Preventative policy guardrails over a compose stack, run before deploy.
//! A small, high-signal ruleset (pin tags, healthcheck, restart, limits, no
//! plaintext secrets) with a warn/block split. Pure over the parsed compose.

/// Severity of a guardrail finding.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Severity {
    Warn,
    Block,
}

/// A single guardrail finding.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Finding {
    pub service: String,
    pub rule: String,
    pub severity: Severity,
    pub message: String,
}

fn key_is_secret(key: &str) -> bool {
    let k = key.to_ascii_uppercase();
    // A *_FILE key is the Docker-secrets convention — a path to a mounted secret,
    // not an inline secret — so it is not a plaintext-secret risk.
    if k.ends_with("_FILE") {
        return false;
    }
    ["PASSWORD", "SECRET", "TOKEN", "APIKEY", "API_KEY", "ACCESS_KEY", "PRIVATE_KEY"]
        .iter()
        .any(|needle| k.contains(needle))
}

fn is_plaintext(value: &str) -> bool {
    let v = value.trim();
    !v.is_empty() && !looks_interpolated(v)
}

/// True when the value is a compose *variable reference* (so its literal text is
/// not the secret). `${...}` anywhere, or a whole-value `$NAME` token, counts as
/// interpolation. `$$secret` (an escaped literal `$`) and `$2b$...` (a `$` that
/// does not begin a variable name) are literals — those must still be flagged.
fn looks_interpolated(v: &str) -> bool {
    if v.contains("${") {
        return true;
    }
    if let Some(rest) = v.strip_prefix('$') {
        // A `$` immediately followed by a variable-name start is a reference
        // (`$VAR`, `$PREFIX-suffix`, `$VAR/path`). Crucially a reference has NO
        // second `$` — a modular-crypt hash pasted as a literal secret does
        // (`$apr1$...`, `$argon2id$...`, `$y$...`, `$6$...`), as do `$$secret`
        // (escaped literal) and `$2b$...` (digit-led) — all stay flaggable.
        let starts_name = matches!(rest.chars().next(), Some(c) if c.is_ascii_alphabetic() || c == '_');
        return starts_name && !rest.contains('$');
    }
    false
}

/// True when a value bakes credentials into a connection URL —
/// `scheme://user:pass@host` — regardless of the env key's name. Fires on
/// `postgres://u:p@h/db` but not on `redis://cache:6379` (port, not password)
/// nor `https://user@host` (no password), keeping false positives near zero.
fn has_embedded_credentials(value: &str) -> bool {
    let v = value.trim();
    let Some(idx) = v.find("://") else {
        return false;
    };
    let scheme = &v[..idx];
    if scheme.is_empty()
        || !scheme.chars().all(|c| c.is_ascii_alphanumeric() || matches!(c, '+' | '.' | '-'))
    {
        return false;
    }
    let after = &v[idx + 3..];
    let authority = after.split(['/', '?', '#']).next().unwrap_or(after);
    match authority.split_once('@') {
        Some((userinfo, host)) => {
            !host.is_empty()
                && userinfo
                    .split_once(':')
                    .map_or(false, |(u, p)| !u.is_empty() && !p.is_empty())
        }
        None => false,
    }
}

/// True when an image reference has no explicit, non-`latest` tag.
fn is_floating_tag(image: &str) -> bool {
    let last = image.rsplit('/').next().unwrap_or(image);
    match last.split_once(':') {
        None => true,
        Some((_, tag)) => tag.is_empty() || tag == "latest",
    }
}

fn service_env(svc: &serde_yaml::Value) -> Vec<(String, String)> {
    let mut out = Vec::new();
    match svc.get("environment") {
        Some(serde_yaml::Value::Sequence(items)) => {
            for it in items {
                if let Some(s) = it.as_str() {
                    if let Some((k, v)) = s.split_once('=') {
                        out.push((k.trim().to_string(), v.to_string()));
                    }
                }
            }
        }
        Some(serde_yaml::Value::Mapping(m)) => {
            for (k, v) in m {
                let key = k.as_str().unwrap_or_default().to_string();
                let val = match v {
                    serde_yaml::Value::String(s) => s.clone(),
                    serde_yaml::Value::Number(n) => n.to_string(),
                    serde_yaml::Value::Bool(b) => b.to_string(),
                    _ => continue,
                };
                out.push((key, val));
            }
        }
        _ => {}
    }
    out
}

/// Run the guardrail ruleset over a compose document.
pub fn run_guardrails(yaml: &str) -> Vec<Finding> {
    let mut out = Vec::new();
    // Refuse pathological YAML (stack-overflow / OOM bomb) with a Block, before
    // serde_yaml recurses — so a crafted compose is stopped, not crashed on.
    if let Err(e) = crate::compose::yaml_guard(yaml) {
        return vec![Finding {
            service: "compose".into(),
            rule: "pathological-yaml".into(),
            severity: Severity::Block,
            message: e.to_string(),
        }];
    }
    let Ok(doc) = serde_yaml::from_str::<serde_yaml::Value>(yaml) else {
        return out;
    };
    let Some(services) = doc.get("services").and_then(|v| v.as_mapping()) else {
        return out;
    };
    let warn = |service: &str, rule: &str, message: String| Finding {
        service: service.to_string(),
        rule: rule.to_string(),
        severity: Severity::Warn,
        message,
    };
    for (name, svc) in services {
        let service = name.as_str().unwrap_or_default().to_string();

        if let Some(image) = svc.get("image").and_then(|v| v.as_str()) {
            if is_floating_tag(image) {
                out.push(Finding {
                    service: service.clone(),
                    rule: "floating-tag".into(),
                    severity: Severity::Block,
                    message: format!("image '{image}' has no pinned tag"),
                });
            }
        }
        if svc.get("healthcheck").is_none() {
            out.push(warn(&service, "no-healthcheck", "no healthcheck defined".into()));
        }
        if svc.get("restart").is_none() {
            out.push(warn(&service, "no-restart", "no restart policy set".into()));
        }
        if svc.get("mem_limit").is_none() && svc.get("cpus").is_none() {
            out.push(warn(&service, "no-limits", "no resource limits set".into()));
        }
        for (k, v) in service_env(svc) {
            if key_is_secret(&k) && is_plaintext(&v) {
                out.push(Finding {
                    service: service.clone(),
                    rule: "plaintext-secret".into(),
                    severity: Severity::Block,
                    message: format!("environment '{k}' looks like a plaintext secret"),
                });
            } else if has_embedded_credentials(&v) {
                out.push(Finding {
                    service: service.clone(),
                    rule: "embedded-credentials".into(),
                    severity: Severity::Block,
                    message: format!("environment '{k}' embeds credentials in a URL"),
                });
            }
        }

        // -- container-hardening (security) lens --
        let block = |rule: &str, message: String| Finding {
            service: service.clone(),
            rule: rule.to_string(),
            severity: Severity::Block,
            message,
        };
        // Privileged: a YAML bool `true` OR a truthy string/int ("true"/"yes"/1).
        if is_truthy(svc.get("privileged")) {
            out.push(block("privileged", "runs privileged (full host device/root access)".into()));
        }
        // Host mounts. Severity depends on WHAT and whether it's writable — a
        // read-write bind of a host-system path is host-root-equivalent (Block);
        // a read-only bind is worth flagging (Warn) but is a legitimate pattern
        // (timezone, CA certs, monitoring); a small allowlist of ubiquitous safe
        // read-only leaves is silent so common composes aren't nagged.
        for (src, read_only) in volume_mounts(svc) {
            if src.ends_with("docker.sock") {
                out.push(block("docker-socket", "mounts the Docker socket (equivalent to host root)".into()));
            } else if src == "/" {
                out.push(block("host-root-mount", "mounts the entire host filesystem at /".into()));
            } else if is_sensitive_host_path(&src) {
                if read_only && SAFE_RO_LEAVES.iter().any(|l| src == *l) {
                    // ubiquitous + safe (e.g. /etc/localtime:ro) — no finding
                } else if read_only {
                    out.push(warn(&service, "host-path-ro", format!("mounts host system path {src} read-only")));
                } else {
                    out.push(block("host-path-mount", format!("mounts writable host system path {src} (host-root-equivalent)")));
                }
            }
        }
        // Host device passthrough: raw memory/disk/kernel devices are host takeover
        // (Block); ordinary passthrough (GPU transcode, serial/Zigbee, USB, tun) is
        // powerful but a legitimate homelab pattern (Warn), not a deploy-stop.
        if let Some(devs) = svc.get("devices").and_then(|v| v.as_sequence()) {
            for d in devs {
                let s = match d {
                    serde_yaml::Value::String(s) => s.split(':').next().unwrap_or("").to_string(),
                    serde_yaml::Value::Mapping(m) => m.get("source").and_then(|x| x.as_str()).unwrap_or_default().to_string(),
                    _ => String::new(),
                };
                if s.is_empty() {
                    continue;
                }
                if is_dangerous_device(&s) {
                    out.push(block("host-device", format!("passes through a raw host device {s} (host takeover)")));
                } else {
                    out.push(warn(&service, "host-device", format!("passes through host device {s}")));
                }
            }
        }
        // Disabling the seccomp/AppArmor sandbox widens every other escape.
        if let Some(opts) = svc.get("security_opt").and_then(|v| v.as_sequence()) {
            for o in opts {
                if let Some(s) = o.as_str() {
                    let s = s.to_ascii_lowercase();
                    if s.contains("unconfined") && (s.contains("seccomp") || s.contains("apparmor")) {
                        out.push(block("security-opt-unconfined", format!("disables the container sandbox ({s})")));
                    }
                }
            }
        }
        // Dangerous added capabilities (sequence OR a single scalar string).
        for c in cap_add_list(svc) {
            let cu = c.trim_start_matches("CAP_").to_ascii_uppercase();
            if BLOCK_CAPS.contains(&cu.as_str()) {
                out.push(block("dangerous-cap", format!("adds host-compromising capability {c}")));
            } else if WARN_CAPS.contains(&cu.as_str()) {
                out.push(warn(&service, "dangerous-cap", format!("adds capability {c}")));
            }
        }
        // Namespace sharing reduces isolation but is sometimes intentional (Warn).
        if svc.get("network_mode").and_then(|v| v.as_str()) == Some("host") {
            out.push(warn(&service, "host-network", "uses host networking (no network isolation)".into()));
        }
        if svc.get("pid").and_then(|v| v.as_str()) == Some("host") {
            out.push(warn(&service, "host-pid", "shares the host PID namespace".into()));
        }
        if svc.get("ipc").and_then(|v| v.as_str()) == Some("host") {
            out.push(warn(&service, "host-ipc", "shares the host IPC namespace".into()));
        }
    }
    out
}

/// Capabilities that are host-root-equivalent → Block.
const BLOCK_CAPS: &[&str] = &[
    "ALL", "SYS_ADMIN", "SYS_MODULE", "SYS_PTRACE", "SYS_RAWIO", "SYS_BOOT",
    "DAC_READ_SEARCH", "DAC_OVERRIDE", "BPF", "MKNOD",
];
/// Capabilities worth a warning (powerful but not directly host-root).
const WARN_CAPS: &[&str] = &["NET_ADMIN", "NET_RAW", "SYSLOG", "SYS_TIME", "SYS_NICE"];

/// A YAML value that means "true": bool true, "true"/"yes"/"on"/"1", or int 1.
fn is_truthy(v: Option<&serde_yaml::Value>) -> bool {
    match v {
        Some(serde_yaml::Value::Bool(b)) => *b,
        Some(serde_yaml::Value::String(s)) => {
            matches!(s.trim().to_ascii_lowercase().as_str(), "true" | "yes" | "on" | "1")
        }
        Some(serde_yaml::Value::Number(n)) => n.as_i64() == Some(1),
        _ => false,
    }
}

/// Ubiquitous, safe read-only host binds — no finding even though they touch a
/// system path (timezone, machine id, CA trust, DNS).
const SAFE_RO_LEAVES: &[&str] = &[
    "/etc/localtime", "/etc/timezone", "/etc/machine-id", "/etc/ssl/certs",
    "/etc/ca-certificates", "/usr/share/zoneinfo", "/etc/hosts", "/etc/resolv.conf",
];

/// `(source, read_only)` for each of a service's `volumes:` (short + long syntax).
fn volume_mounts(svc: &serde_yaml::Value) -> Vec<(String, bool)> {
    let mut out = Vec::new();
    if let Some(vols) = svc.get("volumes").and_then(|v| v.as_sequence()) {
        for vol in vols {
            match vol {
                serde_yaml::Value::String(s) => {
                    let parts: Vec<&str> = s.split(':').collect();
                    let src = parts.first().copied().unwrap_or("").to_string();
                    let ro = parts.len() >= 3 && parts[parts.len() - 1].split(',').any(|m| m.trim() == "ro");
                    out.push((src, ro));
                }
                serde_yaml::Value::Mapping(m) => {
                    if let Some(src) = m.get("source").and_then(|x| x.as_str()) {
                        let ro = m.get("read_only").and_then(|x| x.as_bool()).unwrap_or(false);
                        out.push((src.to_string(), ro));
                    }
                }
                _ => {}
            }
        }
    }
    out
}

/// A raw host device whose passthrough is host-takeover-equivalent (memory,
/// kernel log, I/O ports, or a whole block device). Ordinary device passthrough
/// (GPU, sound, serial, USB, tun) is NOT in here — it only warns.
fn is_dangerous_device(src: &str) -> bool {
    let s = src.replace('\\', "/");
    if matches!(s.as_str(), "/dev/mem" | "/dev/kmem" | "/dev/port" | "/dev/kmsg" | "/dev") {
        return true;
    }
    // whole-disk block devices: /dev/sda, /dev/nvme0n1, /dev/vda, /dev/hda,
    // /dev/mmcblk0, /dev/dm-0, /dev/loop0 (partitions like sda1 too).
    let leaf = s.strip_prefix("/dev/").unwrap_or("");
    // udev/device-mapper symlinks that resolve to whole disks or volumes — the
    // same blast radius as the raw node, reached by a stable name rather than
    // sdX/nvmeX (which a leaf-prefix match would otherwise miss).
    const DISK_ALIASES: &[&str] = &[
        "disk/by-id/",
        "disk/by-path/",
        "disk/by-uuid/",
        "disk/by-partuuid/",
        "disk/by-label/",
        "mapper/",
        "block/",
    ];
    if DISK_ALIASES.iter().any(|p| leaf.starts_with(p)) {
        return true;
    }
    let disk_prefixes = ["sd", "vd", "hd", "nvme", "mmcblk", "dm-", "loop", "xvd"];
    disk_prefixes
        .iter()
        .any(|p| leaf.starts_with(p) && leaf[p.len()..].chars().next().map(|c| c.is_ascii_alphanumeric()).unwrap_or(false))
}

/// `cap_add` as a list, tolerating both a sequence and a single scalar string.
fn cap_add_list(svc: &serde_yaml::Value) -> Vec<String> {
    match svc.get("cap_add") {
        Some(serde_yaml::Value::Sequence(caps)) => {
            caps.iter().filter_map(|c| c.as_str().map(String::from)).collect()
        }
        Some(serde_yaml::Value::String(s)) => vec![s.clone()],
        _ => Vec::new(),
    }
}

/// True for a host bind source that is (under) a sensitive host root.
fn is_sensitive_host_path(src: &str) -> bool {
    let n = src.replace('\\', "/");
    let n = n.trim_end_matches('/');
    if n.is_empty() {
        return src == "/"; // "/" trims to "" (root); a genuinely empty source is not
    }
    const SENSITIVE: &[&str] = &[
        "/proc", "/sys", "/dev", "/var/run", "/run", "/var/lib/docker", "/boot", "/etc",
    ];
    SENSITIVE.iter().any(|r| n == *r || n.starts_with(&format!("{r}/")))
}

/// A stack passes iff it has no blocking findings.
pub fn verdict(findings: &[Finding]) -> bool {
    !findings.iter().any(|f| f.severity == Severity::Block)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rules(f: &[Finding]) -> Vec<&str> {
        f.iter().map(|x| x.rule.as_str()).collect()
    }

    #[test]
    fn flags_floating_tag_missing_checks_and_plaintext_secret() {
        let yaml = "services:\n  db:\n    image: postgres:latest\n    environment:\n      POSTGRES_PASSWORD: hunter2\n";
        let f = run_guardrails(yaml);
        assert!(f.iter().any(|x| x.rule == "floating-tag" && x.severity == Severity::Block));
        assert!(f.iter().any(|x| x.rule == "no-healthcheck" && x.severity == Severity::Warn));
        assert!(f.iter().any(|x| x.rule == "plaintext-secret" && x.severity == Severity::Block));
    }

    #[test]
    fn file_secret_reference_is_not_flagged_plaintext() {
        // *_FILE is the Docker-secrets convention (a path to a mounted secret),
        // which is more secure — it must not be flagged as a plaintext secret,
        // while a real inline secret still is.
        let yaml = "services:\n  db:\n    image: postgres:16\n    environment:\n      POSTGRES_PASSWORD_FILE: /run/secrets/db_password\n";
        let f = run_guardrails(yaml);
        assert!(!rules(&f).contains(&"plaintext-secret"), "a *_FILE ref is not plaintext: {f:?}");

        let inline = "services:\n  db:\n    image: postgres:16\n    environment:\n      POSTGRES_PASSWORD: hunter2\n";
        assert!(rules(&run_guardrails(inline)).contains(&"plaintext-secret"), "inline secret still flagged");
    }

    #[test]
    fn secret_detection_no_longer_evaded_by_dollar_or_url() {
        // `$$`-escaped literal (Docker yields a leading `$`) is a real plaintext
        // secret, not interpolation — it must be flagged.
        let esc = "services:\n  db:\n    image: postgres:16\n    environment:\n      POSTGRES_PASSWORD: $$ecretPw99\n";
        assert!(rules(&run_guardrails(esc)).contains(&"plaintext-secret"), "escaped-$ literal flagged: {:?}", run_guardrails(esc));

        // A genuine `$VAR` reference is interpolation — must NOT be flagged.
        let var = "services:\n  db:\n    image: postgres:16\n    environment:\n      POSTGRES_PASSWORD: $DB_PW\n";
        assert!(!rules(&run_guardrails(var)).contains(&"plaintext-secret"), "a $VAR reference is not plaintext");

        // Credentials embedded in a connection URL evade the key-name list — a
        // key-independent value-shape rule must catch them.
        let url = "services:\n  app:\n    image: app:1.0\n    environment:\n      DATABASE_URL: postgres://user:pw@db/app\n";
        assert!(rules(&run_guardrails(url)).contains(&"embedded-credentials"), "URL creds flagged: {:?}", run_guardrails(url));

        // A URL without an embedded password must NOT trip it (low false-positive).
        let clean = "services:\n  app:\n    image: app:1.0\n    environment:\n      REDIS_URL: redis://cache:6379/0\n";
        assert!(!rules(&run_guardrails(clean)).contains(&"embedded-credentials"), "portful host is not credentials");

        // Letter-led modular-crypt hashes pasted as a literal secret must STILL be
        // flagged (a variable reference has no second `$`).
        for h in ["$apr1$H7abcd", "$argon2id$v=19$m=65536", "$y$j9T$xyz"] {
            let y = format!("services:\n  db:\n    image: postgres:16\n    environment:\n      POSTGRES_PASSWORD: {h}\n");
            assert!(rules(&run_guardrails(&y)).contains(&"plaintext-secret"), "MCF hash {h} must flag: {:?}", run_guardrails(&y));
        }
        // A partial variable reference is NOT a plaintext secret.
        let vref = "services:\n  db:\n    image: postgres:16\n    environment:\n      POSTGRES_PASSWORD: $PREFIX-suffix\n";
        assert!(!rules(&run_guardrails(vref)).contains(&"plaintext-secret"), "a $VAR reference is not plaintext");
    }

    #[test]
    fn whole_disk_udev_symlinks_are_dangerous_devices() {
        assert!(is_dangerous_device("/dev/disk/by-id/ata-Samsung_SSD"), "by-id whole disk");
        assert!(is_dangerous_device("/dev/mapper/vg0-data"), "device-mapper volume");
        assert!(is_dangerous_device("/dev/disk/by-uuid/1234-5678"), "by-uuid");
        // A plain GPU/serial passthrough is still only a warning, not dangerous.
        assert!(!is_dangerous_device("/dev/dri/renderD128"), "GPU is not dangerous");
        assert!(!is_dangerous_device("/dev/ttyUSB0"), "serial is not dangerous");
    }

    #[test]
    fn flags_container_hardening_risks() {
        let yaml = "services:\n  app:\n    image: nginx:1.27\n    privileged: true\n    network_mode: host\n    pid: host\n    cap_add:\n      - SYS_ADMIN\n      - NET_ADMIN\n    volumes:\n      - /var/run/docker.sock:/var/run/docker.sock\n";
        let f = run_guardrails(yaml);
        let rules = rules(&f);
        assert!(rules.contains(&"privileged"), "privileged flagged: {f:?}");
        assert!(f.iter().any(|x| x.rule == "privileged" && x.severity == Severity::Block));
        assert!(rules.contains(&"docker-socket"), "docker.sock mount flagged");
        assert!(f.iter().any(|x| x.rule == "docker-socket" && x.severity == Severity::Block));
        assert!(rules.contains(&"dangerous-cap"), "SYS_ADMIN cap flagged");
        assert!(rules.contains(&"host-network"), "network_mode host flagged");
        assert!(rules.contains(&"host-pid"), "pid host flagged");
        assert!(!verdict(&f), "a privileged/docker-socket stack must not pass");
    }

    #[test]
    fn security_lens_catches_evasion_variants() {
        // privileged as a quoted string (as_bool would miss it)
        assert!(!verdict(&run_guardrails("services:\n  a:\n    image: nginx:1.27\n    privileged: \"true\"\n")), "privileged string");
        // whole host filesystem + writable host-system binds still Block
        let f = run_guardrails("services:\n  a:\n    image: nginx:1.27\n    volumes:\n      - /:/host\n");
        assert!(rules(&f).contains(&"host-root-mount") && !verdict(&f), "root mount blocked: {f:?}");
        assert!(!verdict(&run_guardrails("services:\n  a:\n    image: nginx:1.27\n    volumes:\n      - /var/run:/hr\n")), "writable /var/run bind blocked");
        assert!(!verdict(&run_guardrails("services:\n  a:\n    image: nginx:1.27\n    volumes:\n      - /etc:/hostetc\n")), "writable /etc bind blocked");
        // raw memory/disk devices Block
        let f = run_guardrails("services:\n  a:\n    image: nginx:1.27\n    devices:\n      - /dev/mem:/dev/mem\n");
        assert!(rules(&f).contains(&"host-device") && !verdict(&f), "raw device blocked: {f:?}");
        assert!(!verdict(&run_guardrails("services:\n  a:\n    image: nginx:1.27\n    devices:\n      - /dev/sda:/dev/sda\n")), "whole disk blocked");
        // security_opt unconfined
        assert!(!verdict(&run_guardrails("services:\n  a:\n    image: nginx:1.27\n    security_opt:\n      - seccomp:unconfined\n")), "seccomp unconfined blocked");
        // host-escape caps now Block (were Warn / absent)
        for cap in ["SYS_MODULE", "DAC_READ_SEARCH", "SYS_RAWIO", "SYS_PTRACE"] {
            let y = format!("services:\n  a:\n    image: nginx:1.27\n    cap_add:\n      - {cap}\n");
            assert!(!verdict(&run_guardrails(&y)), "{cap} must block");
        }
        // cap_add as a single scalar string
        assert!(!verdict(&run_guardrails("services:\n  a:\n    image: nginx:1.27\n    cap_add: SYS_ADMIN\n")), "scalar cap_add blocked");
        // ordinary relative/named data binds are NOT sensitive host paths
        assert!(verdict(&run_guardrails("services:\n  a:\n    image: nginx:1.27\n    restart: unless-stopped\n    mem_limit: 128m\n    healthcheck:\n      test: [\"CMD\",\"true\"]\n    volumes:\n      - ./data:/data\n      - db-data:/var/lib/x\n")), "ordinary data binds pass");
    }

    #[test]
    fn common_safe_host_mounts_and_devices_do_not_block() {
        // These are ubiquitous, legitimate self-host patterns; a hard Block here
        // would refuse to deploy real stacks (the regression this fixes).
        let cases = [
            "volumes:\n      - /etc/localtime:/etc/localtime:ro\n",
            "volumes:\n      - /etc/timezone:/etc/timezone:ro\n",
            "volumes:\n      - /sys/fs/cgroup:/sys/fs/cgroup:ro\n", // cAdvisor
            "volumes:\n      - /proc:/host/proc:ro\n",            // node-exporter
            "devices:\n      - /dev/dri:/dev/dri\n",              // GPU transcode
            "devices:\n      - /dev/ttyUSB0:/dev/ttyUSB0\n",      // Zigbee/HA
        ];
        for c in cases {
            let y = format!("services:\n  a:\n    image: nginx:1.27\n    {c}");
            assert!(verdict(&run_guardrails(&y)), "must NOT block a common safe pattern:\n{y}\n{:?}", run_guardrails(&y));
        }
        // a read-only system bind that ISN'T on the allowlist warns (not blocks)
        let f = run_guardrails("services:\n  a:\n    image: nginx:1.27\n    volumes:\n      - /sys:/host/sys:ro\n");
        assert!(verdict(&f) && rules(&f).contains(&"host-path-ro"), "ro system bind warns, not blocks: {f:?}");
    }

    #[test]
    fn ordinary_service_has_no_security_findings() {
        let yaml = "services:\n  web:\n    image: nginx:1.27\n    cap_add:\n      - NET_BIND_SERVICE\n";
        let f = run_guardrails(yaml);
        let rules = rules(&f);
        for r in ["privileged", "docker-socket", "dangerous-cap", "host-network", "host-pid"] {
            assert!(!rules.contains(&r), "benign service should not trip {r}");
        }
    }

    #[test]
    fn clean_service_has_no_blocking_findings() {
        let yaml = "services:\n  web:\n    image: nginx:1.27\n    restart: unless-stopped\n    mem_limit: 256m\n    healthcheck:\n      test: [\"CMD\", \"true\"]\n    environment:\n      DB_PASSWORD: ${DB_PASSWORD}\n";
        let f = run_guardrails(yaml);
        assert!(verdict(&f), "clean service must pass: {f:?}");
        assert!(
            !rules(&f).contains(&"plaintext-secret"),
            "a ${{VAR}} secret reference is not plaintext"
        );
    }

    #[test]
    fn verdict_fails_only_on_block() {
        let block = vec![Finding {
            service: "s".into(),
            rule: "r".into(),
            severity: Severity::Block,
            message: String::new(),
        }];
        let warn = vec![Finding {
            service: "s".into(),
            rule: "r".into(),
            severity: Severity::Warn,
            message: String::new(),
        }];
        assert!(!verdict(&block));
        assert!(verdict(&warn));
        assert!(verdict(&[]));
    }
}
