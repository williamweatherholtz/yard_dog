//! Parse the services out of a compose document. Yard Dog no longer classifies
//! services into a "workload kind" (removed per decRemoveWorkloadKind); this
//! module just extracts the per-service signals other code needs — notably
//! whether a service has a persistent/data mount, which keys the cautious
//! update path (a data-backed service is notify-only, not auto-applied).

/// The signals extracted for one service.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ServiceView {
    pub name: String,
    pub image: Option<String>,
    /// True when the service declares any volume (a data/persistent mount).
    pub has_persistent_mount: bool,
}

/// Extract a [`ServiceView`] per service from a compose document.
pub fn parse_services(yaml: &str) -> Vec<ServiceView> {
    let mut out = Vec::new();
    if crate::compose::yaml_guard(yaml).is_err() {
        return out;
    }
    let Ok(doc) = serde_yaml::from_str::<serde_yaml::Value>(yaml) else {
        return out;
    };
    let Some(services) = doc.get("services").and_then(|v| v.as_mapping()) else {
        return out;
    };
    for (name, svc) in services {
        // A *data* mount (writable volume) keys the cautious update path. A
        // read-only mount (e.g. a config file `:ro`) is not data, so it does not.
        let has_persistent_mount = svc
            .get("volumes")
            .and_then(|v| v.as_sequence())
            .map(|seq| seq.iter().any(is_data_volume))
            .unwrap_or(false);
        out.push(ServiceView {
            name: name.as_str().unwrap_or_default().to_string(),
            image: svc.get("image").and_then(|v| v.as_str()).map(String::from),
            has_persistent_mount,
        });
    }
    out
}

/// Whether a compose volume entry is a writable data mount (not read-only).
fn is_data_volume(v: &serde_yaml::Value) -> bool {
    match v {
        serde_yaml::Value::String(s) => {
            // short syntax SRC:DST[:MODE]; read-only iff a MODE field is `ro`.
            let parts: Vec<&str> = s.split(':').collect();
            let read_only =
                parts.len() >= 3 && parts[parts.len() - 1].split(',').any(|m| m.trim() == "ro");
            !read_only
        }
        // long syntax: `read_only: true` marks it non-data.
        serde_yaml::Value::Mapping(_) => {
            !v.get("read_only").and_then(|x| x.as_bool()).unwrap_or(false)
        }
        _ => true,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_services_extracts_name_image_and_data_mount() {
        let yaml = "services:\n  db:\n    image: postgres:16\n    volumes:\n      - db-data:/var/lib/postgresql/data\n  web:\n    image: nginx:1.27\n    ports:\n      - \"8080:80\"\n";
        let views = parse_services(yaml);
        let db = views.iter().find(|v| v.name == "db").unwrap();
        assert_eq!(db.image.as_deref(), Some("postgres:16"));
        assert!(db.has_persistent_mount, "db declares a volume");
        let web = views.iter().find(|v| v.name == "web").unwrap();
        assert_eq!(web.image.as_deref(), Some("nginx:1.27"));
        assert!(!web.has_persistent_mount, "web has no volume");
    }

    #[test]
    fn read_only_config_mount_is_not_a_data_mount() {
        let yaml = "services:\n  web:\n    image: nginx:1.27\n    volumes:\n      - ./nginx.conf:/etc/nginx/nginx.conf:ro\n  app:\n    image: app:1\n    volumes:\n      - ./data:/data\n";
        let views = parse_services(yaml);
        let web = views.iter().find(|v| v.name == "web").unwrap();
        assert!(!web.has_persistent_mount, "a :ro config mount is not data → auto-update ok");
        let app = views.iter().find(|v| v.name == "app").unwrap();
        assert!(app.has_persistent_mount, "a writable bind is data → notify-only");
    }
}
