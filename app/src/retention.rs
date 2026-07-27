//! Backup retention over a pluggable [`SnapshotStore`]. The store abstracts the
//! destination (a local directory now; a remote object store / SFTP later); the
//! keep-N policy is a pure function so it is trivially unit-testable.

use std::io;
use std::path::PathBuf;

/// Given existing snapshot names (named so they sort chronologically) and a
/// keep count, return the names to prune — the oldest beyond the newest `keep`.
pub fn snapshots_to_prune(existing: &[String], keep: usize) -> Vec<String> {
    let mut sorted = existing.to_vec();
    sorted.sort();
    if sorted.len() <= keep {
        return Vec::new();
    }
    let cut = sorted.len() - keep;
    sorted.into_iter().take(cut).collect()
}

/// A destination that holds backup snapshots.
pub trait SnapshotStore {
    fn list(&self) -> io::Result<Vec<String>>;
    fn remove(&self, name: &str) -> io::Result<()>;
}

/// Enforce keep-N retention against a store; returns the names removed.
pub fn apply_retention(store: &dyn SnapshotStore, keep: usize) -> io::Result<Vec<String>> {
    let existing = store.list()?;
    let prune = snapshots_to_prune(&existing, keep);
    for name in &prune {
        store.remove(name)?;
    }
    Ok(prune)
}

/// A snapshot store backed by a local directory (each snapshot is a subdir).
pub struct LocalStore {
    pub dir: PathBuf,
}

impl SnapshotStore for LocalStore {
    fn list(&self) -> io::Result<Vec<String>> {
        let mut names = Vec::new();
        for entry in std::fs::read_dir(&self.dir)? {
            let entry = entry?;
            if entry.file_type()?.is_dir() {
                names.push(entry.file_name().to_string_lossy().to_string());
            }
        }
        Ok(names)
    }
    fn remove(&self, name: &str) -> io::Result<()> {
        std::fs::remove_dir_all(self.dir.join(name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;

    #[test]
    fn prune_keeps_the_newest_n() {
        let existing = vec!["2026-01".into(), "2026-02".into(), "2026-03".into()];
        assert_eq!(snapshots_to_prune(&existing, 2), vec!["2026-01".to_string()]);
    }

    #[test]
    fn prune_none_when_within_keep() {
        let existing = vec!["a".to_string(), "b".to_string()];
        assert!(snapshots_to_prune(&existing, 5).is_empty());
    }

    #[test]
    fn prune_all_when_keep_zero() {
        let existing = vec!["a".to_string(), "b".to_string()];
        assert_eq!(snapshots_to_prune(&existing, 0).len(), 2);
    }

    #[test]
    fn apply_retention_removes_oldest_via_store() {
        struct RecStore {
            items: Vec<String>,
            removed: RefCell<Vec<String>>,
        }
        impl SnapshotStore for RecStore {
            fn list(&self) -> io::Result<Vec<String>> {
                Ok(self.items.clone())
            }
            fn remove(&self, name: &str) -> io::Result<()> {
                self.removed.borrow_mut().push(name.to_string());
                Ok(())
            }
        }
        let store = RecStore {
            items: vec!["a".into(), "b".into(), "c".into()],
            removed: RefCell::new(Vec::new()),
        };
        let removed = apply_retention(&store, 2).unwrap();
        assert_eq!(removed, vec!["a".to_string()]);
        assert_eq!(*store.removed.borrow(), vec!["a".to_string()]);
    }
}
