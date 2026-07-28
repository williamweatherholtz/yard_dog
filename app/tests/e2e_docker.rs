//! End-to-end tests that exercise the persona use-case catalog against a REAL
//! Docker daemon by running the actual `yd` binary. These are `#[ignore]`d by
//! default (they need Docker + network + are slow); run them explicitly:
//!
//!     cargo test --test e2e_docker -- --ignored --test-threads=1
//!
//! Each test maps to a UseCase in .tracking/personas-usecases.sysml. The
//! Docker-touching tests early-return (skip) if no daemon is reachable, so the
//! suite degrades gracefully on a host without Docker.

use assert_cmd::Command;
use std::path::{Path, PathBuf};

/// True if a Docker daemon is reachable.
fn docker_up() -> bool {
    std::process::Command::new("docker")
        .args(["version", "--format", "{{.Server.Version}}"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// Run the `yd` binary.
fn yd() -> Command {
    Command::cargo_bin("yd").unwrap()
}

fn raw_docker(args: &[&str]) -> String {
    let out = std::process::Command::new("docker").args(args).output().unwrap();
    String::from_utf8_lossy(&out.stdout).trim().to_string()
}

/// A throwaway stack directory whose containers are torn down on drop.
struct Stack {
    dir: tempfile::TempDir,
    name: String,
}

impl Stack {
    /// Create a stack dir with a compose file whose single service is uniquely
    /// named (so parallel/leftover runs never collide) and needs no host ports
    /// (the healthcheck runs inside the container).
    fn new(tag: &str, body_with_name: impl FnOnce(&str) -> String) -> Self {
        let dir = tempfile::tempdir().unwrap();
        // A unique, docker-name-safe suffix from the temp dir.
        let suffix: String = dir
            .path()
            .file_name()
            .unwrap()
            .to_string_lossy()
            .chars()
            .filter(|c| c.is_ascii_alphanumeric())
            .collect();
        let name = format!("yde2e-{tag}-{suffix}");
        std::fs::write(dir.path().join("docker-compose.yml"), body_with_name(&name)).unwrap();
        Stack { dir, name }
    }
    fn compose(&self) -> PathBuf {
        self.dir.path().join("docker-compose.yml")
    }
    fn compose_str(&self) -> String {
        self.compose().to_string_lossy().to_string()
    }
    fn path(&self) -> &Path {
        self.dir.path()
    }
    fn health(&self) -> String {
        raw_docker(&["inspect", &self.name, "--format", "{{.State.Health.Status}}"])
    }
    fn running_image(&self) -> String {
        raw_docker(&["inspect", &self.name, "--format", "{{.Config.Image}}"])
    }
}

impl Drop for Stack {
    fn drop(&mut self) {
        // Best-effort teardown; ignore errors (container may never have started).
        let _ = std::process::Command::new("docker")
            .args(["rm", "-f", &self.name])
            .output();
        let _ = std::process::Command::new("docker")
            .args(["network", "rm", &format!("{}_default", self.name)])
            .output();
    }
}

/// nginx compose whose in-container healthcheck hits `port` (80 = healthy, a
/// closed port = never healthy). `image` lets an upgrade change it.
fn nginx_body(name: &str, image: &str, health_port: u16) -> String {
    format!(
        "services:\n  web:\n    image: {image}\n    container_name: {name}\n    restart: unless-stopped\n    mem_limit: 256m\n    healthcheck:\n      test: [\"CMD\", \"wget\", \"-qO-\", \"http://localhost:{health_port}/\"]\n      interval: 2s\n      timeout: 2s\n      retries: 4\n      start_period: 1s\n"
    )
}

macro_rules! require_docker {
    ($what:expr) => {
        if !docker_up() {
            eprintln!("SKIP {}: no Docker daemon reachable", $what);
            return;
        }
    };
}

// ---- ucFirstDeploy ------------------------------------------------------------
#[test]
#[ignore = "requires Docker"]
fn e2e_uc_first_deploy() {
    require_docker!("first_deploy");
    let s = Stack::new("deploy", |n| nginx_body(n, "nginx:1.27-alpine", 80));

    // preflight says READY
    yd().args(["doctor", &s.compose_str()]).assert().success();
    // deploy comes up healthy
    yd().args(["deploy", &s.compose_str(), "--yes"])
        .assert()
        .success()
        .stdout(predicates::str::contains("Deployed"));

    assert_eq!(s.health(), "healthy", "service must be healthy after deploy");
    // the compose was versioned in the stack dir
    assert!(s.path().join(".git").exists(), "stack dir became a versioning repo");
}

// ---- ucAutoRollback -----------------------------------------------------------
#[test]
#[ignore = "requires Docker"]
fn e2e_uc_auto_rollback() {
    require_docker!("auto_rollback");
    let s = Stack::new("rollback", |n| nginx_body(n, "nginx:1.27-alpine", 80));

    // good deploy
    yd().args(["deploy", &s.compose_str(), "--yes"]).assert().success();
    assert_eq!(s.health(), "healthy");

    // break the healthcheck (point it at a closed port) and redeploy
    std::fs::write(s.compose(), nginx_body(&s.name, "nginx:1.27-alpine", 9999)).unwrap();
    yd().args(["deploy", &s.compose_str(), "--yes"])
        .assert()
        .success()
        .stdout(predicates::str::contains("RolledBack"));

    // live container is back on the GOOD (healthy) config and the file restored
    assert_eq!(s.health(), "healthy", "rollback must leave the stack healthy");
    let restored = std::fs::read_to_string(s.compose()).unwrap();
    assert!(restored.contains("localhost:80/"), "compose restored to the good healthcheck");
    assert!(!restored.contains("9999"), "broken config was rolled back");
}

// ---- ucHealthGatedUpgrade -----------------------------------------------------
#[test]
#[ignore = "requires Docker"]
fn e2e_uc_health_gated_upgrade() {
    require_docker!("health_gated_upgrade");
    let s = Stack::new("upgrade", |n| nginx_body(n, "nginx:1.27-alpine", 80));
    yd().args(["deploy", &s.compose_str(), "--yes"]).assert().success();
    assert_eq!(s.running_image(), "nginx:1.27-alpine");

    // accepted upgrade to a newer tag
    yd().args([
        "upgrade", &s.compose_str(), "--repo", &s.path().to_string_lossy(),
        "--service", "web", "--image", "nginx:1.29-alpine", "--yes",
    ])
    .assert()
    .success()
    .stdout(predicates::str::contains("Upgraded"));
    assert_eq!(s.running_image(), "nginx:1.29-alpine", "running the new image");
    assert_eq!(s.health(), "healthy");

    // an upgrade of an unknown service is refused loudly (no silent success)
    yd().args([
        "upgrade", &s.compose_str(), "--repo", &s.path().to_string_lossy(),
        "--service", "does-not-exist", "--image", "nginx:1.29-alpine", "--yes",
    ])
    .assert()
    .failure();
}

// ---- ucDriftDetection ---------------------------------------------------------
#[test]
#[ignore = "requires Docker"]
fn e2e_uc_drift_detection() {
    require_docker!("drift_detection");
    let s = Stack::new("drift", |n| nginx_body(n, "nginx:1.27-alpine", 80));
    yd().args(["deploy", &s.compose_str(), "--yes"]).assert().success();

    // in sync -> no drift
    yd().args(["drift", &s.compose_str()])
        .assert()
        .success()
        .stdout(predicates::str::contains("no drift"));

    // edit the declared image WITHOUT redeploying -> ImageChanged
    std::fs::write(s.compose(), nginx_body(&s.name, "nginx:1.29-alpine", 80)).unwrap();
    yd().args(["drift", &s.compose_str()])
        .assert()
        .success()
        .stdout(predicates::str::contains("ImageChanged"));
}

// ---- ucUpdateCheck ------------------------------------------------------------
#[test]
#[ignore = "requires Docker + network"]
fn e2e_uc_update_check() {
    require_docker!("update_check");
    let s = Stack::new("updates", |n| nginx_body(n, "nginx:1.27-alpine", 80));
    // deploy pulls the image locally
    yd().args(["deploy", &s.compose_str(), "--yes"]).assert().success();
    // a freshly-pulled image reports UpToDate (local digest == current registry digest)
    yd().args(["updates", &s.compose_str()])
        .assert()
        .success()
        .stdout(predicates::str::contains("web:"))
        .stdout(predicates::str::contains("UpToDate"));
}

// ---- ucBrowserControlPlane: boot `yd serve` and deploy over HTTP --------------
#[test]
#[ignore = "requires Docker"]
fn e2e_serve_deploy_over_http() {
    require_docker!("serve_deploy");
    let root = tempfile::tempdir().unwrap();
    let name = "yde2e-serve-web";
    std::fs::create_dir(root.path().join("webapp")).unwrap();
    std::fs::write(
        root.path().join("webapp").join("docker-compose.yml"),
        format!("services:\n  web:\n    image: nginx:1.27-alpine\n    container_name: {name}\n    healthcheck:\n      test: [\"CMD\", \"wget\", \"-qO-\", \"http://localhost/\"]\n      interval: 2s\n      timeout: 2s\n      retries: 4\n"),
    )
    .unwrap();

    let port: u16 = 8791;
    let child = std::process::Command::new(env!("CARGO_BIN_EXE_yd"))
        .args(["serve", "--root", root.path().to_str().unwrap(), "--port", &port.to_string()])
        .spawn()
        .expect("spawn yd serve");
    // kill the server + remove the container on drop, even if an assert fails.
    struct Guard(std::process::Child, String);
    impl Drop for Guard {
        fn drop(&mut self) {
            let _ = self.0.kill();
            let _ = std::process::Command::new("docker").args(["rm", "-f", &self.1]).output();
        }
    }
    let _guard = Guard(child, name.to_string());

    let base = format!("http://127.0.0.1:{port}");
    let agent = ureq::AgentBuilder::new()
        .timeout_read(std::time::Duration::from_secs(180))
        .build();

    // wait for the server to accept connections
    let mut ready = false;
    for _ in 0..40 {
        if agent.get(&format!("{base}/api/stacks")).call().is_ok() {
            ready = true;
            break;
        }
        std::thread::sleep(std::time::Duration::from_millis(250));
    }
    assert!(ready, "yd serve did not come up on {base}");

    // deploy the stack over HTTP (with the anti-CSRF headers the UI sends)
    let resp = agent
        .post(&format!("{base}/api/deploy"))
        .set("Content-Type", "application/json")
        .set("Origin", &base)
        .send_bytes(b"{\"compose\":\"webapp/docker-compose.yml\"}")
        .expect("POST /api/deploy");
    let body = resp.into_string().unwrap();
    assert!(body.contains("\"ok\":true"), "deploy ok over HTTP: {body}");
    assert!(body.contains("Deployed"), "reported Deployed: {body}");

    // the container is actually running healthy
    let health = raw_docker(&["inspect", name, "--format", "{{.State.Health.Status}}"]);
    assert_eq!(health, "healthy", "container healthy after HTTP deploy");

    let _ = std::process::Command::new("docker")
        .args(["compose", "-f", root.path().join("webapp").join("docker-compose.yml").to_str().unwrap(), "down"])
        .output();
}

// ---- ucBackupVerifiedRestore (no Docker needed) -------------------------------
#[test]
#[ignore = "part of the e2e suite"]
fn e2e_uc_backup_verified_restore() {
    let dir = tempfile::tempdir().unwrap();
    std::fs::create_dir(dir.path().join("data")).unwrap();
    std::fs::write(dir.path().join("data").join("photo.jpg"), b"irreplaceable").unwrap();
    let compose = dir.path().join("docker-compose.yml");
    std::fs::write(
        &compose,
        "services:\n  web:\n    image: nginx:1.27-alpine\n    volumes:\n      - ./data:/usr/share/nginx/html\n",
    )
    .unwrap();

    yd().current_dir(dir.path())
        .args(["backup", compose.to_str().unwrap(), "--run", "--dest", "bak"])
        .assert()
        .success();
    // fresh backup verifies clean
    yd().current_dir(dir.path()).args(["verify", "--dest", "bak"]).assert().success();

    // The bind data lands in a collision-free `data-<hash>/` subdir.
    let bak = dir.path().join("bak");
    let sub = std::fs::read_dir(&bak)
        .unwrap()
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .find(|p| p.is_dir() && p.file_name().and_then(|n| n.to_str()).map_or(false, |n| n.starts_with("data-")))
        .expect("bind data captured under bak/data-<hash>/");
    let backed = sub.join("photo.jpg");
    assert!(backed.exists(), "photo captured under {}", sub.display());

    // A real restore round-trip: corrupt the live data, restore, assert recovery.
    std::fs::write(dir.path().join("data").join("photo.jpg"), b"corrupted").unwrap();
    yd().current_dir(dir.path())
        .args(["restore", compose.to_str().unwrap(), "--from", bak.to_str().unwrap(), "--yes"])
        .assert()
        .success();
    assert_eq!(
        std::fs::read(dir.path().join("data").join("photo.jpg")).unwrap(),
        b"irreplaceable",
        "restore must recover the original bind data"
    );

    // Tampering with the BACKUP (not the live data) is detected by verify.
    std::fs::write(&backed, b"tampered-and-longer").unwrap();
    yd().current_dir(dir.path()).args(["verify", "--dest", "bak"]).assert().failure();
}

// ---- ucGuardrailsBlock (no Docker needed) -------------------------------------
#[test]
#[ignore = "part of the e2e suite"]
fn e2e_uc_guardrails_block() {
    let dir = tempfile::tempdir().unwrap();
    // a floating :latest tag is a block-severity finding
    let bad = dir.path().join("bad.yml");
    std::fs::write(&bad, "services:\n  web:\n    image: nginx:latest\n").unwrap();

    yd().args(["doctor", bad.to_str().unwrap()])
        .assert()
        .failure()
        .stdout(predicates::str::contains("NOT READY"));
    // deploy is refused before anything starts
    yd().args(["deploy", bad.to_str().unwrap(), "--yes"]).assert().failure();

    // a *_FILE secret reference is NOT falsely blocked
    let ok = dir.path().join("ok.yml");
    std::fs::write(
        &ok,
        "services:\n  db:\n    image: postgres:16\n    restart: unless-stopped\n    mem_limit: 256m\n    healthcheck:\n      test: [\"CMD\", \"true\"]\n    environment:\n      POSTGRES_PASSWORD_FILE: /run/secrets/db\n",
    )
    .unwrap();
    yd().args(["doctor", ok.to_str().unwrap()])
        .assert()
        .success()
        .stdout(predicates::str::contains("READY"));
}

// ---- ucLifecycle (no Docker needed) -------------------------------------------
#[test]
#[ignore = "part of the e2e suite"]
fn e2e_uc_lifecycle() {
    let root = tempfile::tempdir().unwrap();
    // instantiate a guardrail-clean datastore stack in Draft
    yd().args([
        "new", "--into", &root.path().to_string_lossy(), "--name", "immich",
    ])
    .assert()
    .success();
    let stack = root.path().join("immich");
    let compose = stack.join("docker-compose.yml");

    // scaffold passes the guardrails
    yd().args(["check", compose.to_str().unwrap()]).assert().success();

    // draft -> active -> deprecate -> archive
    for ev in ["activate", "deprecate", "archive"] {
        yd().args(["lifecycle", "--repo", &stack.to_string_lossy(), "--event", ev])
            .assert()
            .success();
    }
    // deploying an archived stack is refused (Blocked, exit 3) before Docker
    yd().args(["deploy", compose.to_str().unwrap(), "--yes"]).assert().failure();

    // restore, then it is no longer lifecycle-blocked (guardrail-clean READY)
    yd().args(["lifecycle", "--repo", &stack.to_string_lossy(), "--event", "restore"])
        .assert()
        .success();
    yd().args(["doctor", compose.to_str().unwrap()])
        .assert()
        .success()
        .stdout(predicates::str::contains("READY"));
}
