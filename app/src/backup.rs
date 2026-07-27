//! Backup planning: detect each service's database engine, enumerate a stack's
//! persistent data (reusing the path classifier), and assemble a reviewable,
//! application-consistent backup plan. This module PLANS only — it executes
//! nothing (execution is a later increment).

use crate::classify::{classify, MountType, NetworkProbe, VolumeInfo, VolumeInspector};
use crate::compose::{parse_mounts, parse_service_images, RawMount};
use std::collections::HashMap;
use std::path::Path;

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

/// Runs a database's consistent dump inside its container.
pub trait CommandRunner {
    fn run_dump(&self, service: &str, command: &str, dest_dir: &str) -> std::io::Result<()>;
}

/// Copies a persistent-data target into the backup destination.
pub trait Archiver {
    fn archive(&self, target: &BackupTarget, dest_dir: &str) -> std::io::Result<()>;
}

/// What a backup run actually captured.
#[derive(Debug, Default, PartialEq, Eq)]
pub struct BackupManifest {
    pub dumped: Vec<String>,
    pub copied: Vec<String>,
}

/// Execute a backup plan into `dest_dir` — but only when `confirmed`. Without
/// confirmation it performs no writes and returns an empty manifest.
pub fn execute_plan(
    plan: &BackupPlan,
    dest_dir: &str,
    confirmed: bool,
    runner: &dyn CommandRunner,
    archiver: &dyn Archiver,
) -> std::io::Result<BackupManifest> {
    let mut manifest = BackupManifest::default();
    if !confirmed {
        return Ok(manifest);
    }
    for dump in &plan.dumps {
        runner.run_dump(&dump.service, &dump.command, dest_dir)?;
        manifest.dumped.push(dump.service.clone());
    }
    for target in &plan.copies {
        archiver.archive(target, dest_dir)?;
        manifest.copied.push(target.name.clone());
    }
    Ok(manifest)
}

/// Runs a `docker` invocation (argv are the arguments after `docker`).
pub trait DockerRunner {
    fn run(&self, argv: &[String]) -> std::io::Result<()>;
}

/// Build the `docker` argv that tars a named volume into `dest_dir` using a
/// throwaway alpine container. Output file is `<volume>.tar.gz`.
pub fn volume_archive_argv(volume: &str, dest_dir: &str) -> Vec<String> {
    vec![
        "run".into(),
        "--rm".into(),
        "-v".into(),
        format!("{volume}:/src:ro"),
        "-v".into(),
        format!("{dest_dir}:/backup"),
        "alpine".into(),
        "tar".into(),
        "czf".into(),
        format!("/backup/{volume}.tar.gz"),
        "-C".into(),
        "/src".into(),
        ".".into(),
    ]
}

/// Archive a named volume by running the built argv through `runner`.
pub fn archive_volume(volume: &str, dest_dir: &str, runner: &dyn DockerRunner) -> std::io::Result<()> {
    runner.run(&volume_archive_argv(volume, dest_dir))
}

/// An [`Archiver`] that archives named volumes via Docker; bind/network targets
/// are left to a filesystem archiver.
pub struct DockerVolumeArchiver<'a> {
    pub runner: &'a dyn DockerRunner,
}
impl Archiver for DockerVolumeArchiver<'_> {
    fn archive(&self, target: &BackupTarget, dest_dir: &str) -> std::io::Result<()> {
        match target.kind {
            TargetKind::Volume => archive_volume(&target.name, dest_dir, self.runner),
            _ => Err(std::io::Error::new(
                std::io::ErrorKind::Unsupported,
                "DockerVolumeArchiver handles Volume targets only",
            )),
        }
    }
}

/// The default, git-excluded location for a stack's pre-change backups.
pub fn default_backup_dest(stack_dir: &std::path::Path) -> std::path::PathBuf {
    stack_dir.join(".yd-backups")
}

