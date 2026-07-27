//! Base compose management: discover stacks from disk (files stay operator-owned)
//! and keep a copy-based version history of a stack's compose config with
//! snapshot / list / rollback. No tool-owned database, no git required.

use std::io;
use std::path::{Path, PathBuf};

const COMPOSE_NAMES: [&str; 4] = [
    "docker-compose.yml",
    "docker-compose.yaml",
    "compose.yml",
    "compose.yaml",
];

/// A discovered stack: its directory name and the compose file in it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Stack {
    pub name: String,
    pub compose_path: PathBuf,
}

/// The first compose file present in `dir`, if any.
pub fn find_compose(dir: &Path) -> Option<PathBuf> {
    COMPOSE_NAMES
        .iter()
        .map(|n| dir.join(n))
        .find(|p| p.is_file())
}

/// Discover the stacks under `root` — each subdirectory holding a compose file.
pub fn discover_stacks(root: &Path) -> io::Result<Vec<Stack>> {
    let mut stacks = Vec::new();
    for entry in std::fs::read_dir(root)? {
        let entry = entry?;
        if !entry.file_type()?.is_dir() {
            continue;
        }
        if let Some(compose_path) = find_compose(&entry.path()) {
            stacks.push(Stack {
                name: entry.file_name().to_string_lossy().to_string(),
                compose_path,
            });
        }
    }
    stacks.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(stacks)
}

/// Snapshot a compose file (+ sibling `.env`) into the next numbered version
/// under `history_dir`; returns the version name.
pub fn snapshot_config(compose_path: &Path, history_dir: &Path) -> io::Result<String> {
    std::fs::create_dir_all(history_dir)?;
    let next = list_history(history_dir)?
        .iter()
        .filter_map(|v| v.parse::<u32>().ok())
        .max()
        .unwrap_or(0)
        + 1;
    let version = next.to_string();
    let vdir = history_dir.join(&version);
    std::fs::create_dir_all(&vdir)?;

    let file_name = compose_path
        .file_name()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "compose path has no file name"))?;
    std::fs::copy(compose_path, vdir.join(file_name))?;
    if let Some(parent) = compose_path.parent() {
        let env = parent.join(".env");
        if env.is_file() {
            std::fs::copy(&env, vdir.join(".env"))?;
        }
    }
    Ok(version)
}

/// List version names under `history_dir`, newest (highest number) first.
pub fn list_history(history_dir: &Path) -> io::Result<Vec<String>> {
    if !history_dir.exists() {
        return Ok(Vec::new());
    }
    let mut versions: Vec<u32> = Vec::new();
    for entry in std::fs::read_dir(history_dir)? {
        let entry = entry?;
        if entry.file_type()?.is_dir() {
            if let Ok(n) = entry.file_name().to_string_lossy().parse::<u32>() {
                versions.push(n);
            }
        }
    }
    versions.sort_unstable_by(|a, b| b.cmp(a));
    Ok(versions.into_iter().map(|n| n.to_string()).collect())
}

/// Restore `version` from `history_dir` back to `compose_path` — only when
/// `confirmed`. Returns whether a restore happened.
pub fn rollback_config(
    history_dir: &Path,
    version: &str,
    compose_path: &Path,
    confirmed: bool,
) -> io::Result<bool> {
    if !confirmed {
        return Ok(false);
    }
    let vdir = history_dir.join(version);
    let file_name = compose_path
        .file_name()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "compose path has no file name"))?;
    std::fs::copy(vdir.join(file_name), compose_path)?;
    let env = vdir.join(".env");
    if env.is_file() {
        if let Some(parent) = compose_path.parent() {
            std::fs::copy(&env, parent.join(".env"))?;
        }
    }
    Ok(true)
}

