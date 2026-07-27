//! End-to-end test for the `yd inspect <compose>` command.
//!
//! Uses only a named volume, a POSIX bind path that does not exist on any dev
//! host, and an anonymous volume — so the assertions are deterministic without
//! a running Docker daemon or a pre-seeded host path.

use assert_cmd::Command;
use std::io::Write;

#[test]
fn inspect_reports_types_existence_and_remediation() {
    let dir = tempfile::tempdir().unwrap();
    let compose = dir.path().join("docker-compose.yml");
    let mut f = std::fs::File::create(&compose).unwrap();
    write!(
        f,
        "{}",
        r#"services:
  app:
    volumes:
      - data:/var/lib/data
      - /srv/yd-missing-e2e-xyz:/mnt/x
      - /cache
"#
    )
    .unwrap();

    let assert = Command::cargo_bin("yd")
        .unwrap()
        .arg("inspect")
        .arg(compose.to_str().unwrap())
        .assert()
        .success();
    let stdout = String::from_utf8_lossy(&assert.get_output().stdout).to_string();

    assert!(stdout.contains("named-volume"), "stdout was:\n{stdout}");
    assert!(stdout.contains("host-bind"), "stdout was:\n{stdout}");
    assert!(stdout.contains("anonymous"), "stdout was:\n{stdout}");
    assert!(
        stdout.to_lowercase().contains("missing"),
        "missing bind should be flagged; stdout was:\n{stdout}"
    );
    assert!(
        stdout.to_lowercase().contains("create"),
        "a missing path should carry a create remediation; stdout was:\n{stdout}"
    );
}

#[test]
fn fix_applies_missing_dir_only_when_confirmed() {
    let dir = tempfile::tempdir().unwrap();
    let compose = dir.path().join("docker-compose.yml");
    std::fs::write(
        &compose,
        "services:\n  app:\n    volumes:\n      - ./newdir:/data\n",
    )
    .unwrap();

    // dry run (no --yes): the directory must NOT be created
    Command::cargo_bin("yd")
        .unwrap()
        .current_dir(dir.path())
        .arg("fix")
        .arg(compose.to_str().unwrap())
        .assert()
        .success();
    assert!(
        !dir.path().join("newdir").exists(),
        "a dry-run fix must not create the host path"
    );

    // confirmed (--yes): the directory is created
    Command::cargo_bin("yd")
        .unwrap()
        .current_dir(dir.path())
        .arg("fix")
        .arg(compose.to_str().unwrap())
        .arg("--yes")
        .assert()
        .success();
    assert!(
        dir.path().join("newdir").exists(),
        "a confirmed fix must create the missing host path"
    );
}

#[test]
fn backup_plan_lists_dumps_and_targets() {
    let dir = tempfile::tempdir().unwrap();
    let compose = dir.path().join("docker-compose.yml");
    std::fs::write(
        &compose,
        "services:\n  db:\n    image: postgres:16\n    volumes:\n      - pgdata:/var/lib/postgresql/data\n  app:\n    image: nginx\n    volumes:\n      - /srv/site:/usr/share/nginx/html\n",
    )
    .unwrap();

    let assert = Command::cargo_bin("yd")
        .unwrap()
        .arg("backup")
        .arg(compose.to_str().unwrap())
        .arg("--plan")
        .assert()
        .success();
    let out = String::from_utf8_lossy(&assert.get_output().stdout).to_string();

    assert!(out.contains("pg_dump"), "plan should include the pg dump; got:\n{out}");
    assert!(out.contains("pgdata"), "plan should list the named volume; got:\n{out}");
    assert!(out.contains("/srv/site"), "plan should list the bind; got:\n{out}");
}

#[test]
fn backup_run_copies_bind_data() {
    let dir = tempfile::tempdir().unwrap();
    std::fs::create_dir(dir.path().join("data")).unwrap();
    std::fs::write(dir.path().join("data").join("file.txt"), b"hello").unwrap();
    let compose = dir.path().join("docker-compose.yml");
    std::fs::write(
        &compose,
        "services:\n  app:\n    image: nginx\n    volumes:\n      - ./data:/usr/share/nginx/html\n",
    )
    .unwrap();

    // plan only: nothing copied
    Command::cargo_bin("yd")
        .unwrap()
        .current_dir(dir.path())
        .arg("backup")
        .arg(compose.to_str().unwrap())
        .arg("--plan")
        .assert()
        .success();
    assert!(!dir.path().join("bak").join("data").join("file.txt").exists());

    // run: the bind's data is copied into the destination
    Command::cargo_bin("yd")
        .unwrap()
        .current_dir(dir.path())
        .arg("backup")
        .arg(compose.to_str().unwrap())
        .arg("--run")
        .arg("--dest")
        .arg("bak")
        .assert()
        .success();
    assert!(
        dir.path().join("bak").join("data").join("file.txt").exists(),
        "a confirmed backup run must copy the bind's data into the destination"
    );
}

