//! Parse a docker-compose file into the raw mounts declared by its services.
//!
//! Handles both the short (`"src:dst[:mode]"`) and long (`{type,source,target,
//! read_only}`) volume syntaxes, and interpolates `${VAR}` / `$VAR` against a
//! supplied environment map. Classification of each mount into a path type is a
//! separate concern (see `classify`); this module only extracts what was written.

use std::collections::HashMap;

/// A mount exactly as declared on a service, before any classification.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RawMount {
    pub service: String,
    /// `None` for an anonymous volume (only a container target was given).
    pub source: Option<String>,
    pub target: String,
    pub read_only: bool,
    pub long_form: bool,
}

#[derive(Debug, PartialEq, Eq)]
pub enum ComposeError {
    Yaml(String),
}

/// Extract every service mount from a compose document, interpolating `${VAR}`.
pub fn parse_mounts(
    yaml: &str,
    env: &HashMap<String, String>,
) -> Result<Vec<RawMount>, ComposeError> {
    let doc: serde_yaml::Value =
        serde_yaml::from_str(yaml).map_err(|e| ComposeError::Yaml(e.to_string()))?;

    let mut mounts = Vec::new();
    let Some(services) = doc.get("services").and_then(|v| v.as_mapping()) else {
        return Ok(mounts);
    };

    for (name, svc) in services {
        let service = name.as_str().unwrap_or_default().to_string();
        let Some(volumes) = svc.get("volumes").and_then(|v| v.as_sequence()) else {
            continue;
        };
        for entry in volumes {
            if let Some(s) = entry.as_str() {
                mounts.push(parse_short(&service, &interpolate(s, env)));
            } else if let Some(map) = entry.as_mapping() {
                mounts.push(parse_long(&service, map, env));
            }
        }
    }
    Ok(mounts)
}

/// Parse the short `[SOURCE:]TARGET[:MODE]` volume form (already interpolated).
///
/// Note: a Windows drive letter (`C:\`) would defeat naive `:` splitting, but a
/// compose file for a Linux Docker host uses POSIX source paths — Windows-host
/// sources are out of scope for v1.
fn parse_short(service: &str, spec: &str) -> RawMount {
    let parts: Vec<&str> = spec.split(':').collect();
    match parts.as_slice() {
        [target] => RawMount {
            service: service.to_string(),
            source: None,
            target: (*target).to_string(),
            read_only: false,
            long_form: false,
        },
        [source, target] => RawMount {
            service: service.to_string(),
            source: Some((*source).to_string()),
            target: (*target).to_string(),
            read_only: false,
            long_form: false,
        },
        [source, target, mode, ..] => RawMount {
            service: service.to_string(),
            source: Some((*source).to_string()),
            target: (*target).to_string(),
            read_only: mode_is_read_only(mode),
            long_form: false,
        },
        [] => RawMount {
            service: service.to_string(),
            source: None,
            target: String::new(),
            read_only: false,
            long_form: false,
        },
    }
}

/// Parse the long-form mapping (`type`/`source`/`target`/`read_only`).
fn parse_long(
    service: &str,
    map: &serde_yaml::Mapping,
    env: &HashMap<String, String>,
) -> RawMount {
    let get = |k: &str| map.get(serde_yaml::Value::from(k));
    let source = get("source")
        .and_then(|v| v.as_str())
        .map(|s| interpolate(s, env));
    let target = get("target")
        .and_then(|v| v.as_str())
        .map(|s| interpolate(s, env))
        .unwrap_or_default();
    let read_only = get("read_only").and_then(|v| v.as_bool()).unwrap_or(false);
    RawMount {
        service: service.to_string(),
        source,
        target,
        read_only,
        long_form: true,
    }
}

/// A short-form mode field is read-only if any comma-part is exactly `ro`.
fn mode_is_read_only(mode: &str) -> bool {
    mode.split(',').any(|opt| opt.trim() == "ro")
}