/// Import an existing compose file (+ sibling `.env`) into `stacks_root` as a
/// named stack, without modifying the original. Refuses to overwrite an
/// existing stack. `name` defaults to the compose file's parent directory name.
pub fn import_stack(compose_path: &Path, stacks_root: &Path, name: Option<&str>) -> io::Result<Stack> {
    let stack_name = match name {
        Some(n) => n.to_string(),
        None => compose_path
            .parent()
            .and_then(|p| p.file_name())
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|| "imported".to_string()),
    };
    let dest = stacks_root.join(&stack_name);
    if dest.exists() {
        return Err(io::Error::new(
            io::ErrorKind::AlreadyExists,
            format!("stack '{stack_name}' already exists"),
        ));
    }
    std::fs::create_dir_all(&dest)?;

    let file_name = compose_path
        .file_name()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "compose path has no file name"))?;
    let dest_compose = dest.join(file_name);
    std::fs::copy(compose_path, &dest_compose)?;
    if let Some(parent) = compose_path.parent() {
        let env = parent.join(".env");
        if env.is_file() {
            std::fs::copy(&env, dest.join(".env"))?;
        }
    }
    Ok(Stack {
        name: stack_name,
        compose_path: dest_compose,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn touch(path: &Path, contents: &str) {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).unwrap();
        }
        std::fs::write(path, contents).unwrap();
    }

    #[test]
    fn discovers_only_dirs_with_a_compose_file() {
        let root = tempfile::tempdir().unwrap();
        touch(&root.path().join("immich").join("docker-compose.yml"), "services: {}");
        touch(&root.path().join("blog").join("compose.yaml"), "services: {}");
        touch(&root.path().join("notes").join("README.md"), "not a stack");

        let stacks = discover_stacks(root.path()).unwrap();
        let names: Vec<&str> = stacks.iter().map(|s| s.name.as_str()).collect();
        assert!(names.contains(&"immich"));
        assert!(names.contains(&"blog"));
        assert!(!names.contains(&"notes"));
        assert_eq!(stacks.len(), 2);
    }

    #[test]
    fn snapshot_then_list_newest_first() {
        let dir = tempfile::tempdir().unwrap();
        let compose = dir.path().join("docker-compose.yml");
        std::fs::write(&compose, "v1").unwrap();
        std::fs::write(dir.path().join(".env"), "K=1").unwrap();
        let history = dir.path().join(".history");

        let v1 = snapshot_config(&compose, &history).unwrap();
        std::fs::write(&compose, "v2").unwrap();
        let v2 = snapshot_config(&compose, &history).unwrap();

        assert_eq!(v1, "1");
        assert_eq!(v2, "2");
        assert_eq!(list_history(&history).unwrap(), vec!["2", "1"]);
        // the snapshot captured the compose content and the .env
        assert_eq!(
            std::fs::read_to_string(history.join("1").join("docker-compose.yml")).unwrap(),
            "v1"
        );
        assert!(history.join("1").join(".env").exists());
    }

    #[test]
    fn rollback_restores_only_when_confirmed() {
        let dir = tempfile::tempdir().unwrap();
        let compose = dir.path().join("docker-compose.yml");
        std::fs::write(&compose, "good").unwrap();
        let history = dir.path().join(".history");
        snapshot_config(&compose, &history).unwrap(); // version "1" = "good"
        std::fs::write(&compose, "broken").unwrap();

        // not confirmed -> no change
        assert!(!rollback_config(&history, "1", &compose, false).unwrap());
        assert_eq!(std::fs::read_to_string(&compose).unwrap(), "broken");

        // confirmed -> restored
        assert!(rollback_config(&history, "1", &compose, true).unwrap());
        assert_eq!(std::fs::read_to_string(&compose).unwrap(), "good");
    }

    #[test]
    fn import_copies_and_is_discoverable() {
        let src = tempfile::tempdir().unwrap();
        let compose = src.path().join("immich").join("docker-compose.yml");
        touch(&compose, "services: {}");
        std::fs::write(src.path().join("immich").join(".env"), "K=1").unwrap();
        let stacks_root = tempfile::tempdir().unwrap();

        let stack = import_stack(&compose, stacks_root.path(), None).unwrap();
        assert_eq!(stack.name, "immich");
        assert!(stacks_root.path().join("immich").join("docker-compose.yml").exists());
        assert!(stacks_root.path().join("immich").join(".env").exists());
        assert!(compose.exists(), "the original must be left untouched");

        let found = discover_stacks(stacks_root.path()).unwrap();
        assert!(found.iter().any(|s| s.name == "immich"));
    }

    #[test]
    fn import_refuses_to_overwrite() {
        let src = tempfile::tempdir().unwrap();
        let compose = src.path().join("blog").join("compose.yml");
        touch(&compose, "services: {}");
        let stacks_root = tempfile::tempdir().unwrap();

        import_stack(&compose, stacks_root.path(), None).unwrap();
        let err = import_stack(&compose, stacks_root.path(), None).unwrap_err();
        assert_eq!(err.kind(), io::ErrorKind::AlreadyExists);
    }
}
