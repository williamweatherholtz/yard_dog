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
                let mut name = String::new();
                while let Some(&nc) = chars.peek() {
                    chars.next();
                    if nc == '}' {
                        break;
                    }
                    name.push(nc);
                }
                out.push_str(env.get(&name).map(String::as_str).unwrap_or(""));
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
}