/// Substitute `${VAR}` and `$VAR` (ASCII word chars) from `env`; unknown → empty.
fn interpolate(input: &str, env: &HashMap<String, String>) -> String {
    let mut out = String::with_capacity(input.len());
    let mut chars = input.chars().peekable();
    while let Some(c) = chars.next() {
        if c != '$' {
            out.push(c);
            continue;
        }
        match chars.peek() {
            Some('{') => {
                chars.next();
                let mut inner = String::new();
                while let Some(&nc) = chars.peek() {
                    chars.next();
                    if nc == '}' {
                        break;
                    }
                    inner.push(nc);
                }
                out.push_str(&resolve_braced(&inner, env));
            }
            Some(&nc) if nc.is_ascii_alphanumeric() || nc == '_' => {
                let mut name = String::new();
                while let Some(&nc) = chars.peek() {
                    if nc.is_ascii_alphanumeric() || nc == '_' {
                        name.push(nc);
                        chars.next();
                    } else {
                        break;
                    }
                }
                out.push_str(env.get(&name).map(String::as_str).unwrap_or(""));
            }
            _ => out.push('$'),
        }
    }
    out
}

/// Read each service's `PUID`/`PGID` from its `environment` (list or map form),
/// interpolating `${VAR}` values. Returns service name -> (puid, pgid).
pub fn parse_service_ids(
    yaml: &str,
    env: &HashMap<String, String>,
) -> HashMap<String, (Option<u32>, Option<u32>)> {
    let mut out = HashMap::new();
    let Ok(doc) = serde_yaml::from_str::<serde_yaml::Value>(yaml) else {
        return out;
    };
    let Some(services) = doc.get("services").and_then(|v| v.as_mapping()) else {
        return out;
    };
    for (name, svc) in services {
        let service = name.as_str().unwrap_or_default().to_string();
        let mut puid = None;
        let mut pgid = None;
        let mut set = |k: &str, v: &str| {
            let resolved = interpolate(v, env);
            if let Ok(n) = resolved.trim().parse::<u32>() {
                match k {
                    "PUID" => puid = Some(n),
                    "PGID" => pgid = Some(n),
                    _ => {}
                }
            }
        };
        match svc.get("environment") {
            Some(serde_yaml::Value::Sequence(items)) => {
                for item in items {
                    if let Some(s) = item.as_str() {
                        if let Some((k, v)) = s.split_once('=') {
                            set(k.trim(), v);
                        }
                    }
                }
            }
            Some(serde_yaml::Value::Mapping(map)) => {
                for (k, v) in map {
                    let key = k.as_str().unwrap_or_default();
                    let val = match v {
                        serde_yaml::Value::String(s) => s.clone(),
                        serde_yaml::Value::Number(n) => n.to_string(),
                        _ => continue,
                    };
                    set(key, &val);
                }
            }
            _ => {}
        }
        out.insert(service, (puid, pgid));
    }
    out
}