#[test]
fn prune_keeps_newest_snapshots() {
    let dir = tempfile::tempdir().unwrap();
    for name in ["2026-01", "2026-02", "2026-03"] {
        std::fs::create_dir(dir.path().join(name)).unwrap();
    }

    Command::cargo_bin("yd")
        .unwrap()
        .arg("prune")
        .arg("--dest")
        .arg(dir.path().to_str().unwrap())
        .arg("--keep")
        .arg("2")
        .assert()
        .success();

    assert!(!dir.path().join("2026-01").exists(), "oldest must be pruned");
    assert!(dir.path().join("2026-02").exists());
    assert!(dir.path().join("2026-03").exists());
}

#[test]
fn verify_reports_clean_then_detects_corruption() {
    let dir = tempfile::tempdir().unwrap();
    std::fs::create_dir(dir.path().join("data")).unwrap();
    std::fs::write(dir.path().join("data").join("file.txt"), b"hello").unwrap();
    let compose = dir.path().join("docker-compose.yml");
    std::fs::write(
        &compose,
        "services:\n  app:\n    image: nginx\n    volumes:\n      - ./data:/x\n",
    )
    .unwrap();

    // back up (writes manifest.json)
    Command::cargo_bin("yd")
        .unwrap()
        .current_dir(dir.path())
        .arg("backup")
        .arg(compose.to_str().unwrap())
        .arg("--run")
        .arg("--dest")
        .arg("bak")
        .assert()
        .success();

    // a fresh backup verifies clean
    Command::cargo_bin("yd")
        .unwrap()
        .current_dir(dir.path())
        .arg("verify")
        .arg("--dest")
        .arg("bak")
        .assert()
        .success();

    // tampering is detected (non-zero exit)
    std::fs::write(dir.path().join("bak").join("data").join("file.txt"), b"tampered-and-longer").unwrap();
    Command::cargo_bin("yd")
        .unwrap()
        .current_dir(dir.path())
        .arg("verify")
        .arg("--dest")
        .arg("bak")
        .assert()
        .failure();
}

#[test]
fn stacks_lists_only_compose_dirs() {
    let root = tempfile::tempdir().unwrap();
    std::fs::create_dir(root.path().join("immich")).unwrap();
    std::fs::write(root.path().join("immich").join("docker-compose.yml"), "services: {}").unwrap();
    std::fs::create_dir(root.path().join("notes")).unwrap();
    std::fs::write(root.path().join("notes").join("README.md"), "x").unwrap();

    let assert = Command::cargo_bin("yd")
        .unwrap()
        .arg("stacks")
        .arg("--root")
        .arg(root.path().to_str().unwrap())
        .assert()
        .success();
    let out = String::from_utf8_lossy(&assert.get_output().stdout).to_string();

    assert!(out.contains("immich"), "should list the compose stack; got:\n{out}");
    assert!(!out.contains("notes"), "should not list a non-stack dir; got:\n{out}");
}

#[test]
fn deploy_dry_run_takes_no_action() {
    let dir = tempfile::tempdir().unwrap();
    let compose = dir.path().join("docker-compose.yml");
    std::fs::write(&compose, "services: {}\n").unwrap();

    Command::cargo_bin("yd")
        .unwrap()
        .arg("deploy")
        .arg(compose.to_str().unwrap())
        .assert()
        .success();

    assert!(
        !dir.path().join(".yd-history").exists(),
        "a dry-run deploy must not snapshot or change anything"
    );
}

#[test]
fn notify_sends_message_to_stdout() {
    let assert = Command::cargo_bin("yd")
        .unwrap()
        .arg("notify")
        .arg("--message")
        .arg("hello-operator-42")
        .assert()
        .success();
    let out = String::from_utf8_lossy(&assert.get_output().stdout).to_string();
    assert!(out.contains("hello-operator-42"), "got:\n{out}");
}

#[test]
fn import_places_stack_under_target() {
    let src = tempfile::tempdir().unwrap();
    let compose = src.path().join("docker-compose.yml");
    std::fs::write(&compose, "services: {}\n").unwrap();
    let into = tempfile::tempdir().unwrap();

    Command::cargo_bin("yd")
        .unwrap()
        .arg("import")
        .arg(compose.to_str().unwrap())
        .arg("--into")
        .arg(into.path().to_str().unwrap())
        .arg("--name")
        .arg("adopted")
        .assert()
        .success();

    assert!(
        into.path().join("adopted").join("docker-compose.yml").exists(),
        "imported stack should appear under the target dir"
    );
}

