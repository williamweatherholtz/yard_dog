//! Git-backed config versioning (shell-out to `git`, which the tool already
//! requires). Realizes decGitVersioning: an opinionated repo that excludes data
//! and secrets, a single bot committer, history, and restore-as-a-new-commit
//! (never a bare checkout leaving a detached/dirty tree).

use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;

const BOT_NAME: &str = "Yard Dog";
const BOT_EMAIL: &str = "noreply@yarddog.local";

/// Opinionated ignore: config is versioned, data and secrets never are. Data-dir
/// names are anchored one level deep (`*/data/`) so, in the monorepo, a STACK
/// named `data`/`db` at the root is still versioned while a stack's own data
/// subdir is not; data FILES (.env, *.sqlite, *.db, secrets) are excluded anywhere.
const GITIGNORE: &str = "# Yard Dog: never version data or secrets\n\
.yd-backups/\n\
.yd-backups.partial-*\n\
.yd-backups.old-*\n\
.yd-pins.*.tmp\n\
.yd-git.lock\n\
.env\n\
*.env\n\
*.secret\n\
secrets/\n\
# data directories at ANY depth (not just 1-2 levels) — else deep layouts leak\n\
**/data/\n\
**/db/\n\
**/pgdata/\n\
**/mysql/\n\
**/postgres/\n\
**/redis/\n\
*.sqlite\n\
*.sqlite3\n\
*.db\n\
*.rdb\n\
*.mdb\n";

const GITATTRIBUTES: &str = "* text=auto eol=lf\n";

/// A cross-process advisory lock on a repo's git index. The web server's
/// in-process git ops AND spawned `yd` subprocesses (deploy/backup) all take it,
/// so concurrent mutations of the shared monorepo index serialize — held only for
/// the git step, not a whole deploy, so different stacks aren't blocked.
struct IndexLock {
    path: std::path::PathBuf,
    owned: bool,
}
impl Drop for IndexLock {
    fn drop(&mut self) {
        // Only ever remove a lock this instance actually created — never one we
        // proceeded-unlocked past, and never another holder's file.
        if self.owned {
            let _ = std::fs::remove_file(&self.path);
        }
    }
}
fn acquire_index_lock(root: &Path) -> IndexLock {
    let path = root.join(".yd-git.lock");
    let stale = std::time::Duration::from_secs(30);
    loop {
        match std::fs::OpenOptions::new().write(true).create_new(true).open(&path) {
            Ok(mut f) => {
                use std::io::Write;
                let _ = writeln!(f, "{}", std::process::id());
                return IndexLock { path, owned: true };
            }
            Err(e) if e.kind() == io::ErrorKind::AlreadyExists => {
                // Break the lock only if the *file itself* is older than the stale
                // window — never merely because we've waited that long. Measuring
                // the file's age (not our wait time) means a lock another waiter
                // just freshly took has a recent mtime and won't be deleted, so two
                // waiters can't both break in and double-hold the index.
                let stale_now = std::fs::metadata(&path)
                    .and_then(|m| m.modified())
                    .map(|t| t.elapsed().map(|e| e > stale).unwrap_or(false))
                    .unwrap_or(false);
                if stale_now {
                    let _ = std::fs::remove_file(&path);
                    continue;
                }
                std::thread::sleep(std::time::Duration::from_millis(40));
            }
            // Can't even create it (e.g. read-only fs, or a Windows sharing/
            // pending-delete violation) — proceed unlocked rather than hang, and
            // mark it unowned so Drop never deletes a file we didn't create.
            Err(_) => return IndexLock { path, owned: false },
        }
    }
}

/// Run a git command in `dir` with the bot identity (no global config needed).
fn git_ok(dir: &Path, args: &[&str]) -> io::Result<String> {
    let dir_s = dir.to_str().unwrap_or(".");
    let mut cmd = Command::new("git");
    cmd.args(["-C", dir_s])
        .args(["-c", &format!("user.name={BOT_NAME}")])
        .args(["-c", &format!("user.email={BOT_EMAIL}")])
        // Never let a host's global signing requirement or a pre-commit hook block
        // the bot's snapshot/restore commits.
        .args(["-c", "commit.gpgsign=false"])
        .args(["-c", "core.hooksPath="])
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
    ensure_ignore(dir)?;
    // Don't clobber an operator's existing attributes.
    let attr = dir.join(".gitattributes");
    if !attr.exists() {
        std::fs::write(attr, GITATTRIBUTES)?;
    }
    Ok(())
}

