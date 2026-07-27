//! `yd` — the Yard Dog CLI. `yd inspect <compose-file>` classifies every mount,
//! checks host-path existence, and prints ranked remediations.

use std::collections::HashMap;

use clap::{Parser, Subcommand};
use yarddog::classify::{NetworkProbe, VolumeInfo, VolumeInspector};
use yarddog::compose::{parse_mounts, parse_service_ids};
use yarddog::report::{build_report, render_text};

#[derive(Parser)]
#[command(name = "yd", version, about = "Yard Dog — path intelligence for Docker/Compose")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Analyse the mounts declared in a docker-compose file.
    Inspect {
        /// Path to the docker-compose file.
        file: String,
    },
    /// Apply remediations for detected path issues (dry-run unless --yes).
    Fix {
        /// Path to the docker-compose file.
        file: String,
        /// Actually apply the fixes. Without this, prints what would be done.
        #[arg(long)]
        yes: bool,
    },
    /// Plan or run an application-consistent backup for a stack.
    Backup {
        /// Path to the docker-compose file.
        file: String,
        /// Preview the plan (no backup runs).
        #[arg(long)]
        plan: bool,
        /// Execute the backup (requires --dest).
        #[arg(long)]
        run: bool,
        /// Destination directory for the backup.
        #[arg(long)]
        dest: Option<String>,
    },
    /// Safely deploy a stack: back up, snapshot, deploy, roll back on failure.
    Deploy {
        /// Path to the docker-compose file.
        file: String,
        /// Actually deploy. Without this it is a no-op preview.
        #[arg(long)]
        yes: bool,
    },
    /// List the compose stacks discovered under a root directory.
    Stacks {
        /// Root directory to scan (each stack is a subdirectory with a compose file).
        #[arg(long)]
        root: String,
    },
    /// Verify a backup's integrity against its recorded manifest.
    Verify {
        /// Backup destination directory (must contain manifest.json).
        #[arg(long)]
        dest: String,
    },
    /// Prune old backup snapshots in a destination, keeping the newest N.
    Prune {
        /// Backup destination directory (snapshots are subdirectories).
        #[arg(long)]
        dest: String,
        /// Number of most-recent snapshots to keep.
        #[arg(long)]
        keep: usize,
    },
}

fn main() {
    let cli = Cli::parse();
    let result = match cli.command {
        Command::Inspect { file } => run_inspect(&file),
        Command::Fix { file, yes } => run_fix(&file, yes),
        Command::Backup {
            file,
            plan,
            run,
            dest,
        } => run_backup(&file, plan, run, dest.as_deref()),
        Command::Deploy { file, yes } => run_deploy(&file, yes),
        Command::Stacks { root } => run_stacks(&root),
        Command::Verify { dest } => run_verify(&dest),
        Command::Prune { dest, keep } => run_prune(&dest, keep),
    };
    if let Err(e) = result {
        eprintln!("yd: {e}");
        std::process::exit(1);
    }
}

type Analysis = (Vec<yarddog::report::MountReport>, HashMap<String, (u32, u32)>);

fn analyze(file: &str) -> Result<Analysis, String> {
    let yaml = std::fs::read_to_string(file).map_err(|e| format!("reading {file}: {e}"))?;
    let env: HashMap<String, String> = std::env::vars().collect();
    let mounts = parse_mounts(&yaml, &env).map_err(|e| format!("parsing {file}: {e:?}"))?;

    let volumes = RealVolumeInspector::new();
    let net = RealNetworkProbe;
    let fs = yarddog::hostfs::RealFs;

    let mut ids = HashMap::new();
    for (svc, (puid, pgid)) in parse_service_ids(&yaml, &env) {
        if let (Some(p), Some(g)) = (puid, pgid) {
            ids.insert(svc, (p, g));
        }
    }

    let reports = build_report(&mounts, &volumes, &net, &fs, &ids);
    Ok((reports, ids))
}

fn run_inspect(file: &str) -> Result<(), String> {
    let (reports, _ids) = analyze(file)?;
    print!("{}", render_text(&reports));
    Ok(())
}

fn run_fix(file: &str, yes: bool) -> Result<(), String> {
    use yarddog::apply::{actions_for, apply_fix, ApplyOutcome, RealFsMut};
    let (reports, ids) = analyze(file)?;
    let fsmut = RealFsMut;
    let mut any = false;
    for r in &reports {
        let expected = ids.get(&r.service).copied();
        for issue in &r.issues {
            for action in actions_for(issue, expected) {
                any = true;
                if yes {
                    match apply_fix(&action, true, &fsmut) {
                        ApplyOutcome::Applied => println!("applied: {action:?}"),
                        ApplyOutcome::Skipped => println!("skipped: {action:?}"),
                        ApplyOutcome::Failed(e) => println!("failed:  {action:?} — {e}"),
                    }
                } else {
                    println!("would apply (dry-run; pass --yes to apply): {action:?}");
                }
            }
        }
    }
    if !any {
        println!("nothing to fix");
    }
    Ok(())
}