#[test]
fn push_mirrors_backup_to_target() {
    let from = tempfile::tempdir().unwrap();
    std::fs::create_dir(from.path().join("sub")).unwrap();
    std::fs::write(from.path().join("sub").join("b.txt"), b"payload").unwrap();
    let to = tempfile::tempdir().unwrap();

    Command::cargo_bin("yd")
        .unwrap()
        .arg("push")
        .arg("--from")
        .arg(from.path().to_str().unwrap())
        .arg("--to")
        .arg(to.path().to_str().unwrap())
        .assert()
        .success();

    assert!(
        to.path().join("sub").join("b.txt").exists(),
        "push should mirror the nested file to the target"
    );
}

#[test]
fn version_snapshot_then_history() {
    let dir = tempfile::tempdir().unwrap();
    let repo = dir.path().to_str().unwrap();

    Command::cargo_bin("yd").unwrap().args(["version", "init", "--repo", repo]).assert().success();
    std::fs::write(dir.path().join("docker-compose.yml"), "services: {}\n").unwrap();
    Command::cargo_bin("yd").unwrap().args(["version", "snapshot", "--repo", repo, "-m", "first-snapshot"]).assert().success();

    let assert = Command::cargo_bin("yd").unwrap().args(["version", "history", "--repo", repo]).assert().success();
    let out = String::from_utf8_lossy(&assert.get_output().stdout).to_string();
    assert!(out.contains("first-snapshot"), "history should list the snapshot; got:\n{out}");
}

#[test]
fn check_blocks_bad_compose_passes_clean() {
    let dir = tempfile::tempdir().unwrap();
    let bad = dir.path().join("bad.yml");
    std::fs::write(
        &bad,
        "services:\n  db:\n    image: postgres:latest\n    environment:\n      POSTGRES_PASSWORD: hunter2\n",
    )
    .unwrap();
    Command::cargo_bin("yd").unwrap().arg("check").arg(bad.to_str().unwrap()).assert().failure();

    let good = dir.path().join("good.yml");
    std::fs::write(
        &good,
        "services:\n  web:\n    image: nginx:1.27\n    restart: unless-stopped\n    mem_limit: 128m\n    healthcheck:\n      test: [\"CMD\", \"true\"]\n",
    )
    .unwrap();
    Command::cargo_bin("yd").unwrap().arg("check").arg(good.to_str().unwrap()).assert().success();
}

#[test]
fn classify_labels_services_by_kind() {
    let dir = tempfile::tempdir().unwrap();
    let f = dir.path().join("c.yml");
    std::fs::write(
        &f,
        "services:\n  db:\n    image: postgres:16\n  web:\n    image: nginx:1.27\n    ports:\n      - \"8080:80\"\n",
    )
    .unwrap();
    let a = Command::cargo_bin("yd").unwrap().arg("classify").arg(f.to_str().unwrap()).assert().success();
    let out = String::from_utf8_lossy(&a.get_output().stdout).to_string();
    assert!(out.contains("db: datastore"), "got:\n{out}");
    assert!(out.contains("web: web"), "got:\n{out}");
}

#[test]
fn updates_lists_services_with_kind_and_action() {
    let dir = tempfile::tempdir().unwrap();
    let f = dir.path().join("c.yml");
    std::fs::write(
        &f,
        "services:\n  db:\n    image: postgres:16\n  web:\n    image: nginx:1.27\n    ports:\n      - \"80:80\"\n",
    )
    .unwrap();
    let a = Command::cargo_bin("yd").unwrap().arg("updates").arg(f.to_str().unwrap()).assert().success();
    let out = String::from_utf8_lossy(&a.get_output().stdout).to_string();
    assert!(out.contains("db"), "got:\n{out}");
    assert!(out.contains("web"), "got:\n{out}");
    assert!(out.contains("kind=datastore"), "got:\n{out}");
}

#[test]
fn pin_add_then_list() {
    let dir = tempfile::tempdir().unwrap();
    let repo = dir.path().to_str().unwrap();
    Command::cargo_bin("yd").unwrap().args(["pin", "add", "--repo", repo, "--service", "immich"]).assert().success();
    let a = Command::cargo_bin("yd").unwrap().args(["pin", "list", "--repo", repo]).assert().success();
    let out = String::from_utf8_lossy(&a.get_output().stdout).to_string();
    assert!(out.contains("immich"), "got:\n{out}");
}