const IGNORE_MARKER: &str = "# --- Yard Dog managed: never version data or secrets ---";

/// Ensure the opinionated data/secret ignore rules are present, WITHOUT clobbering
/// an operator's own `.gitignore` — append a marked block once (idempotent). This
/// runs on adopt of a pre-existing repo too, so their data/secrets aren't committed.
fn ensure_ignore(dir: &Path) -> io::Result<()> {
    let path = dir.join(".gitignore");
    let existing = std::fs::read_to_string(&path).unwrap_or_default();
    if existing.contains(IGNORE_MARKER) {
        return Ok(());
    }
    let block = format!("{IGNORE_MARKER}\n{GITIGNORE}# --- end Yard Dog managed ---\n");
    let combined = if existing.trim().is_empty() {
        block
    } else {
        format!("{}\n\n{block}", existing.trim_end())
    };
    std::fs::write(&path, combined)
}

/// Ensure `dir` is a versioning repo: initialise it (with the opinionated
/// ignore/attributes) when it has no `.git`, and do nothing when it is already a
/// repo — so we never clobber an operator's existing git config.
pub fn ensure_repo(dir: &Path) -> io::Result<()> {
    if dir.join(".git").exists() {
        // Existing repo (e.g. an adopted operator repo): don't re-init or touch
        // their git config, but DO ensure our data/secret ignore block is present.
        return ensure_ignore(dir);
    }
    init(dir)
}

/// Commit the current config as a snapshot; returns the commit sha.
pub fn snapshot(dir: &Path, message: &str) -> io::Result<String> {
    let _lock = acquire_index_lock(dir);
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
    let _lock = acquire_index_lock(dir);
    // Bring tracked paths back to their state at `sha` (index + worktree),
    // without moving HEAD, then commit the result as a new snapshot.
    git_ok(dir, &["checkout", sha, "--", "."])?;
    // `checkout -- .` reverts tracked content but leaves files added after `sha`
    // in place. A faithful restore must also delete those, so the worktree
    // matches the target commit exactly (else stray config survives a regress).
    let in_target: std::collections::HashSet<String> =
        split_z(&git_ok(dir, &["ls-tree", "-r", "-z", "--name-only", sha])?);
    let tracked_now = split_z(&git_ok(dir, &["ls-files", "-z"])?);
    for f in tracked_now.iter().filter(|f| !in_target.contains(*f)) {
        git_ok(dir, &["rm", "-f", "--", f])?;
    }
    git_ok(dir, &["add", "-A"])?;
    // Restoring to already-current content is a no-op; committing would fail.
    if git_ok(dir, &["status", "--porcelain"])?.trim().is_empty() {
        return Ok(git_ok(dir, &["rev-parse", "HEAD"])?.trim().to_string());
    }
    let short: String = sha.chars().take(12).collect();
    git_ok(dir, &["commit", "-q", "-m", &format!("restore to {short}")])?;
    Ok(git_ok(dir, &["rev-parse", "HEAD"])?.trim().to_string())
}

/// Unified diff of the config between two points. `to = None` diffs `from`
/// against the current working tree. Returns git's diff output (may be empty).
pub fn diff(dir: &Path, from: &str, to: Option<&str>) -> io::Result<String> {
    match to {
        Some(t) => git_ok(dir, &["diff", from, t, "--", "."]),
        None => git_ok(dir, &["diff", from, "--", "."]),
    }
}

// ---- monorepo: path-scoped operations (decGitVersioning) --------------------
// The versioning repo lives at the stacks ROOT; each stack's config is a subpath.
// `rel` is the stack's path relative to the root ("." = the whole repo, which is
// exactly the single-stack case — so these are drop-in supersets of the above).

/// Convert a relative path into a git pathspec ("." for the repo itself).
fn spec(rel: &Path) -> String {
    let s = rel.to_string_lossy().replace('\\', "/");
    if s.is_empty() || s == "." {
        ".".to_string()
    } else {
        // `:(literal)` disables git's fnmatch, so a stack dir containing `* ? [ ]`
        // can't glob into sibling stacks or match nothing.
        format!(":(literal){s}")
    }
}

