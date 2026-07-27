//! Assemble and render the per-mount analysis: classification, host-path
//! existence, ownership issues, and ranked remediations. Pure over the injected
//! traits, so the whole pipeline is unit-testable.

use crate::classify::{classify, MountType, NetworkProbe, VolumeInspector};
use crate::compose::RawMount;
use crate::hostfs::{check_existence, ExistenceReport, HostFs, PathKind};
use crate::ownership::detect_ownership;
use crate::remediation::{remediations_for, Issue, Remediation};

/// The full analysis of one mount.
#[derive(Debug, Clone)]
pub struct MountReport {
    pub service: String,
    pub source: Option<String>,
    pub target: String,
    pub mount_type: MountType,
    pub existence: Option<ExistenceReport>,
    pub issues: Vec<Issue>,
    pub remediations: Vec<Remediation>,
}

/// Stable, human-facing label for a mount type.
pub fn type_label(t: MountType) -> &'static str {
    match t {
        MountType::HostBind => "host-bind",
        MountType::NamedVolume => "named-volume",
        MountType::Anonymous => "anonymous",
        MountType::Network => "network",
    }
}

fn kind_label(k: PathKind) -> &'static str {
    match k {
        PathKind::Directory => "directory",
        PathKind::File => "file",
        PathKind::Symlink => "symlink",
        PathKind::Other => "special",
        PathKind::Missing => "missing",
    }
}

/// True when a mount type refers to a real host path we can stat.
fn is_host_path(t: MountType) -> bool {
    matches!(t, MountType::HostBind | MountType::Network)
}

/// Build the analysis for every mount.
///
/// `expected` is the container's `(PUID, PGID)` when the stack declares them.
pub fn build_report(
    mounts: &[RawMount],
    volumes: &dyn VolumeInspector,
    net: &dyn NetworkProbe,
    fs: &dyn HostFs,
    expected: Option<(u32, u32)>,
) -> Vec<MountReport> {
    mounts
        .iter()
        .map(|m| {
            let mount_type = classify(m, volumes, net);
            let mut existence = None;
            let mut issues = Vec::new();

            if is_host_path(mount_type) {
                if let Some(src) = &m.source {
                    let ex = check_existence(src, fs);
                    if !ex.exists {
                        issues.push(Issue::MissingPath { path: src.clone() });
                    } else if let Some(meta) = fs.metadata(src) {
                        for oi in detect_ownership(&meta, expected) {
                            issues.push(Issue::Ownership {
                                issue: oi,
                                path: src.clone(),
                            });
                        }
                    }
                    existence = Some(ex);
                }
            }

            let remediations = issues.iter().flat_map(remediations_for).collect();
            MountReport {
                service: m.service.clone(),
                source: m.source.clone(),
                target: m.target.clone(),
                mount_type,
                existence,
                issues,
                remediations,
            }
        })
        .collect()
}

/// Render the reports as a plain-text summary for the CLI.
pub fn render_text(reports: &[MountReport]) -> String {
    let mut out = String::new();
    for r in reports {
        let src = r.source.as_deref().unwrap_or("(anonymous)");
        out.push_str(&format!(
            "[{}] {} -> {}  ({})\n",
            type_label(r.mount_type),
            src,
            r.target,
            r.service
        ));
        if let Some(ex) = &r.existence {
            out.push_str(&format!(
                "    host path: {} ({})\n",
                if ex.exists { "exists" } else { "MISSING" },
                kind_label(ex.kind)
            ));
        }
        for rem in &r.remediations {
            out.push_str(&format!("    fix {}: {}\n", rem.rank, rem.summary));
            if let Some(cmd) = &rem.command {
                out.push_str(&format!("            $ {cmd}\n"));
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::classify::VolumeInfo;
    use std::collections::HashMap;

    struct NoVols;
    impl VolumeInspector for NoVols {
        fn inspect(&self, _n: &str) -> Option<VolumeInfo> {
            None
        }
    }
    struct LocalFsOnly;
    impl NetworkProbe for LocalFsOnly {
        fn fs_type(&self, _p: &str) -> Option<String> {
            None
        }
    }
    struct MapFs(HashMap<String, PathKind>);
    impl HostFs for MapFs {
        fn kind(&self, p: &str) -> PathKind {
            self.0.get(p).copied().unwrap_or(PathKind::Missing)
        }
        fn metadata(&self, _p: &str) -> Option<crate::hostfs::PathMeta> {
            None
        }
    }

    #[test]
    fn missing_bind_yields_a_create_remediation_in_text() {
        let mounts = vec![RawMount {
            service: "app".into(),
            source: Some("/srv/missing".into()),
            target: "/data".into(),
            read_only: false,
            long_form: false,
        }];
        let reports = build_report(&mounts, &NoVols, &LocalFsOnly, &MapFs(HashMap::new()), None);
        let text = render_text(&reports).to_lowercase();
        assert!(text.contains("host-bind"));
        assert!(text.contains("missing"));
        assert!(text.contains("create"));
    }
}
