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
    !v.is_empty() && !v.contains("${") && !v.starts_with('$')
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
            }
        }
    }
    out
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