/// Build and execute a backup of a whole stack in one call.
#[allow(clippy::too_many_arguments)]
pub fn backup_stack(
    yaml: &str,
    env: &HashMap<String, String>,
    dest_dir: &str,
    confirmed: bool,
    volumes: &dyn VolumeInspector,
    net: &dyn NetworkProbe,
    runner: &dyn CommandRunner,
    archiver: &dyn Archiver,
) -> std::io::Result<BackupManifest> {
    let plan = build_backup_plan(yaml, env, volumes, net);
    execute_plan(&plan, dest_dir, confirmed, runner, archiver)
}

// ---- data restore (the reverse of a bind-data backup) -----------------------

// Bind classification needs no daemon (a host path vs a named token); these
// no-op probes let restore enumerate bind targets without Docker.
struct NoVol;
impl VolumeInspector for NoVol {
    fn inspect(&self, _n: &str) -> Option<VolumeInfo> {
        None
    }
}
struct NoNet;
impl NetworkProbe for NoNet {
    fn fs_type(&self, _p: &str) -> Option<String> {
        None
    }
}

fn copy_tree(src: &Path, dst: &Path) -> std::io::Result<()> {
    if src.is_file() {
        if let Some(p) = dst.parent() {
            std::fs::create_dir_all(p)?;
        }
        std::fs::copy(src, dst)?;
        return Ok(());
    }
    std::fs::create_dir_all(dst)?;
    for entry in std::fs::read_dir(src)? {
        let entry = entry?;
        let to = dst.join(entry.file_name());
        if entry.file_type()?.is_dir() {
            copy_tree(&entry.path(), &to)?;
        } else {
            if let Some(p) = to.parent() {
                std::fs::create_dir_all(p)?;
            }
            std::fs::copy(entry.path(), &to)?;
        }
    }
    Ok(())
}

/// Resolve a bind source against the stack dir (as compose does) for relative paths.
fn resolve_bind(stack_dir: &Path, source: &str) -> std::path::PathBuf {
    let p = Path::new(source);
    if p.is_absolute() || source.starts_with('~') {
        p.to_path_buf()
    } else {
        stack_dir.join(source)
    }
}

/// The outcome of a data-restore attempt.
#[derive(Debug, PartialEq, Eq)]
pub enum RestoreOutcome {
    /// Restored these bind sources (paths) from the backup.
    Restored(Vec<String>),
    /// The backup failed its integrity manifest — refused to restore (N findings).
    VerifyFailed(usize),
    /// No `--yes`: nothing was done.
    Skipped,
}

