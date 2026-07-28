//! Assemble and render the per-mount analysis: classification, host-path
//! existence, ownership issues, and ranked remediations. Pure over the injected
//! traits, so the whole pipeline is unit-testable.

use crate::classify::{classify, MountType, NetworkProbe, VolumeInspector};
use crate::compose::RawMount;
use crate::hostfs::{check_existence, ExistenceReport, HostFs, PathKind};
use crate::ownership::detect_ownership;
use crate::remediation::{remediations_for, Issue, Remediation};
use std::collections::HashMap;

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

/// Whether the container target implies a directory or a file, when the shape of
/// the target gives a *strong* signal — a trailing slash means a directory; a
/// recognized config/file extension means a file. Extensionless targets return
/// `None` (unknown) so an intentional extensionless file bind isn't false-flagged.
fn expected_kind(target: &str) -> Option<bool> {
    const FILE_EXTS: &[&str] = &[
        "conf", "cfg", "cnf", "yaml", "yml", "json", "toml", "ini", "env", "pem", "crt", "key",
        "properties", "xml", "sh", "sql", "pub",
    ];
    if target.ends_with('/') {
        return Some(true);
    }
    let base = target.rsplit(['/', '\\']).next().unwrap_or(target);
    if let Some((_, ext)) = base.rsplit_once('.') {
        if FILE_EXTS.contains(&ext.to_ascii_lowercase().as_str()) {
            return Some(false);
        }
    }
    None
}

/// Build the analysis for every mount.
///
/// `expected` is the container's `(PUID, PGID)` when the stack declares them.
pub fn build_report(
    mounts: &[RawMount],
    volumes: &dyn VolumeInspector,
    net: &dyn NetworkProbe,
    fs: &dyn HostFs,
    ids_by_service: &HashMap<String, (u32, u32)>,
) -> Vec<MountReport> {
    mounts
        .iter()
        .map(|m| {
            let mount_type = classify(m, volumes, net);
            let expected = ids_by_service.get(&m.service).copied();
            let mut existence = None;
            let mut issues = Vec::new();

            // Only probe/create a real host PATH. A network-backed *named volume*
            // (MountType::Network with a volume-name source, e.g. an NFS/CIFS
            // driver volume) is managed by Docker — stat'ing or creating it by its
            // bare name would falsely report "missing" and `yd fix` would mkdir a
            // junk dir named after the volume in the CWD.
            if is_host_path(mount_type) {
                if let Some(src) = m.source.as_ref().filter(|s| crate::classify::is_path_source(s.as_str())) {
                    let ex = check_existence(src, fs);
                    if !ex.exists {
                        issues.push(Issue::MissingPath { path: src.clone() });
                    } else {
                        // Wrong-kind bind: a file where a directory is wanted (or
                        // vice-versa) — Docker would bind it anyway and the container
                        // then breaks. Only flag on a strong target-shape signal.
                        match (expected_kind(&m.target), ex.kind) {
                            (Some(true), PathKind::File) => issues.push(Issue::TypeMismatch {
                                path: src.clone(),
                                found: PathKind::File,
                                expected_dir: true,
                            }),
                            (Some(false), PathKind::Directory) => issues.push(Issue::TypeMismatch {
                                path: src.clone(),
                                found: PathKind::Directory,
                                expected_dir: false,
                            }),
                            _ => {}
                        }
                        if let Some(meta) = fs.metadata(src) {
                            for oi in detect_ownership(&meta, expected) {
                                issues.push(Issue::Ownership {
                                    issue: oi,
                                    path: src.clone(),
                                });
                            }
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
        let reports = build_report(
            &mounts,
            &NoVols,
            &LocalFsOnly,
            &MapFs(HashMap::new()),
            &HashMap::new(),
        );
        let text = render_text(&reports).to_lowercase();
        assert!(text.contains("host-bind"));
        assert!(text.contains("missing"));
        assert!(text.contains("create"));
    }

    struct MetaFs {
        kind: PathKind,
        meta: Option<crate::hostfs::PathMeta>,
    }
    impl HostFs for MetaFs {
        fn kind(&self, _p: &str) -> PathKind {
            self.kind
        }
        fn metadata(&self, _p: &str) -> Option<crate::hostfs::PathMeta> {
            self.meta
        }
    }

    #[test]
    fn wrong_kind_bind_flagged_as_type_mismatch() {
        // A file bound where a directory is expected (trailing-slash target).
        let mounts = vec![RawMount {
            service: "app".into(),
            source: Some("/srv/thing".into()),
            target: "/data/".into(),
            read_only: false,
            long_form: false,
        }];
        let fs = MapFs(HashMap::from([("/srv/thing".to_string(), PathKind::File)]));
        let reports = build_report(&mounts, &NoVols, &LocalFsOnly, &fs, &HashMap::new());
        assert!(
            reports[0].issues.iter().any(|i| matches!(
                i,
                Issue::TypeMismatch { expected_dir: true, found: PathKind::File, .. }
            )),
            "file-where-dir-expected must be a TypeMismatch: {:?}",
            reports[0].issues
        );

        // A directory bound where a config file is expected (recognized extension).
        let mounts = vec![RawMount {
            service: "web".into(),
            source: Some("/srv/nginx.conf".into()),
            target: "/etc/nginx/nginx.conf".into(),
            read_only: true,
            long_form: false,
        }];
        let fs = MapFs(HashMap::from([("/srv/nginx.conf".to_string(), PathKind::Directory)]));
        let reports = build_report(&mounts, &NoVols, &LocalFsOnly, &fs, &HashMap::new());
        assert!(reports[0].issues.iter().any(|i| matches!(
            i,
            Issue::TypeMismatch { expected_dir: false, found: PathKind::Directory, .. }
        )));

        // Extensionless target with a matching-kind directory: no false positive.
        let mounts = vec![RawMount {
            service: "app".into(),
            source: Some("/srv/data".into()),
            target: "/data".into(),
            read_only: false,
            long_form: false,
        }];
        let fs = MapFs(HashMap::from([("/srv/data".to_string(), PathKind::Directory)]));
        let reports = build_report(&mounts, &NoVols, &LocalFsOnly, &fs, &HashMap::new());
        assert!(!reports[0].issues.iter().any(|i| matches!(i, Issue::TypeMismatch { .. })));
    }

    #[test]
    fn ownership_mismatch_flagged_from_service_ids() {
        use crate::ownership::OwnershipIssue;
        let mounts = vec![RawMount {
            service: "app".into(),
            source: Some("/srv/data".into()),
            target: "/data".into(),
            read_only: false,
            long_form: false,
        }];
        let fs = MetaFs {
            kind: PathKind::Directory,
            meta: Some(crate::hostfs::PathMeta {
                uid: 0,
                gid: 0,
                mode: 0o755,
            }),
        };
        let ids = HashMap::from([("app".to_string(), (1000u32, 1000u32))]);

        let reports = build_report(&mounts, &NoVols, &LocalFsOnly, &fs, &ids);
        assert!(reports[0].issues.iter().any(|i| matches!(
            i,
            Issue::Ownership {
                issue: OwnershipIssue::RootOwned,
                ..
            }
        )));
        assert!(render_text(&reports).to_lowercase().contains("chown"));
    }
}
