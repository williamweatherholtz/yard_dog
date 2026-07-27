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