fn head(root: &Path) -> io::Result<String> {
    Ok(git_ok(root, &["rev-parse", "HEAD"])?.trim().to_string())
}

/// The git repo root enclosing `start`, or `None` if `start` is not in a repo.
pub fn repo_root(start: &Path) -> Option<PathBuf> {
    let out = git_ok(start, &["rev-parse", "--show-toplevel"]).ok()?;
    let p = out.trim();
    if p.is_empty() {
        None
    } else {
        Some(PathBuf::from(p))
    }
}

/// Snapshot only the config under `rel` within the root repo. A no-op (nothing
/// changed under `rel`) returns the current HEAD instead of failing.
pub fn snapshot_scoped(root: &Path, rel: &Path, message: &str) -> io::Result<String> {
    let _lock = acquire_index_lock(root);
    let sp = spec(rel);
    git_ok(root, &["add", "-A", "--", &sp])?;
    if git_ok(root, &["status", "--porcelain", "--", &sp])?.trim().is_empty() {
        return head(root);
    }
    git_ok(root, &["commit", "-q", "-m", message, "--", &sp])?;
    head(root)
}

/// History of the config under `rel`, newest-first.
pub fn history_scoped(root: &Path, rel: &Path) -> io::Result<Vec<(String, String)>> {
    let log = git_ok(root, &["log", "--pretty=format:%H%x09%s", "--", &spec(rel)])?;
    Ok(log
        .lines()
        .filter(|l| !l.is_empty())
        .map(|l| {
            let mut p = l.splitn(2, '\t');
            (p.next().unwrap_or("").to_string(), p.next().unwrap_or("").to_string())
        })
        .collect())
}

/// Diff the config under `rel` between two points (`to = None` => working tree).
pub fn diff_scoped(root: &Path, rel: &Path, from: &str, to: Option<&str>) -> io::Result<String> {
    let sp = spec(rel);
    match to {
        Some(t) => git_ok(root, &["diff", from, t, "--", &sp]),
        None => git_ok(root, &["diff", from, "--", &sp]),
    }
}

/// Restore the config under `rel` to its state at `sha` (removing files added
/// under `rel` after `sha`), recorded as a new commit. Returns the new sha.
pub fn restore_scoped(root: &Path, rel: &Path, sha: &str) -> io::Result<String> {
    let _lock = acquire_index_lock(root);
    let sp = spec(rel);
    // What existed under `rel` at the target sha (NUL-terminated so non-ASCII /
    // special filenames aren't quote-mangled). Empty ⇒ the stack didn't exist at
    // sha (added/renamed since) — then we skip checkout and just clear it.
    let in_target: std::collections::HashSet<String> = split_z(&git_ok(
        root,
        &["ls-tree", "-r", "-z", "--name-only", sha, "--", &sp],
    )?);
    if !in_target.is_empty() {
        git_ok(root, &["checkout", sha, "--", &sp])?;
    }
    // Remove files under `rel` that are not present at `sha` (scoped stray-removal).
    let now = split_z(&git_ok(root, &["ls-files", "-z", "--", &sp])?);
    for f in now.iter().filter(|f| !in_target.contains(*f)) {
        git_ok(root, &["rm", "-f", "--", f])?;
    }
    git_ok(root, &["add", "-A", "--", &sp])?;
    if git_ok(root, &["status", "--porcelain", "--", &sp])?.trim().is_empty() {
        return head(root);
    }
    let short: String = sha.chars().take(12).collect();
    git_ok(root, &["commit", "-q", "-m", &format!("restore to {short}"), "--", &sp])?;
    head(root)
}

/// Split NUL-terminated git output (from `-z`) into a set of raw paths.
fn split_z(s: &str) -> std::collections::HashSet<String> {
    s.split('\0').filter(|p| !p.is_empty()).map(|p| p.to_string()).collect()
}

// ---- remote sync (needRemoteConfigSync) -------------------------------------
// Auth is delegated to the operator's own git (credential helper / SSH agent /
// gh) — Yard Dog never handles or stores raw tokens.

