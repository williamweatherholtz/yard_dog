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
