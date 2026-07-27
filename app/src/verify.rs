//! Backup integrity: a checksum manifest captured at backup time, and
//! verification that a backup still matches it — so "an untested backup" becomes
//! a tested one. Pure over the real filesystem (sha2 + sizes), no Docker.

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::io;
use std::path::Path;

/// A recorded checksum + size for one file.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Entry {
    pub sha256: String,
    pub size: u64,
}

/// A manifest of every file under a backup directory, keyed by relative path.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Manifest {
    pub entries: BTreeMap<String, Entry>,
}

/// What verification found wrong with a backup.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Finding {
    Missing(String),
    Changed(String),
}

fn hash_file(path: &Path) -> io::Result<(String, u64)> {
    let bytes = std::fs::read(path)?;
    let mut hasher = Sha256::new();
    hasher.update(&bytes);
    Ok((format!("{:x}", hasher.finalize()), bytes.len() as u64))
}

fn walk(dir: &Path, base: &Path, out: &mut Vec<std::path::PathBuf>) -> io::Result<()> {
    for entry in std::fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        if entry.file_type()?.is_dir() {
            walk(&path, base, out)?;
        } else {
            out.push(path);
        }
    }
    let _ = base;
    Ok(())
}

/// Build a manifest of every file under `dir` (a file named `manifest.json` at
/// the top level is skipped so a manifest never checksums itself).
pub fn build_manifest(dir: &Path) -> io::Result<Manifest> {
    let mut files = Vec::new();
    walk(dir, dir, &mut files)?;
    let mut entries = BTreeMap::new();
    for path in files {
        let rel = path.strip_prefix(dir).unwrap_or(&path);
        let rel_str = rel.to_string_lossy().replace('\\', "/");
        if rel_str == "manifest.json" {
            continue;
        }
        let (sha256, size) = hash_file(&path)?;
        entries.insert(rel_str, Entry { sha256, size });
    }
    Ok(Manifest { entries })
}

/// Verify `dir` against a previously-recorded `manifest`; empty = intact.
pub fn verify(dir: &Path, manifest: &Manifest) -> io::Result<Vec<Finding>> {
    let mut findings = Vec::new();
    for (rel, expected) in &manifest.entries {
        let path = dir.join(rel);
        if !path.exists() {
            findings.push(Finding::Missing(rel.clone()));
            continue;
        }
        let (sha256, size) = hash_file(&path)?;
        if sha256 != expected.sha256 || size != expected.size {
            findings.push(Finding::Changed(rel.clone()));
        }
    }
    Ok(findings)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn manifest_captures_files_and_verifies_intact() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("a.txt"), b"hello").unwrap();
        std::fs::create_dir(dir.path().join("sub")).unwrap();
        std::fs::write(dir.path().join("sub").join("b.txt"), b"world").unwrap();

        let manifest = build_manifest(dir.path()).unwrap();
        assert_eq!(manifest.entries.len(), 2);
        assert_eq!(manifest.entries["a.txt"].size, 5);

        // intact -> no findings
        assert!(verify(dir.path(), &manifest).unwrap().is_empty());
    }

    #[test]
    fn verify_detects_missing_and_changed() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("keep.txt"), b"stable").unwrap();
        std::fs::write(dir.path().join("gone.txt"), b"temp").unwrap();
        std::fs::write(dir.path().join("edit.txt"), b"before").unwrap();
        let manifest = build_manifest(dir.path()).unwrap();

        std::fs::remove_file(dir.path().join("gone.txt")).unwrap();
        std::fs::write(dir.path().join("edit.txt"), b"after-longer").unwrap();

        let findings = verify(dir.path(), &manifest).unwrap();
        assert!(findings.contains(&Finding::Missing("gone.txt".to_string())));
        assert!(findings.contains(&Finding::Changed("edit.txt".to_string())));
        assert_eq!(findings.len(), 2);
    }

    #[test]
    fn manifest_round_trips_through_json() {
        let mut m = Manifest::default();
        m.entries.insert(
            "x".into(),
            Entry {
                sha256: "abc".into(),
                size: 3,
            },
        );
        let json = serde_json::to_string(&m).unwrap();
        let back: Manifest = serde_json::from_str(&json).unwrap();
        assert_eq!(m, back);
    }
}