/// Set (or replace) the `origin` remote URL for the repo at `root`.
pub fn set_remote(root: &Path, url: &str) -> io::Result<()> {
    let _ = git_ok(root, &["remote", "remove", "origin"]); // ignore if absent
    git_ok(root, &["remote", "add", "origin", url])?;
    Ok(())
}

/// The `origin` remote URL, or `None` if no remote is configured.
pub fn remote_url(root: &Path) -> Option<String> {
    git_ok(root, &["remote", "get-url", "origin"])
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

fn current_branch(root: &Path) -> io::Result<String> {
    Ok(git_ok(root, &["rev-parse", "--abbrev-ref", "HEAD"])?.trim().to_string())
}

/// Push the current branch to `origin`, setting upstream. Auth is the operator's.
pub fn push(root: &Path) -> io::Result<String> {
    let branch = current_branch(root)?;
    git_ok(root, &["push", "-u", "origin", &branch])
}

/// Fast-forward pull from `origin`.
pub fn pull(root: &Path) -> io::Result<String> {
    git_ok(root, &["pull", "--ff-only"])
}

/// Explicitly refresh remote-tracking refs (`git fetch origin`). This is the
/// mutating counterpart to `ahead_behind`'s cached read — invoked from a POST so a
/// visited page can't drive network fetches via a GET. Serialized under the index
/// lock since it writes refs/FETCH_HEAD.
pub fn fetch_remote(root: &Path) -> io::Result<String> {
    let _lock = acquire_index_lock(root);
    git_ok(root, &["fetch", "origin"])
}

/// (ahead, behind) commit counts vs `origin/<branch>` after a fetch, or `None`
/// if there is no remote / upstream to compare against.
pub fn ahead_behind(root: &Path) -> Option<(usize, usize)> {
    // Read-only: compare against the LAST-FETCHED tracking ref, with NO fetch — so
    // this stays a pure, side-effect-free read safe to call on a GET. An explicit
    // refresh (fetch_remote) is a separate, mutating POST. Counts may be stale
    // until the next fetch/pull; `None` means no upstream configured.
    let branch = current_branch(root).ok()?;
    let out = git_ok(root, &["rev-list", "--left-right", "--count", &format!("origin/{branch}...HEAD")]).ok()?;
    let mut it = out.split_whitespace();
    let behind = it.next()?.parse().ok()?;
    let ahead = it.next()?.parse().ok()?;
    Some((ahead, behind))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn raw_git(dir: &Path, args: &[&str]) {
        let ok = Command::new("git").args(["-C", dir.to_str().unwrap()]).args(args).status().map(|s| s.success()).unwrap_or(false);
        assert!(ok, "git {args:?} failed in {dir:?}");
    }

    #[test]
    fn remote_push_pull_roundtrip() {
        // a working repo with one snapshot
        let work = tempfile::tempdir().unwrap();
        init(work.path()).unwrap();
        std::fs::write(work.path().join("docker-compose.yml"), "image: nginx:1.27\n").unwrap();
        snapshot(work.path(), "v1").unwrap();

        // a bare repo acts as the remote (local => deterministic, no auth)
        let bare = tempfile::tempdir().unwrap();
        raw_git(bare.path(), &["init", "--bare", "-q"]);
        let url = bare.path().to_string_lossy().replace('\\', "/");

        set_remote(work.path(), &url).unwrap();
        assert_eq!(remote_url(work.path()).as_deref(), Some(url.as_str()));
        push(work.path()).unwrap();
        // in sync right after push
        assert_eq!(ahead_behind(work.path()), Some((0, 0)));

        // a new local commit is 1 ahead
        std::fs::write(work.path().join("docker-compose.yml"), "image: nginx:1.29\n").unwrap();
        snapshot(work.path(), "v2").unwrap();
        assert_eq!(ahead_behind(work.path()).map(|(a, _)| a), Some(1));

        // a fresh clone of the remote has v1 (the pushed state)
        let clone = tempfile::tempdir().unwrap();
        raw_git(clone.path(), &["clone", "-q", &url, "."]);
        assert_eq!(std::fs::read_to_string(clone.path().join("docker-compose.yml")).unwrap(), "image: nginx:1.27\n");
    }

    #[test]
    fn monorepo_scoped_ops_isolate_stacks() {
        // One repo at the root; two stacks a/ and b/ as subpaths.
        let root = tempfile::tempdir().unwrap();
        init(root.path()).unwrap();
        std::fs::create_dir_all(root.path().join("a")).unwrap();
        std::fs::create_dir_all(root.path().join("b")).unwrap();
        std::fs::write(root.path().join("a/docker-compose.yml"), "image: nginx:1.27\n").unwrap();
        std::fs::write(root.path().join("b/docker-compose.yml"), "image: redis:7\n").unwrap();
        let a = std::path::Path::new("a");
        let b = std::path::Path::new("b");

        let a1 = snapshot_scoped(root.path(), a, "deploy a").unwrap();
        let _b1 = snapshot_scoped(root.path(), b, "deploy b").unwrap();
        std::fs::write(root.path().join("a/docker-compose.yml"), "image: nginx:1.29\n").unwrap();
        snapshot_scoped(root.path(), a, "upgrade a").unwrap();

        // history is per-stack
        assert_eq!(history_scoped(root.path(), a).unwrap().len(), 2, "a has two commits");
        assert_eq!(history_scoped(root.path(), b).unwrap().len(), 1, "b untouched by a's commits");
        // diff is scoped to a
        let d = diff_scoped(root.path(), a, &a1, None).unwrap();
        assert!(d.contains("nginx:1.29"), "diff shows a's change");
        // restoring a does not touch b
        restore_scoped(root.path(), a, &a1).unwrap();
        assert_eq!(std::fs::read_to_string(root.path().join("a/docker-compose.yml")).unwrap(), "image: nginx:1.27\n");
        assert_eq!(std::fs::read_to_string(root.path().join("b/docker-compose.yml")).unwrap(), "image: redis:7\n", "b unchanged");
        // repo_root finds the root from a subdir
        assert!(repo_root(&root.path().join("a")).is_some());
    }

    #[test]
    fn diff_shows_changes_between_snapshots() {
        let dir = tempfile::tempdir().unwrap();
        init(dir.path()).unwrap();
        std::fs::write(dir.path().join("docker-compose.yml"), "image: nginx:1.27\n").unwrap();
        let a = snapshot(dir.path(), "a").unwrap();
        std::fs::write(dir.path().join("docker-compose.yml"), "image: nginx:1.29\n").unwrap();
        let b = snapshot(dir.path(), "b").unwrap();

        let d = diff(dir.path(), &a, Some(&b)).unwrap();
        assert!(d.contains("-image: nginx:1.27"), "diff shows removed line:\n{d}");
        assert!(d.contains("+image: nginx:1.29"), "diff shows added line:\n{d}");
        // a snapshot vs. the (matching) working tree is empty
        assert!(diff(dir.path(), &b, None).unwrap().trim().is_empty(), "no diff vs current tree");
    }

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
    fn ensure_repo_inits_once_and_is_idempotent() {
        let dir = tempfile::tempdir().unwrap();
        assert!(!dir.path().join(".git").exists());
        ensure_repo(dir.path()).unwrap();
        assert!(dir.path().join(".git").exists(), "fresh dir gets a repo");
        // a snapshot works after ensure_repo
        std::fs::write(dir.path().join("docker-compose.yml"), "v1").unwrap();
        let sha = snapshot(dir.path(), "first").unwrap();
        // second ensure_repo is a no-op and does not lose history
        ensure_repo(dir.path()).unwrap();
        assert_eq!(history(dir.path()).unwrap()[0].0, sha, "history preserved; not re-init'd");
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
    fn restore_removes_files_added_after_the_target() {
        // A faithful restore makes the worktree match the target commit — files
        // added afterwards must be gone, not merely have their content reverted.
        let dir = tempfile::tempdir().unwrap();
        init(dir.path()).unwrap();
        std::fs::write(dir.path().join("docker-compose.yml"), "v1").unwrap();
        let good = snapshot(dir.path(), "good").unwrap();
        std::fs::write(dir.path().join("override.yml"), "stray").unwrap();
        snapshot(dir.path(), "added override").unwrap();

        restore(dir.path(), &good).unwrap();
        assert!(
            !dir.path().join("override.yml").exists(),
            "a file added after the target must be removed on restore"
        );
        assert_eq!(std::fs::read_to_string(dir.path().join("docker-compose.yml")).unwrap(), "v1");
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
