//! Backup planning: detect each service's database engine, enumerate a stack's
//! persistent data (reusing the path classifier), and assemble a reviewable,
//! application-consistent backup plan. This module PLANS only — it executes
//! nothing (execution is a later increment).

use crate::classify::{classify, MountType, NetworkProbe, VolumeInspector};
use crate::compose::{parse_mounts, parse_service_images, RawMount};
use std::collections::HashMap;

/// A recognised database engine and the consistent-dump method it implies.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DbEngine {
    Postgres,
    Mysql,
    Mariadb,
    Mongo,
    Redis,
}

impl DbEngine {
    /// A representative application-consistent dump command for the engine.
    pub fn dump_command(&self) -> &'static str {
        match self {
            DbEngine::Postgres => "pg_dumpall -U \"$POSTGRES_USER\"",
            DbEngine::Mysql => "mysqldump --all-databases --single-transaction",
            DbEngine::Mariadb => "mariadb-dump --all-databases --single-transaction",
            DbEngine::Mongo => "mongodump --archive",
            DbEngine::Redis => "redis-cli --rdb /data/dump.rdb",
        }
    }
}

/// Detect a database engine from a container image (and environment).
pub fn detect_db_engine(image: &str, _env: &HashMap<String, String>) -> Option<DbEngine> {
    // repo = last path segment, minus any tag
    let last = image.rsplit('/').next().unwrap_or(image);
    let repo = last.split(':').next().unwrap_or(last).to_ascii_lowercase();
    if repo.contains("postgres") || repo.contains("postgis") {
        Some(DbEngine::Postgres)
    } else if repo.contains("mariadb") {
        Some(DbEngine::Mariadb)
    } else if repo.contains("mysql") {
        Some(DbEngine::Mysql)
    } else if repo.contains("mongo") {
        Some(DbEngine::Mongo)
    } else if repo.contains("redis") || repo.contains("valkey") {
        Some(DbEngine::Redis)
    } else {
        None
    }
}

/// What kind of persistent-data target a backup step covers.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TargetKind {
    Volume,
    Bind,
    Network,
}

/// One persistent-data target to back up.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BackupTarget {
    pub name: String,
    pub kind: TargetKind,
}

/// Enumerate the persistent-data targets of a stack (named volumes + bind/host
/// paths, incl. network), excluding anonymous/ephemeral mounts; de-duplicated.
pub fn enumerate_stack_data(
    mounts: &[RawMount],
    volumes: &dyn VolumeInspector,
    net: &dyn NetworkProbe,
) -> Vec<BackupTarget> {
    let mut out: Vec<BackupTarget> = Vec::new();
    for m in mounts {
        let kind = match classify(m, volumes, net) {
            MountType::NamedVolume => TargetKind::Volume,
            MountType::HostBind => TargetKind::Bind,
            MountType::Network => TargetKind::Network,
            MountType::Anonymous => continue,
        };
        if let Some(name) = &m.source {
            let target = BackupTarget {
                name: name.clone(),
                kind,
            };
            if !out.contains(&target) {
                out.push(target);
            }
        }
    }
    out
}

/// A consistent dump step for one detected database.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DumpStep {
    pub service: String,
    pub engine: DbEngine,
    pub command: String,
}

/// A reviewable backup plan: consistent dumps + data copies.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BackupPlan {
    pub dumps: Vec<DumpStep>,
    pub copies: Vec<BackupTarget>,
}

/// Assemble the backup plan for a stack.
pub fn build_backup_plan(
    yaml: &str,
    env: &HashMap<String, String>,
    volumes: &dyn VolumeInspector,
    net: &dyn NetworkProbe,
) -> BackupPlan {
    let mut dumps: Vec<DumpStep> = parse_service_images(yaml)
        .into_iter()
        .filter_map(|(service, image)| {
            detect_db_engine(&image, env).map(|engine| DumpStep {
                service,
                engine,
                command: engine.dump_command().to_string(),
            })
        })
        .collect();
    dumps.sort_by(|a, b| a.service.cmp(&b.service));

    let mounts = parse_mounts(yaml, env).unwrap_or_default();
    let copies = enumerate_stack_data(&mounts, volumes, net);
    BackupPlan { dumps, copies }
}

/// Render a backup plan as a plain-text summary for the CLI.
pub fn render_plan(plan: &BackupPlan) -> String {
    let mut out = String::from("Backup plan (review only — nothing runs):\n");
    if plan.dumps.is_empty() {
        out.push_str("  databases: none detected\n");
    }
    for d in &plan.dumps {
        out.push_str(&format!("  dump [{}] {:?}: {}\n", d.service, d.engine, d.command));
    }
    for c in &plan.copies {
        out.push_str(&format!("  copy [{:?}] {}\n", c.kind, c.name));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::classify::VolumeInfo;

    fn env() -> HashMap<String, String> {
        HashMap::new()
    }

    struct NoVols;
    impl VolumeInspector for NoVols {
        fn inspect(&self, _n: &str) -> Option<VolumeInfo> {
            None
        }
    }
    struct LocalFs;
    impl NetworkProbe for LocalFs {
        fn fs_type(&self, _p: &str) -> Option<String> {
            None
        }
    }

    #[test]
    fn detects_engines_from_image() {
        let e = env();
        assert_eq!(detect_db_engine("postgres:16", &e), Some(DbEngine::Postgres));
        assert_eq!(detect_db_engine("mariadb:11", &e), Some(DbEngine::Mariadb));
        assert_eq!(detect_db_engine("mysql:8", &e), Some(DbEngine::Mysql));
        assert_eq!(
            detect_db_engine("ghcr.io/org/mongo:7", &e),
            Some(DbEngine::Mongo)
        );
        assert_eq!(detect_db_engine("redis:7-alpine", &e), Some(DbEngine::Redis));
        assert_eq!(detect_db_engine("nginx:latest", &e), None);
        assert!(DbEngine::Postgres.dump_command().contains("pg_dump"));
    }

    #[test]
    fn enumerate_excludes_anonymous_mounts() {
        let yaml = "services:\n  a:\n    volumes:\n      - pgdata:/var/lib/postgresql/data\n      - /srv/media:/media\n      - /cache\n";
        let mounts = parse_mounts(yaml, &env()).unwrap();
        let targets = enumerate_stack_data(&mounts, &NoVols, &LocalFs);
        assert!(targets.contains(&BackupTarget {
            name: "pgdata".into(),
            kind: TargetKind::Volume
        }));
        assert!(targets.contains(&BackupTarget {
            name: "/srv/media".into(),
            kind: TargetKind::Bind
        }));
        assert_eq!(targets.len(), 2, "the anonymous /cache mount is excluded");
    }

    #[test]
    fn builds_plan_with_dump_and_copies() {
        let yaml = "services:\n  db:\n    image: postgres:16\n    volumes:\n      - pgdata:/var/lib/postgresql/data\n  app:\n    image: nginx\n    volumes:\n      - /srv/site:/usr/share/nginx/html\n";
        let plan = build_backup_plan(yaml, &env(), &NoVols, &LocalFs);
        assert_eq!(plan.dumps.len(), 1);
        assert_eq!(plan.dumps[0].service, "db");
        assert_eq!(plan.dumps[0].engine, DbEngine::Postgres);
        assert!(plan.copies.iter().any(|t| t.name == "pgdata"));
        assert!(plan.copies.iter().any(|t| t.name == "/srv/site"));
    }
}