/// Resolve the content between `${` and `}`, supporting the shell/compose forms
/// `${VAR}`, `${VAR:-default}`, `${VAR-default}`, `${VAR:?err}`, `${VAR?err}`,
/// `${VAR:+alt}`, `${VAR+alt}`. `:` variants treat an empty value like unset.
/// The default/alt word is itself interpolated. `:?`/`?` do not panic — an
/// unset value resolves to empty (the CLI layer may surface the message).
fn resolve_braced(inner: &str, env: &HashMap<String, String>) -> String {
    let name_end = inner
        .find(|c: char| !(c.is_ascii_alphanumeric() || c == '_'))
        .unwrap_or(inner.len());
    let (name, rest) = inner.split_at(name_end);
    let val = env.get(name).map(String::as_str);

    if rest.is_empty() {
        return val.unwrap_or("").to_string();
    }

    let (colon, op_rest) = match rest.strip_prefix(':') {
        Some(r) => (true, r),
        None => (false, rest),
    };
    let (op, word) = match op_rest.chars().next() {
        Some(c @ ('-' | '?' | '+')) => (c, &op_rest[1..]),
        _ => ('\0', op_rest),
    };

    let present = if colon {
        val.map_or(false, |v| !v.is_empty())
    } else {
        val.is_some()
    };

    match op {
        '-' => {
            if present {
                val.unwrap_or("").to_string()
            } else {
                interpolate(word, env)
            }
        }
        '+' => {
            if present {
                interpolate(word, env)
            } else {
                String::new()
            }
        }
        '?' => {
            if present {
                val.unwrap_or("").to_string()
            } else {
                String::new()
            }
        }
        _ => val.unwrap_or("").to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_short_and_long_mounts_with_interpolation() {
        let yaml = r#"
services:
  db:
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ${CONF_DIR}/db.conf:/etc/db.conf:ro
      - /var/log
      - type: bind
        source: /srv/backups
        target: /backups
        read_only: true
"#;
        let mut env = HashMap::new();
        env.insert("CONF_DIR".to_string(), "/opt/conf".to_string());

        let mounts = parse_mounts(yaml, &env).expect("compose should parse");
        assert_eq!(mounts.len(), 4, "expected 4 mounts on service db");

        // named volume (short)
        assert_eq!(mounts[0].source.as_deref(), Some("pgdata"));
        assert_eq!(mounts[0].target, "/var/lib/postgresql/data");
        assert!(!mounts[0].read_only);
        assert_eq!(mounts[0].service, "db");

        // bind with ${VAR} interpolation + read-only (short)
        assert_eq!(mounts[1].source.as_deref(), Some("/opt/conf/db.conf"));
        assert_eq!(mounts[1].target, "/etc/db.conf");
        assert!(mounts[1].read_only);

        // anonymous volume (short, target only)
        assert_eq!(mounts[2].source, None);
        assert_eq!(mounts[2].target, "/var/log");

        // bind (long form) read-only
        assert_eq!(mounts[3].source.as_deref(), Some("/srv/backups"));
        assert_eq!(mounts[3].target, "/backups");
        assert!(mounts[3].read_only);
        assert!(mounts[3].long_form);
    }

    #[test]
    fn parse_service_ids_reads_list_and_map_forms() {
        let yaml = r#"
services:
  a:
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=UTC
  b:
    environment:
      PUID: "1500"
      PGID: 1600
  c:
    image: nginx
"#;
        let env = HashMap::new();
        let ids = parse_service_ids(yaml, &env);
        assert_eq!(ids.get("a"), Some(&(Some(1000), Some(1000))));
        assert_eq!(ids.get("b"), Some(&(Some(1500), Some(1600))));
        assert_eq!(ids.get("c"), Some(&(None, None)));
    }

    #[test]
    fn interpolation_handles_default_and_error_forms() {
        let env = HashMap::from([("SET".to_string(), "yes".to_string())]);
        // ${VAR:-default} — default when unset/empty
        assert_eq!(interpolate("${UNSET:-/opt/def}", &env), "/opt/def");
        assert_eq!(interpolate("${SET:-/opt/def}", &env), "yes");
        // ${VAR-default} — default only when unset
        assert_eq!(interpolate("${UNSET-/opt/def}", &env), "/opt/def");
        assert_eq!(interpolate("${SET-/opt/def}", &env), "yes");
        // ${VAR:?err} — value when set (non-panicking: empty when unset)
        assert_eq!(interpolate("${SET:?must be set}", &env), "yes");
        assert_eq!(interpolate("${UNSET:?must be set}", &env), "");
        // embedded in a path
        assert_eq!(
            interpolate("${CONF:-/opt/immich}/config", &env),
            "/opt/immich/config"
        );
        // plain forms still work
        assert_eq!(interpolate("${SET}", &env), "yes");
        assert_eq!(interpolate("$SET/x", &env), "yes/x");
    }
}