fn run_backup(file: &str, plan: bool, run: bool, dest: Option<&str>) -> Result<(), String> {
    let yaml = std::fs::read_to_string(file).map_err(|e| format!("reading {file}: {e}"))?;
    let env: HashMap<String, String> = std::env::vars().collect();
    let volumes = RealVolumeInspector::new();
    let net = RealNetworkProbe;
    let backup_plan = yarddog::backup::build_backup_plan(&yaml, &env, &volumes, &net);

    if run {
        let dest = dest.ok_or_else(|| "`--run` requires `--dest DIR`".to_string())?;
        std::fs::create_dir_all(dest).map_err(|e| format!("creating {dest}: {e}"))?;
        let manifest =
            yarddog::backup::execute_plan(&backup_plan, dest, true, &RealRunner, &RealArchiver)
                .map_err(|e| format!("backup failed: {e}"))?;

        // Record an integrity manifest so the backup can be verified later.
        let integrity = yarddog::verify::build_manifest(std::path::Path::new(dest))
            .map_err(|e| format!("manifesting {dest}: {e}"))?;
        let json = serde_json::to_string_pretty(&integrity)
            .map_err(|e| format!("serializing manifest: {e}"))?;
        std::fs::write(std::path::Path::new(dest).join("manifest.json"), json)
            .map_err(|e| format!("writing manifest: {e}"))?;

        println!(
            "backed up to {dest}: dumps={:?} copies={:?} ({} files manifested)",
            manifest.dumped,
            manifest.copied,
            integrity.entries.len()
        );
    } else if plan {
        print!("{}", yarddog::backup::render_plan(&backup_plan));
    } else {
        println!("Nothing to do — pass --plan to preview or --run --dest DIR to execute.");
    }
    Ok(())
}

fn run_deploy(file: &str, yes: bool) -> Result<(), String> {
    let compose = std::path::Path::new(file);
    let stack_dir = compose.parent().unwrap_or_else(|| std::path::Path::new("."));
    let history = stack_dir.join(".yd-history");
    let outcome = yarddog::deploy::safe_deploy(compose, &history, yes, &RealBackupHook, &RealDeployer)
        .map_err(|e| format!("deploy failed: {e}"))?;
    println!("deploy: {outcome:?}");
    if matches!(outcome, yarddog::deploy::DeployOutcome::BackupFailed(_)) {
        std::process::exit(2);
    }
    Ok(())
}

/// Real deployer: `docker compose up -d` in the stack directory.
struct RealDeployer;
impl yarddog::deploy::Deployer for RealDeployer {
    fn deploy(&self, stack_dir: &std::path::Path) -> std::io::Result<()> {
        let status = std::process::Command::new("docker")
            .args(["compose", "up", "-d"])
            .current_dir(stack_dir)
            .status()?;
        if status.success() {
            Ok(())
        } else {
            Err(std::io::Error::new(
                std::io::ErrorKind::Other,
                "docker compose up failed",
            ))
        }
    }
}

/// Pre-change backup hook. TODO: wire to `yd backup --run` with a dest policy;
/// for now it is a logged no-op so the deploy orchestration is usable.
struct RealBackupHook;
impl yarddog::deploy::BackupHook for RealBackupHook {
    fn pre_change_backup(&self, _stack_dir: &std::path::Path) -> std::io::Result<()> {
        println!("note: pre-change backup is a stub in this build (configure a backup dest to enable)");
        Ok(())
    }
}

fn run_stacks(root: &str) -> Result<(), String> {
    let stacks = yarddog::stacks::discover_stacks(std::path::Path::new(root))
        .map_err(|e| format!("scanning {root}: {e}"))?;
    if stacks.is_empty() {
        println!("no compose stacks found under {root}");
    }
    for s in &stacks {
        println!("{}\t{}", s.name, s.compose_path.display());
    }
    Ok(())
}

fn run_verify(dest: &str) -> Result<(), String> {
    let dir = std::path::Path::new(dest);
    let manifest_path = dir.join("manifest.json");
    let json = std::fs::read_to_string(&manifest_path)
        .map_err(|e| format!("reading {}: {e}", manifest_path.display()))?;
    let manifest: yarddog::verify::Manifest =
        serde_json::from_str(&json).map_err(|e| format!("parsing manifest: {e}"))?;
    let findings = yarddog::verify::verify(dir, &manifest).map_err(|e| format!("verify failed: {e}"))?;
    if findings.is_empty() {
        println!("backup OK: {} file(s) intact", manifest.entries.len());
    } else {
        println!("backup INTEGRITY ISSUES ({}):", findings.len());
        for f in &findings {
            println!("  {f:?}");
        }
        std::process::exit(2);
    }
    Ok(())
}

