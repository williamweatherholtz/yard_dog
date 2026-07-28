//! Classify a raw mount into exactly one of the four Yard Dog path types.
//!
//! Two host-touching capabilities are injected as traits so the decision logic
//! is fully unit-testable against fixtures:
//!   - [`VolumeInspector`] — resolves a named volume's driver/options (Docker).
//!   - [`NetworkProbe`]     — resolves the filesystem type backing a host path
//!     (the host mount table).

use crate::compose::RawMount;
use std::collections::HashMap;

/// The authoritative classification of a mount.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MountType {
    /// A bind mount of a host path.
    HostBind,
    /// A named Docker volume (local driver, non-network).
    NamedVolume,
    /// An anonymous / container-only volume (no source given).
    Anonymous,
    /// A network-backed mount (NFS/CIFS/SMB) — whether via a bind on a network
    /// filesystem or a named volume whose driver options are network.
    Network,
}

/// A named volume's driver and options, as reported by the Docker daemon.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VolumeInfo {
    pub driver: String,
    pub options: HashMap<String, String>,
}

/// Resolves a named volume to its [`VolumeInfo`], or `None` if it does not exist.
pub trait VolumeInspector {
    fn inspect(&self, name: &str) -> Option<VolumeInfo>;
}

/// Resolves the filesystem type (e.g. `"nfs"`, `"cifs"`, `"ext4"`) backing a
/// host path, from the host mount table; `None` if unknown.
pub trait NetworkProbe {
    fn fs_type(&self, path: &str) -> Option<String>;
}

/// Filesystem types we treat as network-backed.
fn is_network_fs(fs: &str) -> bool {
    matches!(
        fs.to_ascii_lowercase().as_str(),
        "nfs" | "nfs4" | "cifs" | "smb" | "smbfs" | "smb3"
    )
}

/// A compose source denotes a host path (bind) rather than a named volume when
/// it contains a path separator or begins with `.` / `~` / `/`.
pub fn is_path_source(source: &str) -> bool {
    source.starts_with('/')
        || source.starts_with('.')
        || source.starts_with('~')
        || source.contains('/')
}

/// True when a named volume's driver/options indicate a network backing.
fn volume_is_network(info: &VolumeInfo) -> bool {
    if info.driver.to_ascii_lowercase().contains("nfs")
        || info.driver.to_ascii_lowercase().contains("cifs")
    {
        return true;
    }
    info.options
        .get("type")
        .map(|t| is_network_fs(t))
        .unwrap_or(false)
}

/// Classify a single mount.
pub fn classify(
    mount: &RawMount,
    volumes: &dyn VolumeInspector,
    net: &dyn NetworkProbe,
) -> MountType {
    let Some(source) = mount.source.as_deref() else {
        return MountType::Anonymous;
    };

    if is_path_source(source) {
        // A host bind — network-backed if its host path sits on a network fs.
        return match net.fs_type(source) {
            Some(fs) if is_network_fs(&fs) => MountType::Network,
            _ => MountType::HostBind,
        };
    }

    // A named volume — network-backed if its driver/options say so.
    match volumes.inspect(source) {
        Some(info) if volume_is_network(&info) => MountType::Network,
        _ => MountType::NamedVolume,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mount(source: Option<&str>, target: &str) -> RawMount {
        RawMount {
            service: "svc".into(),
            source: source.map(|s| s.to_string()),
            target: target.into(),
            read_only: false,
            long_form: false,
        }
    }

    struct StubInspector {
        vols: HashMap<String, VolumeInfo>,
    }
    impl VolumeInspector for StubInspector {
        fn inspect(&self, name: &str) -> Option<VolumeInfo> {
            self.vols.get(name).cloned()
        }
    }

    struct StubProbe {
        fs: HashMap<String, String>, // path prefix -> fs type
    }
    impl NetworkProbe for StubProbe {
        fn fs_type(&self, path: &str) -> Option<String> {
            self.fs
                .iter()
                .filter(|(prefix, _)| path.starts_with(prefix.as_str()))
                .max_by_key(|(prefix, _)| prefix.len())
                .map(|(_, fs)| fs.clone())
        }
    }

    fn nfs_volume() -> VolumeInfo {
        let mut options = HashMap::new();
        options.insert("type".into(), "nfs".into());
        options.insert("o".into(), "addr=10.0.0.5,rw".into());
        VolumeInfo {
            driver: "local".into(),
            options,
        }
    }

    #[test]
    fn classifies_each_of_the_four_types() {
        let vols = StubInspector {
            vols: HashMap::from([
                (
                    "pgdata".to_string(),
                    VolumeInfo {
                        driver: "local".into(),
                        options: HashMap::new(),
                    },
                ),
                ("nas".to_string(), nfs_volume()),
            ]),
        };
        let net = StubProbe {
            fs: HashMap::from([
                ("/srv".to_string(), "ext4".to_string()),
                ("/mnt/nfsshare".to_string(), "nfs".to_string()),
            ]),
        };

        // named volume, local -> NamedVolume
        assert_eq!(
            classify(&mount(Some("pgdata"), "/var/lib/postgresql/data"), &vols, &net),
            MountType::NamedVolume
        );
        // host bind on a local fs -> HostBind
        assert_eq!(
            classify(&mount(Some("/srv/data"), "/data"), &vols, &net),
            MountType::HostBind
        );
        // no source -> Anonymous
        assert_eq!(
            classify(&mount(None, "/cache"), &vols, &net),
            MountType::Anonymous
        );
        // named volume with nfs driver options -> Network
        assert_eq!(
            classify(&mount(Some("nas"), "/media"), &vols, &net),
            MountType::Network
        );
        // host bind that lands on an nfs mount -> Network
        assert_eq!(
            classify(&mount(Some("/mnt/nfsshare/movies"), "/media"), &vols, &net),
            MountType::Network
        );
    }
}
