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
    let Ok(doc) = serde_yaml::from_str::<serde_yaml::Value>(yaml) else {
        return out;
    };
    let Some(services) = doc.get("services").and_then(|v| v.as_mapping()) else {
        return out;
    };
    for (name, svc) in services {
        let has_persistent_mount = svc
            .get("volumes")
            .and_then(|v| v.as_sequence())
            .map(|s| !s.is_empty())
            .unwrap_or(false);
        out.push(ServiceView {
            name: name.as_str().unwrap_or_default().to_string(),
            image: svc.get("image").and_then(|v| v.as_str()).map(String::from),
            has_persistent_mount,
        });
    }
    out
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
}
