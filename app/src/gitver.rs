//! Git-backed config versioning (shell-out to `git`, which the tool already
//! requires). Realizes decGitVersioning: an opinionated repo that excludes data
//! and secrets, a single bot committer, history, and restore-as-a-new-commit
//! (never a bare checkout leaving a detached/dirty tree).

use std::io;
use std::path::Path;
use std::process::Command;

const BOT_NAME: &str = "Yard Dog";
const BOT_EMAIL: &str = "noreply@yarddog.local";

/// Opinionated ignore: config is versioned, data and secrets never are.
const GITIGNORE: &str = "# Yard Dog: never version data or secrets\n\
.yd-backups/\n\
.env\n\
*.env\n\
*.secret\n\
secrets/\n\
data/\n\
db/\n\
pgdata/\n\
*.sqlite\n\
*.sqlite3\n\
*.db\n";

const GITATTRIBUTES: &str = "* text=auto eol=lf\n";

/// Run a git command in `dir` with the bot identity (no global config needed).
fn git_ok(dir: &Path, args: &[&str]) -> io::Result<String> {
    let dir_s = dir.to_str().unwrap_or(".");
    let mut cmd = Command::new("git");
    cmd.args(["-C", dir_s])
        .args(["-c", &format!("user.name={BOT_NAME}")])
        .args(["-c", &format!("user.email={BOT_EMAIL}")])
        .args(args);
    let out = cmd.output()?;
    if !out.status.success() {
        return Err(io::Error::new(
            io::ErrorKind::Other,
            format!(
                "git {:?} failed: {}",
                args,
                String::from_utf8_lossy(&out.stderr).trim()
            ),
        ));
    }
    Ok(String::from_utf8_lossy(&out.stdout).to_string())
}

/// Initialise the versioning repo with the opinionated ignore + attributes.
pub fn init(dir: &Path) -> io::Result<()> {
    std::fs::create_dir_all(dir)?;
    git_ok(dir, &["init", "-q"])?;
    std::fs::write(dir.join(".gitignore"), GITIGNORE)?;
    std::fs::write(dir.join(".gitattributes"), GITATTRIBUTES)?;
    Ok(())
}

/// Commit the current config as a snapshot; returns the commit sha.
pub fn snapshot(dir: &Path, message: &str) -> io::Result<String> {
    git_ok(dir, &["add", "-A"])?;
    // Nothing staged => a deploy with no config change; committing would fail,
    // so treat it as a no-op and return the current HEAD.
    if git_ok(dir, &["status", "--porcelain"])?.trim().is_empty() {
        return Ok(git_ok(dir, &["rev-parse", "HEAD"])?.trim().to_string());
    }
    git_ok(dir, &["commit", "-q", "-m", message])?;
    Ok(git_ok(dir, &["rev-parse", "HEAD"])?.trim().to_string())
}

/// List commits newest-first as (sha, message).
pub fn history(dir: &Path) -> io::Result<Vec<(String, String)>> {
    let log = git_ok(dir, &["log", "--pretty=format:%H%x09%s"])?;
    Ok(log
        .lines()
        .filter(|l| !l.is_empty())
        .map(|l| {
            let mut parts = l.splitn(2, '\t');
            (
                parts.next().unwrap_or("").to_string(),
                parts.next().unwrap_or("").to_string(),
            )
        })
        .collect())
}

/// Restore the working tree to match `sha` and record it as a NEW commit
/// (HEAD advances; never a detached checkout). Returns the new commit sha.
pub fn restore(dir: &Path, sha: &str) -> io::Result<String> {
    // Bring tracked paths back to their state at `sha` (index + worktree),
    // without moving HEAD, then commit the result as a new snapshot.
    git_ok(dir, &["checkout", sha, "--", "."])?;
    git_ok(dir, &["add", "-A"])?;
    // Restoring to already-current content is a no-op; committing would fail.
    if git_ok(dir, &["status", "--porcelain"])?.trim().is_empty() {
        return Ok(git_ok(dir, &["rev-parse", "HEAD"])?.trim().to_string());
    }
    let short = &sha[..sha.len().min(12)];
    git_ok(dir, &["commit", "-q", "-m", &format!("restore to {short}")])?;
    Ok(git_ok(dir, &["rev-parse", "HEAD"])?.trim().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn init_creates_repo_with_ignore_and_attributes() {
        let dir = tempfile::tempdir().unwrap();
        init(dir.path()).unwrap();
        assert!(dir.path().join(".git").exists());
        let ignore = std::fs::read_to_string(dir.path().join(".gitignore")).unwrap();
        assert!(ignore.contains(".env"));
        assert!(ignore.contains(".yd-backups"));
        assert!(dir.path().join(".gitattributes").exists());
    }

    #[test]
    fn snapshot_history_excludes_secrets_and_data() {
        let dir = tempfile::tempdir().unwrap();
        init(dir.path()).unwrap();
        std::fs::write(dir.path().join("docker-compose.yml"), "v1").unwrap();
        std::fs::write(dir.path().join(".env"), "SECRET=1").unwrap();
        std::fs::create_dir(dir.path().join("data")).unwrap();
        std::fs::write(dir.path().join("data").join("x.sqlite"), "blob").unwrap();

        let s1 = snapshot(dir.path(), "first").unwrap();
        std::fs::write(dir.path().join("docker-compose.yml"), "v2").unwrap();
        let s2 = snapshot(dir.path(), "second").unwrap();
        assert_ne!(s1, s2);

        let h = history(dir.path()).unwrap();
        assert_eq!(h[0].1, "second", "newest first");
        assert_eq!(h[1].1, "first");

        let tracked = git_ok(dir.path(), &["ls-files"]).unwrap();
        assert!(tracked.contains("docker-compose.yml"));
        assert!(!tracked.contains(".env"), "secrets must not be tracked");
        assert!(!tracked.contains("x.sqlite"), "data must not be tracked");
    }

    #[test]
    fn snapshot_with_no_changes_is_a_noop_returning_head() {
        // A deploy without a config change must not fail at snapshot time.
        let dir = tempfile::tempdir().unwrap();
        init(dir.path()).unwrap();
        std::fs::write(dir.path().join("docker-compose.yml"), "v1").unwrap();
        let s1 = snapshot(dir.path(), "first").unwrap();
        let s2 = snapshot(dir.path(), "again").unwrap();
        assert_eq!(s1, s2, "no change => same HEAD, no error, no new commit");
        assert_eq!(history(dir.path()).unwrap().len(), 1);
    }

    #[test]
    fn restore_reverts_content_as_a_new_commit() {
        let dir = tempfile::tempdir().unwrap();
        init(dir.path()).unwrap();
        let f = dir.path().join("docker-compose.yml");
        std::fs::write(&f, "good").unwrap();
        let good = snapshot(dir.path(), "good").unwrap();
        std::fs::write(&f, "broken").unwrap();
        snapshot(dir.path(), "broken").unwrap();

        let new_sha = restore(dir.path(), &good).unwrap();
        assert_eq!(std::fs::read_to_string(&f).unwrap(), "good");
        assert_ne!(new_sha, good, "restore creates a new commit");
        assert_eq!(history(dir.path()).unwrap().len(), 3, "HEAD advanced, not detached");
    }
}