/// Restore a stack's bind-mounted data from a backup directory. Verifies the
/// backup against its manifest first (refusing on any mismatch), then copies each
/// backed-up bind dir/file back to its source. DB dumps and volume archives are
/// not restored here (docker/engine-specific — a later increment).
pub fn restore_bind_data(
    yaml: &str,
    env: &HashMap<String, String>,
    stack_dir: &Path,
    dest_dir: &Path,
    confirmed: bool,
) -> std::io::Result<RestoreOutcome> {
    if !confirmed {
        return Ok(RestoreOutcome::Skipped);
    }
    // Verify the source backup first, if it carries a manifest.
    if let Ok(text) = std::fs::read_to_string(dest_dir.join("manifest.json")) {
        if let Ok(manifest) = serde_json::from_str::<crate::verify::Manifest>(&text) {
            let findings = crate::verify::verify(dest_dir, &manifest)?;
            if !findings.is_empty() {
                return Ok(RestoreOutcome::VerifyFailed(findings.len()));
            }
        }
    }
    let mounts = parse_mounts(yaml, env).map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, format!("{e:?}")))?;
    let mut restored = Vec::new();
    for t in enumerate_stack_data(&mounts, &NoVol, &NoNet) {
        if t.kind != TargetKind::Bind {
            continue; // volumes / network are not bind-restored here
        }
        let base = Path::new(&t.name)
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|| "root".to_string());
        let backup_path = dest_dir.join(&base);
        if backup_path.exists() {
            copy_tree(&backup_path, &resolve_bind(stack_dir, &t.name))?;
            restored.push(t.name.clone());
        }
    }
    Ok(RestoreOutcome::Restored(restored))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::classify::VolumeInfo;
    use std::cell::RefCell;

    #[test]
    fn restore_bind_data_copies_backed_up_files_back() {
        let stack = tempfile::tempdir().unwrap();
        // current (to be overwritten) bind data
        std::fs::create_dir_all(stack.path().join("html")).unwrap();
        std::fs::write(stack.path().join("html").join("index.html"), b"CURRENT").unwrap();
        // a backup dest holding the good copy
        let dest = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dest.path().join("html")).unwrap();
        std::fs::write(dest.path().join("html").join("index.html"), b"BACKED-UP").unwrap();

        let yaml = "services:\n  web:\n    image: nginx:1.27\n    volumes:\n      - ./html:/usr/share/nginx/html\n";
        let env = HashMap::new();

        // unconfirmed = no-op
        assert_eq!(restore_bind_data(yaml, &env, stack.path(), dest.path(), false).unwrap(), RestoreOutcome::Skipped);

        // confirmed restores the backed-up content over the current
        let out = restore_bind_data(yaml, &env, stack.path(), dest.path(), true).unwrap();
        assert!(matches!(out, RestoreOutcome::Restored(ref v) if v.iter().any(|s| s.contains("html"))), "got {out:?}");
        assert_eq!(std::fs::read_to_string(stack.path().join("html").join("index.html")).unwrap(), "BACKED-UP");
    }

    #[test]
    fn restore_refuses_a_backup_that_fails_verification() {
        let stack = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(stack.path().join("html")).unwrap();
        let dest = tempfile::tempdir().unwrap();
        std::fs::create_dir_all(dest.path().join("html")).unwrap();
        std::fs::write(dest.path().join("html").join("f"), b"data").unwrap();
        // a manifest that expects a file which does NOT match (tampered/missing)
        let mut m = crate::verify::Manifest::default();
        m.entries.insert("html/f".into(), crate::verify::Entry { sha256: "deadbeef".into(), size: 4 });
        std::fs::write(dest.path().join("manifest.json"), serde_json::to_string(&m).unwrap()).unwrap();

        let yaml = "services:\n  web:\n    image: nginx:1.27\n    volumes:\n      - ./html:/x\n";
        let out = restore_bind_data(yaml, &HashMap::new(), stack.path(), dest.path(), true).unwrap();
        assert!(matches!(out, RestoreOutcome::VerifyFailed(_)), "must refuse a bad backup: {out:?}");
    }

    #[derive(Default)]
    struct RecRunner {
        calls: RefCell<Vec<String>>,
    }
    impl CommandRunner for RecRunner {
        fn run_dump(&self, service: &str, command: &str, _dest: &str) -> std::io::Result<()> {
            self.calls.borrow_mut().push(format!("{service}:{command}"));
            Ok(())
        }
    }
    #[derive(Default)]
    struct RecArch {
        calls: RefCell<Vec<String>>,
    }
    impl Archiver for RecArch {
        fn archive(&self, target: &BackupTarget, _dest: &str) -> std::io::Result<()> {
            self.calls.borrow_mut().push(target.name.clone());
            Ok(())
        }
    }

    fn sample_plan() -> BackupPlan {
        BackupPlan {
            dumps: vec![DumpStep {
                service: "db".into(),
                engine: DbEngine::Postgres,
                command: DbEngine::Postgres.dump_command().to_string(),
            }],
            copies: vec![
                BackupTarget {
                    name: "pgdata".into(),
                    kind: TargetKind::Volume,
                },
                BackupTarget {
                    name: "/srv/site".into(),
                    kind: TargetKind::Bind,
                },
            ],
        }
    }

    #[test]
    fn execute_runs_dumps_and_copies_when_confirmed() {
        let r = RecRunner::default();
        let a = RecArch::default();
        let m = execute_plan(&sample_plan(), "/dest", true, &r, &a).unwrap();
        assert_eq!(r.calls.borrow().len(), 1);
        assert!(r.calls.borrow()[0].contains("pg_dump"));
        assert_eq!(a.calls.borrow().as_slice(), ["pgdata", "/srv/site"]);
        assert_eq!(m.dumped, vec!["db".to_string()]);
        assert_eq!(m.copied, vec!["pgdata".to_string(), "/srv/site".to_string()]);
    }

    #[test]
    fn execute_does_nothing_without_confirmation() {
        let r = RecRunner::default();
        let a = RecArch::default();
        let m = execute_plan(&sample_plan(), "/dest", false, &r, &a).unwrap();
        assert!(r.calls.borrow().is_empty() && a.calls.borrow().is_empty());
        assert_eq!(m, BackupManifest::default());
    }

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

    #[derive(Default)]
    struct RecDocker {
        runs: RefCell<Vec<Vec<String>>>,
    }
    impl DockerRunner for RecDocker {
        fn run(&self, argv: &[String]) -> std::io::Result<()> {
            self.runs.borrow_mut().push(argv.to_vec());
            Ok(())
        }
    }

    #[test]
    fn volume_archive_argv_targets_the_volume_and_output() {
        let argv = volume_archive_argv("pgdata", "/bak");
        assert_eq!(argv[0], "run");
        assert!(argv.contains(&"--rm".to_string()));
        assert!(argv.contains(&"pgdata:/src:ro".to_string()));
        assert!(argv.contains(&"/bak:/backup".to_string()));
        assert!(argv.iter().any(|a| a == "/backup/pgdata.tar.gz"));
    }

    #[test]
    fn archive_volume_runs_the_built_argv() {
        let docker = RecDocker::default();
        archive_volume("pgdata", "/bak", &docker).unwrap();
        let runs = docker.runs.borrow();
        assert_eq!(runs.len(), 1);
        assert_eq!(runs[0], volume_archive_argv("pgdata", "/bak"));
    }

    #[test]
    fn docker_volume_archiver_handles_volumes_only() {
        let docker = RecDocker::default();
        let archiver = DockerVolumeArchiver { runner: &docker };
        archiver
            .archive(
                &BackupTarget {
                    name: "pgdata".into(),
                    kind: TargetKind::Volume,
                },
                "/bak",
            )
            .unwrap();
        assert_eq!(docker.runs.borrow().len(), 1);

        let err = archiver
            .archive(
                &BackupTarget {
                    name: "/srv/x".into(),
                    kind: TargetKind::Bind,
                },
                "/bak",
            )
            .unwrap_err();
        assert_eq!(err.kind(), std::io::ErrorKind::Unsupported);
    }

    #[test]
    fn default_backup_dest_is_a_gitignored_subdir() {
        let d = default_backup_dest(std::path::Path::new("/srv/immich"));
        assert!(d.ends_with(".yd-backups"), "got {d:?}");
    }

    #[test]
    fn backup_stack_builds_and_executes() {
        let yaml = "services:\n  db:\n    image: postgres:16\n    volumes:\n      - pgdata:/var/lib/postgresql/data\n  app:\n    image: nginx\n    volumes:\n      - /srv/site:/x\n";
        let r = RecRunner::default();
        let a = RecArch::default();
        let m = backup_stack(yaml, &env(), "/dest", true, &NoVols, &LocalFs, &r, &a).unwrap();
        assert!(r.calls.borrow().iter().any(|c| c.contains("pg_dump")));
        assert!(a.calls.borrow().iter().any(|n| n == "pgdata"));
        assert!(a.calls.borrow().iter().any(|n| n == "/srv/site"));
        assert!(!m.dumped.is_empty());

        // not confirmed -> nothing happens
        let r2 = RecRunner::default();
        let a2 = RecArch::default();
        let m2 = backup_stack(yaml, &env(), "/dest", false, &NoVols, &LocalFs, &r2, &a2).unwrap();
        assert!(r2.calls.borrow().is_empty() && a2.calls.borrow().is_empty());
        assert_eq!(m2, BackupManifest::default());
    }
}
