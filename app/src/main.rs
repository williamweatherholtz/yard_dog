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
    /// Run preventative policy guardrails over a compose file.
    Check {
        /// Path to the docker-compose file.
        file: String,
    },
    /// Show image-update status + the suggested action per service.
    Updates {
        /// Path to the docker-compose file.
        file: String,
    },
    /// Report drift between the declared compose and the running stack.
    Drift {
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
    /// Safely upgrade a service's image: back up, snapshot, deploy, regress-or-accept.
    Upgrade {
        /// Path to the docker-compose file.
        file: String,
        /// Git versioning repo (usually the stacks root).
        #[arg(long)]
        repo: String,
        /// Service to upgrade.
        #[arg(long)]
        service: String,
        /// Target image (e.g. nginx:1.29).
        #[arg(long)]
        image: String,
        /// Proceed and auto-accept on a passing healthcheck. Without this it is a no-op.
        #[arg(long)]
        yes: bool,
    },
    /// List the compose stacks discovered under a root directory.
    Stacks {
        /// Root directory to scan (each stack is a subdirectory with a compose file).
        #[arg(long)]
        root: String,
    },
    /// Import an existing compose stack into a managed stacks directory.
    Import {
        /// Path to the existing compose file to import.
        file: String,
        /// Managed stacks directory to import into.
        #[arg(long)]
        into: String,
        /// Stack name (defaults to the compose file's parent directory name).
        #[arg(long)]
        name: Option<String>,
    },
    /// Send a notification through the default (stdout) channel.
    Notify {
        /// Message to send.
        #[arg(long)]
        message: String,
    },
    /// Verify a backup's integrity against its recorded manifest.
    Verify {
        /// Backup destination directory (must contain manifest.json).
        #[arg(long)]
        dest: String,
    },
    /// Mirror a backup directory to a destination (local target for now).
    Push {
        /// Source backup directory.
        #[arg(long)]
        from: String,
        /// Destination directory (stand-in remote / mount).
        #[arg(long)]
        to: String,
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
    /// Git-backed config versioning for a stacks repo.
    Version {
        #[command(subcommand)]
        action: VersionAction,
    },
    /// Pin services to hold their updates.
    Pin {
        #[command(subcommand)]
        action: PinAction,
    },
    /// Connect and sync the config monorepo with a git remote (auth = your git).
    Git {
        #[command(subcommand)]
        action: GitAction,
    },
    /// Act across every stack under a root (status / check / backup).
    Fleet {
        #[command(subcommand)]
        action: FleetAction,
    },
    /// Check whether a newer Yard Dog release is available (or apply it).
    SelfUpdate {
        /// Download, verify (SHA256), and install the latest release in place.
        #[arg(long)]
        apply: bool,
    },
    /// Restore a stack's bind-mounted DATA from a backup (verify-gated; --yes to apply).
    Restore {
        /// Path to the docker-compose file.
        file: String,
        /// The backup directory to restore from (a recovery point).
        #[arg(long)]
        from: String,
        /// Actually overwrite current data (without this it is a dry run).
        #[arg(long)]
        yes: bool,
    },
    /// Serve the loopback-only browser control plane over the stacks under a root.
    Serve {
        /// Directory whose stacks the UI manages (defaults to the current dir).
        #[arg(long, default_value = ".")]
        root: String,
        /// TCP port for the control plane.
        #[arg(long, default_value_t = 8770)]
        port: u16,
        /// Bind address. Default 127.0.0.1 (loopback). Use 0.0.0.0 ONLY inside a
        /// container whose port is published to the host's loopback — the Host
        /// allowlist still refuses any non-loopback Host, so this never opens LAN.
        #[arg(long, default_value = "127.0.0.1")]
        host: String,
    },
    /// Preflight a stack: one go/no-go verdict from guardrails + lifecycle.
    Doctor {
        /// Path to the docker-compose file.
        file: String,
    },
    /// Instantiate a new guardrail-clean starter stack.
    New {
        #[arg(long)]
        into: String,
        #[arg(long)]
        name: String,
        /// Service name inside the compose (defaults to the stack name).
        #[arg(long)]
        service: Option<String>,
    },
    /// Show or transition a stack's lifecycle state (draft/active/deprecated/archived).
    Lifecycle {
        #[arg(long)]
        repo: String,
        /// activate | deprecate | archive | restore (omit to just show the current state).
        #[arg(long)]
        event: Option<String>,
    },
}

#[derive(Subcommand)]
enum GitAction {
    /// Show or set the config repo's git remote.
    Remote {
        #[arg(long)]
        repo: String,
        /// Set the remote URL (omit to just show it).
        #[arg(long)]
        url: Option<String>,
    },
    /// Push the config repo to its remote.
    Push {
        #[arg(long)]
        repo: String,
    },
    /// Fast-forward pull the config repo from its remote.
    Pull {
        #[arg(long)]
        repo: String,
    },
    /// Show remote + ahead/behind status.
    Status {
        #[arg(long)]
        repo: String,
    },
}

#[derive(Subcommand)]
enum FleetAction {
    /// Lifecycle + guardrail-issue summary for every stack.
    Status {
        #[arg(long)]
        root: String,
    },
    /// Preflight (READY/NOT READY) every stack.
    Check {
        #[arg(long)]
        root: String,
    },
    /// Back up every stack to its .yd-backups.
    Backup {
        #[arg(long)]
        root: String,
    },
}

#[derive(Subcommand)]
enum PinAction {
    /// Pin a service (hold its updates).
    Add {
        #[arg(long)]
        repo: String,
        #[arg(long)]
        service: String,
    },
    /// List pinned services.
    List {
        #[arg(long)]
        repo: String,
    },
}

#[derive(Subcommand)]
enum VersionAction {
    /// Initialise the versioning repo (opinionated .gitignore + attributes).
    Init {
        #[arg(long)]
        repo: String,
    },
    /// Commit the current config as a snapshot.
    Snapshot {
        #[arg(long)]
        repo: String,
        #[arg(long, short = 'm')]
        message: String,
    },
    /// List version history (newest first).
    History {
        #[arg(long)]
        repo: String,
    },
    /// Restore a prior version by sha (as a new commit).
    Restore {
        #[arg(long)]
        repo: String,
        #[arg(long)]
        sha: String,
    },
}

fn main() {
    let cli = Cli::parse();
    let result = match cli.command {
        Command::Inspect { file } => run_inspect(&file),
        Command::Check { file } => run_check(&file),
        Command::Updates { file } => run_updates(&file),
        Command::Drift { file } => run_drift(&file),
        Command::Fix { file, yes } => run_fix(&file, yes),
        Command::Backup {
            file,
            plan,
            run,
            dest,
        } => run_backup(&file, plan, run, dest.as_deref()),
        Command::Deploy { file, yes } => run_deploy(&file, yes),
        Command::Upgrade {
            file,
            repo,
            service,
            image,
            yes,
        } => run_upgrade(&file, &repo, &service, &image, yes),
        Command::Stacks { root } => run_stacks(&root),
        Command::Import { file, into, name } => run_import(&file, &into, name.as_deref()),
        Command::Notify { message } => run_notify(&message),
        Command::Verify { dest } => run_verify(&dest),
        Command::Push { from, to } => run_push(&from, &to),
        Command::Prune { dest, keep } => run_prune(&dest, keep),
        Command::Version { action } => run_version(action),
        Command::Pin { action } => run_pin(action),
        Command::Git { action } => run_git(action),
        Command::Fleet { action } => run_fleet(action),
        Command::SelfUpdate { apply } => run_self_update(apply),
        Command::Restore { file, from, yes } => run_restore(&file, &from, yes),
        Command::Serve { root, port, host } => {
            yarddog::web::serve(&host, port, std::path::Path::new(&root)).map_err(|e| e.to_string())
        }
        Command::Doctor { file } => run_doctor(&file),
        Command::New { into, name, service } => run_new(&into, &name, service.as_deref()),
        Command::Lifecycle { repo, event } => run_lifecycle(&repo, event.as_deref()),
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


fn run_updates(file: &str) -> Result<(), String> {
    let yaml = std::fs::read_to_string(file).map_err(|e| format!("reading {file}: {e}"))?;
    let services = yarddog::workload::parse_services(&yaml);
    let mut running = std::collections::HashMap::new();
    for s in &services {
        if let Some(img) = &s.image {
            if let Some(d) = yarddog::updates::local_image_digest(img) {
                running.insert(s.name.clone(), d);
            }
        }
    }
    let plan = yarddog::updates::build_update_plan(&services, &running, &yarddog::registry::HttpRegistryClient);
    for item in &plan {
        println!(
            "{}: status={:?} action={}",
            item.service,
            item.status,
            item.action.as_str()
        );
    }
    Ok(())
}

fn run_drift(file: &str) -> Result<(), String> {
    // Real running-state via `docker compose ps`; None only when docker is down.
    struct DockerRunning {
        compose: std::path::PathBuf,
    }
    impl yarddog::drift::RunningState for DockerRunning {
        fn running_images(&self) -> Option<std::collections::HashMap<String, String>> {
            yarddog::drift::running_images_via_docker(&self.compose)
        }
    }
    let running = DockerRunning { compose: std::path::PathBuf::from(file) };
    let yaml = std::fs::read_to_string(file).map_err(|e| format!("reading {file}: {e}"))?;
    match yarddog::drift::drift_report(&yaml, &running) {
        Some(items) if items.is_empty() => println!("no drift"),
        Some(items) => {
            for i in &items {
                println!("{}: {:?}", i.service, i.kind);
            }
        }
        None => {
            println!("running state unavailable — drift check needs docker (planned). Declared services:");
            for (svc, img) in yarddog::compose::parse_service_images(&yaml) {
                println!("  {svc}: {img}");
            }
        }
    }
    Ok(())
}

fn run_check(file: &str) -> Result<(), String> {
    let yaml = std::fs::read_to_string(file).map_err(|e| format!("reading {file}: {e}"))?;
    let findings = yarddog::guardrails::run_guardrails(&yaml);
    if findings.is_empty() {
        println!("guardrails: OK (no findings)");
    }
    for f in &findings {
        println!("  [{:?}] {} ({}): {}", f.severity, f.rule, f.service, f.message);
    }
    if !yarddog::guardrails::verdict(&findings) {
        eprintln!("guardrails: BLOCKED by the findings above");
        std::process::exit(2);
    }
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
    // Resolve the compose's relative bind sources and a relative --dest against
    // the stack directory (as docker compose does), not the process CWD — so
    // backup works regardless of where `yd` is invoked from (e.g. via the UI).
    let compose = std::fs::canonicalize(file).unwrap_or_else(|_| std::path::PathBuf::from(file));
    let yaml = std::fs::read_to_string(&compose).map_err(|e| format!("reading {file}: {e}"))?;
    if let Some(stack_dir) = compose.parent() {
        std::env::set_current_dir(stack_dir).map_err(|e| format!("entering stack dir: {e}"))?;
    }
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

/// Print guardrail findings so the operator is told, before anything is applied,
/// what the FSM will warn or block on — e.g. a service with no healthcheck (which
/// also makes the health-gate a no-op), a floating tag, or a plaintext secret.
fn announce_guardrails(compose: &std::path::Path) {
    let Ok(yaml) = std::fs::read_to_string(compose) else {
        return;
    };
    for f in yarddog::guardrails::run_guardrails(&yaml) {
        let tag = match f.severity {
            yarddog::guardrails::Severity::Block => "BLOCK",
            yarddog::guardrails::Severity::Warn => "warn",
        };
        eprintln!("guardrail [{tag}] {}: {} ({})", f.service, f.message, f.rule);
    }
}

fn run_deploy(file: &str, yes: bool) -> Result<(), String> {
    let compose = std::path::Path::new(file);
    let stack_dir = compose.parent().unwrap_or_else(|| std::path::Path::new("."));
    // Version at the (mono)repo root: use the enclosing git repo if there is one
    // (e.g. the `yd serve --root` monorepo), else make the stack dir its own repo.
    // gitver's ignore excludes data/secrets/.yd-backups; snapshots are path-scoped
    // to the stack so a rollback restores only it.
    let root = yarddog::gitver::repo_root(stack_dir).unwrap_or_else(|| stack_dir.to_path_buf());
    yarddog::gitver::ensure_repo(&root).map_err(|e| format!("cannot init versioning repo: {e}"))?;
    announce_guardrails(compose);
    let outcome = yarddog::deploy::safe_deploy(compose, &root, yes, &RealBackupHook, &RealDeployer)
        .map_err(|e| format!("deploy failed: {e}"))?;
    println!("deploy: {outcome:?}");
    if matches!(outcome, yarddog::deploy::DeployOutcome::BackupFailed(_)) {
        std::process::exit(2);
    }
    if matches!(outcome, yarddog::deploy::DeployOutcome::Blocked(_)) {
        std::process::exit(3);
    }
    if let yarddog::deploy::DeployOutcome::RollbackFailed(why) = &outcome {
        eprintln!("CRITICAL: deploy failed and rollback did not recover — stack needs attention: {why}");
        std::process::exit(4);
    }
    Ok(())
}

fn run_upgrade(
    file: &str,
    repo: &str,
    service: &str,
    image: &str,
    yes: bool,
) -> Result<(), String> {
    // --yes proceeds and auto-accepts on a passing healthcheck. Version at the
    // enclosing (mono)repo root if one exists, else at the given --repo dir.
    let repo_path = std::path::Path::new(repo);
    let root = yarddog::gitver::repo_root(repo_path).unwrap_or_else(|| repo_path.to_path_buf());
    yarddog::gitver::ensure_repo(&root)
        .map_err(|e| format!("cannot init versioning repo: {e}"))?;
    announce_guardrails(std::path::Path::new(file));
    let outcome = yarddog::upgrade::safe_upgrade(
        std::path::Path::new(file),
        &root,
        service,
        image,
        yes,
        yes,
        &RealBackupHook,
        &RealDeployer,
    )
    .map_err(|e| format!("upgrade failed: {e}"))?;
    println!("upgrade: {outcome:?}");
    if matches!(outcome, yarddog::upgrade::UpgradeOutcome::Blocked(_)) {
        std::process::exit(3);
    }
    if let yarddog::upgrade::UpgradeOutcome::RegressFailed(why) = &outcome {
        eprintln!("CRITICAL: upgrade failed and rollback did not recover — stack needs attention: {why}");
        std::process::exit(4);
    }
    if let yarddog::upgrade::UpgradeOutcome::NoSuchService(why) = &outcome {
        eprintln!("upgrade not applied: {why}");
        std::process::exit(3);
    }
    Ok(())
}

/// Real deployer: `docker compose up -d --wait` in the stack directory. `--wait`
/// blocks until containers are HEALTHY (or the wait times out), so a non-zero
/// exit — the health-gate failing — is surfaced as `Err` and drives a regress.
struct RealDeployer;
impl yarddog::deploy::Deployer for RealDeployer {
    fn deploy(&self, stack_dir: &std::path::Path) -> std::io::Result<()> {
        let status = std::process::Command::new("docker")
            .args(yarddog::flow::compose_up_args())
            .current_dir(stack_dir)
            .status()?;
        if status.success() {
            Ok(())
        } else {
            Err(std::io::Error::new(
                std::io::ErrorKind::Other,
                "docker compose up --wait failed (unhealthy or timed out)",
            ))
        }
    }
}

/// Pre-change backup hook. TODO: wire to `yd backup --run` with a dest policy;
/// for now it is a logged no-op so the deploy orchestration is usable.
struct RealBackupHook;
impl yarddog::deploy::BackupHook for RealBackupHook {
    fn pre_change_backup(&self, stack_dir: &std::path::Path) -> std::io::Result<()> {
        let Some(compose) = yarddog::stacks::find_compose(stack_dir) else {
            return Ok(()); // no compose here — nothing to back up
        };
        let yaml = std::fs::read_to_string(&compose)?;
        let env: HashMap<String, String> = std::env::vars().collect();
        let dest = yarddog::backup::default_backup_dest(stack_dir);
        std::fs::create_dir_all(&dest)?;
        let dest_str = dest.to_string_lossy().to_string();
        let volumes = RealVolumeInspector::new();
        let net = RealNetworkProbe;
        let manifest = yarddog::backup::backup_stack(
            &yaml, &env, &dest_str, true, &volumes, &net, &RealRunner, &RealArchiver,
        )?;
        println!(
            "pre-change backup -> {dest_str}: dumps={:?} copies={:?}",
            manifest.dumped, manifest.copied
        );
        Ok(())
    }
}

fn run_import(file: &str, into: &str, name: Option<&str>) -> Result<(), String> {
    let stack = yarddog::stacks::import_stack(
        std::path::Path::new(file),
        std::path::Path::new(into),
        name,
    )
    .map_err(|e| format!("import failed: {e}"))?;
    println!(
        "imported stack '{}' -> {}",
        stack.name,
        stack.compose_path.display()
    );
    Ok(())
}

fn run_notify(message: &str) -> Result<(), String> {
    use yarddog::notify::{Notifier, StdoutNotifier};
    StdoutNotifier
        .send(message)
        .map_err(|e| format!("notify failed: {e}"))
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

fn run_push(from: &str, to: &str) -> Result<(), String> {
    let n = yarddog::transport::sync_dir(
        std::path::Path::new(from),
        &yarddog::transport::LocalTransport {
            target: std::path::PathBuf::from(to),
        },
    )
    .map_err(|e| format!("push failed: {e}"))?;
    println!("pushed {n} file(s) to {to}");
    Ok(())
}

/// The public repo self-update pulls releases from.
const RELEASE_REPO: &str = "williamweatherholtz/yard_dog";

fn run_self_update(apply: bool) -> Result<(), String> {
    use yarddog::selfupdate::{check, perform_update, ApplyOutcome, GithubReleases, SelfUpdateStatus};
    let current = env!("CARGO_PKG_VERSION");
    let gh = GithubReleases { repo: RELEASE_REPO.to_string() };

    if !apply {
        match check(current, &gh) {
            SelfUpdateStatus::UpToDate => println!("yd {current}: up to date"),
            SelfUpdateStatus::UpdateAvailable(v) => {
                println!("yd {current}: update available -> {v}  (run `yd self-update --apply`)")
            }
            SelfUpdateStatus::Unknown => println!("yd {current}: could not reach {RELEASE_REPO} releases"),
        }
        return Ok(());
    }

    let exe = std::env::current_exe().map_err(|e| format!("cannot locate current exe: {e}"))?;
    match perform_update(&gh, current, &exe).map_err(|e| format!("update failed: {e}"))? {
        ApplyOutcome::UpToDate => println!("yd {current}: already up to date"),
        ApplyOutcome::Updated { from, to, backup } => {
            println!("updated yd {from} -> {to}  (previous binary kept at {})", backup.display());
        }
        ApplyOutcome::NoAsset(a) => return Err(format!("no release asset '{a}' for this platform")),
        ApplyOutcome::ChecksumMismatch => return Err("SHA256 verification failed — refusing to install".into()),
        ApplyOutcome::Unreachable => return Err(format!("could not reach {RELEASE_REPO} releases")),
    }
    Ok(())
}

fn run_doctor(file: &str) -> Result<(), String> {
    let compose = std::path::Path::new(file);
    let yaml = std::fs::read_to_string(compose).map_err(|e| format!("cannot read {file}: {e}"))?;
    let stack_dir = compose.parent().unwrap_or_else(|| std::path::Path::new("."));
    let state = yarddog::lifecycle::read_state(stack_dir);
    let p = yarddog::preflight::assess(&yaml, state);
    println!(
        "preflight: {} — lifecycle={}, {} block(s), {} warning(s)",
        if p.ready { "READY" } else { "NOT READY" },
        p.lifecycle.as_str(),
        p.blocks,
        p.warns
    );
    // Show the operator the actual findings so the verdict is actionable.
    announce_guardrails(compose);
    if !p.ready {
        std::process::exit(3);
    }
    Ok(())
}

fn run_new(into: &str, name: &str, service: Option<&str>) -> Result<(), String> {
    let service = service.unwrap_or(name);
    let compose = yarddog::instantiate::instantiate(std::path::Path::new(into), name, service)
        .map_err(|e| format!("instantiate failed: {e}"))?;
    println!("created {} (lifecycle=draft)", compose.display());
    Ok(())
}

fn run_lifecycle(repo: &str, event: Option<&str>) -> Result<(), String> {
    use yarddog::lifecycle::{read_state, transition, LifecycleEvent};
    let dir = std::path::Path::new(repo);
    let state = match event {
        None => read_state(dir),
        Some(e) => {
            let ev = LifecycleEvent::parse(e)
                .ok_or_else(|| format!("unknown event '{e}' (activate|deprecate|archive|restore)"))?;
            transition(dir, ev).map_err(|err| format!("lifecycle transition rejected: {err}"))?
        }
    };
    println!("lifecycle: {}", state.as_str());
    Ok(())
}

fn run_restore(file: &str, from: &str, yes: bool) -> Result<(), String> {
    let compose = std::path::Path::new(file);
    let stack_dir = compose.parent().unwrap_or_else(|| std::path::Path::new("."));
    let yaml = std::fs::read_to_string(compose).map_err(|e| format!("reading {file}: {e}"))?;
    let env: HashMap<String, String> = std::env::vars().collect();
    let from_p = std::path::Path::new(from);
    let dest = if from_p.is_absolute() { from_p.to_path_buf() } else { stack_dir.join(from) };
    match yarddog::backup::restore_bind_data(&yaml, &env, stack_dir, &dest, yes)
        .map_err(|e| format!("restore failed: {e}"))?
    {
        yarddog::backup::RestoreOutcome::Restored(v) => {
            println!("restored {} bind path(s): {:?}", v.len(), v);
        }
        yarddog::backup::RestoreOutcome::VerifyFailed(n) => {
            eprintln!("refused: backup failed verification ({n} issue(s)) — not restoring");
            std::process::exit(3);
        }
        yarddog::backup::RestoreOutcome::Skipped => {
            println!("dry run — pass --yes to restore (this OVERWRITES current data)");
        }
    }
    Ok(())
}

fn run_fleet(action: FleetAction) -> Result<(), String> {
    let scan = |root: &str| yarddog::stacks::discover_stacks(std::path::Path::new(root)).unwrap_or_default();
    match action {
        FleetAction::Status { root } => {
            for s in scan(&root) {
                let dir = s.compose_path.parent().unwrap_or_else(|| std::path::Path::new("."));
                let state = yarddog::lifecycle::read_state(dir);
                let yaml = std::fs::read_to_string(&s.compose_path).unwrap_or_default();
                let f = yarddog::guardrails::run_guardrails(&yaml);
                let blocks = f.iter().filter(|x| x.severity == yarddog::guardrails::Severity::Block).count();
                let warns = f.iter().filter(|x| x.severity == yarddog::guardrails::Severity::Warn).count();
                println!("{:<20} {:<11} {} block(s), {} warning(s)", s.name, state.as_str(), blocks, warns);
            }
        }
        FleetAction::Check { root } => {
            for s in scan(&root) {
                let dir = s.compose_path.parent().unwrap_or_else(|| std::path::Path::new("."));
                let yaml = std::fs::read_to_string(&s.compose_path).unwrap_or_default();
                let p = yarddog::preflight::assess(&yaml, yarddog::lifecycle::read_state(dir));
                println!("{:<20} {}", s.name, if p.ready { "READY" } else { "NOT READY" });
            }
        }
        FleetAction::Backup { root } => {
            for s in scan(&root) {
                print!("{}: ", s.name);
                match run_backup(&s.compose_path.to_string_lossy(), false, true, Some(".yd-backups")) {
                    Ok(()) => {}
                    Err(e) => println!("failed — {e}"),
                }
            }
        }
    }
    Ok(())
}

fn run_git(action: GitAction) -> Result<(), String> {
    use yarddog::gitver;
    let root_of = |repo: &str| {
        gitver::repo_root(std::path::Path::new(repo)).unwrap_or_else(|| std::path::PathBuf::from(repo))
    };
    match action {
        GitAction::Remote { repo, url } => {
            let root = root_of(&repo);
            match url {
                Some(u) => {
                    gitver::set_remote(&root, &u).map_err(|e| e.to_string())?;
                    println!("remote set: {u}");
                }
                None => match gitver::remote_url(&root) {
                    Some(u) => println!("{u}"),
                    None => println!("no remote configured"),
                },
            }
        }
        GitAction::Push { repo } => {
            let out = gitver::push(&root_of(&repo)).map_err(|e| format!("push failed: {e}"))?;
            print!("{out}");
            println!("pushed");
        }
        GitAction::Pull { repo } => {
            let out = gitver::pull(&root_of(&repo)).map_err(|e| format!("pull failed: {e}"))?;
            print!("{out}");
            println!("pulled");
        }
        GitAction::Status { repo } => {
            let root = root_of(&repo);
            match gitver::remote_url(&root) {
                Some(u) => {
                    print!("remote: {u}");
                    if let Some((a, b)) = gitver::ahead_behind(&root) {
                        print!("  ({a} ahead, {b} behind)");
                    }
                    println!();
                }
                None => println!("no remote configured"),
            }
        }
    }
    Ok(())
}

fn run_pin(action: PinAction) -> Result<(), String> {
    use yarddog::updates::{read_pins, write_pin};
    let p = std::path::Path::new;
    match action {
        PinAction::Add { repo, service } => {
            write_pin(p(&repo), &service).map_err(|e| format!("pin failed: {e}"))?;
            println!("pinned {service}");
        }
        PinAction::List { repo } => {
            for s in read_pins(p(&repo)) {
                println!("{s}");
            }
        }
    }
    Ok(())
}

fn run_version(action: VersionAction) -> Result<(), String> {
    use yarddog::gitver;
    let p = std::path::Path::new;
    match action {
        VersionAction::Init { repo } => {
            gitver::init(p(&repo)).map_err(|e| format!("init failed: {e}"))?;
            println!("initialised versioning at {repo}");
        }
        VersionAction::Snapshot { repo, message } => {
            let sha = gitver::snapshot(p(&repo), &message).map_err(|e| format!("snapshot failed: {e}"))?;
            println!("snapshot {}", &sha[..sha.len().min(12)]);
        }
        VersionAction::History { repo } => {
            for (sha, msg) in gitver::history(p(&repo)).map_err(|e| format!("history failed: {e}"))? {
                println!("{}  {}", &sha[..sha.len().min(12)], msg);
            }
        }
        VersionAction::Restore { repo, sha } => {
            let new = gitver::restore(p(&repo), &sha).map_err(|e| format!("restore failed: {e}"))?;
            println!("restored as {}", &new[..new.len().min(12)]);
        }
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
                yarddog::backup::archive_volume(&target.name, dest_dir, &RealDockerRunner)
            }
        }
    }
}

/// Real docker runner: invokes `docker <argv>`.
struct RealDockerRunner;
impl yarddog::backup::DockerRunner for RealDockerRunner {
    fn run(&self, argv: &[String]) -> std::io::Result<()> {
        let status = std::process::Command::new("docker").args(argv).status()?;
        if status.success() {
            Ok(())
        } else {
            Err(std::io::Error::new(
                std::io::ErrorKind::Other,
                "docker command failed",
            ))
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