fn run_prune(dest: &str, keep: usize) -> Result<(), String> {
    let store = yarddog::retention::LocalStore {
        dir: std::path::PathBuf::from(dest),
    };
    let removed = yarddog::retention::apply_retention(&store, keep)
        .map_err(|e| format!("prune failed: {e}"))?;
    println!("pruned {} snapshot(s): {:?}", removed.len(), removed);
    Ok(())
}

/// Real dump runner: streams a container's dump command output to a file.
struct RealRunner;
impl yarddog::backup::CommandRunner for RealRunner {
    fn run_dump(&self, service: &str, command: &str, dest_dir: &str) -> std::io::Result<()> {
        let out_path = std::path::Path::new(dest_dir).join(format!("{service}.dump"));
        let out = std::fs::File::create(&out_path)?;
        let status = std::process::Command::new("docker")
            .args(["compose", "exec", "-T", service, "sh", "-c", command])
            .stdout(out)
            .status()?;
        if !status.success() {
            return Err(std::io::Error::new(
                std::io::ErrorKind::Other,
                format!("dump for service '{service}' failed"),
            ));
        }
        Ok(())
    }
}

/// Real archiver: copies bind/network host paths into the destination. Named
/// volume archiving (needs Docker) lands in a later increment.
struct RealArchiver;
impl yarddog::backup::Archiver for RealArchiver {
    fn archive(&self, target: &yarddog::backup::BackupTarget, dest_dir: &str) -> std::io::Result<()> {
        use yarddog::backup::TargetKind;
        match target.kind {
            TargetKind::Bind | TargetKind::Network => {
                let src = std::path::Path::new(&target.name);
                let base = src
                    .file_name()
                    .map(|s| s.to_string_lossy().to_string())
                    .unwrap_or_else(|| "root".to_string());
                let dst = std::path::Path::new(dest_dir).join(base);
                if src.is_file() {
                    if let Some(parent) = dst.parent() {
                        std::fs::create_dir_all(parent)?;
                    }
                    std::fs::copy(src, &dst)?;
                    Ok(())
                } else {
                    copy_dir_all(src, &dst)
                }
            }
            TargetKind::Volume => {
                println!(
                    "note: skipping named volume '{}' (volume archiving lands in a later increment)",
                    target.name
                );
                Ok(())
            }
        }
    }
}

fn copy_dir_all(src: &std::path::Path, dst: &std::path::Path) -> std::io::Result<()> {
    std::fs::create_dir_all(dst)?;
    for entry in std::fs::read_dir(src)? {
        let entry = entry?;
        let to = dst.join(entry.file_name());
        if entry.file_type()?.is_dir() {
            copy_dir_all(&entry.path(), &to)?;
        } else {
            std::fs::copy(entry.path(), to)?;
        }
    }
    Ok(())
}

/// Real named-volume inspector, best-effort over the local Docker daemon. Any
/// connection or lookup error resolves to `None` (treated as a plain volume),
/// so the tool stays useful without Docker.
struct RealVolumeInspector {
    rt: Option<tokio::runtime::Runtime>,
    docker: Option<bollard::Docker>,
}

impl RealVolumeInspector {
    fn new() -> Self {
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .ok();
        let docker = bollard::Docker::connect_with_local_defaults().ok();
        Self { rt, docker }
    }
}

impl VolumeInspector for RealVolumeInspector {
    fn inspect(&self, name: &str) -> Option<VolumeInfo> {
        let rt = self.rt.as_ref()?;
        let docker = self.docker.as_ref()?;
        let volume = rt.block_on(docker.inspect_volume(name)).ok()?;
        Some(VolumeInfo {
            driver: volume.driver,
            options: volume.options,
        })
    }
}

/// Real network probe: resolves a host path's filesystem type from the Linux
/// mount table. On non-Linux hosts it returns `None` (no network detection).
struct RealNetworkProbe;

impl NetworkProbe for RealNetworkProbe {
    fn fs_type(&self, path: &str) -> Option<String> {
        #[cfg(target_os = "linux")]
        {
            let mounts = std::fs::read_to_string("/proc/mounts").ok()?;
            yarddog::mounttable::fstype_from_table(&mounts, path)
        }
        #[cfg(not(target_os = "linux"))]
        {
            let _ = path;
            None
        }
    }
}
