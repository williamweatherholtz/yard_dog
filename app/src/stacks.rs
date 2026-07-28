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
/// A safe stack name: exactly one normal path segment (no `..`, no separators,
/// no absolute/drive prefix, not empty) — so `root.join(name)` can't escape root.
pub fn is_plain_name(name: &str) -> bool {
    let mut comps = Path::new(name).components();
    matches!(comps.next(), Some(std::path::Component::Normal(_))) && comps.next().is_none()
}

pub fn import_stack(compose_path: &Path, stacks_root: &Path, name: Option<&str>) -> io::Result<Stack> {
    let stack_name = match name {
        Some(n) => n.to_string(),
        None => compose_path
            .parent()
            .and_then(|p| p.file_name())
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|| "imported".to_string()),
    };
    if !is_plain_name(&stack_name) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("invalid stack name '{stack_name}' — must be a single path segment (no '/', '..', or drive)"),
        ));
    }
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
        // Carry companion files a deploy needs: override composes + any relative
        // env_file targets (otherwise the imported copy silently differs / breaks).
        for companion in [
            "docker-compose.override.yml", "compose.override.yml",
            "docker-compose.override.yaml", "compose.override.yaml",
        ] {
            let src = parent.join(companion);
            if src.is_file() {
                std::fs::copy(&src, dest.join(companion))?;
            }
        }
        if let Ok(yaml) = std::fs::read_to_string(compose_path) {
            for ef in env_file_refs(&yaml) {
                let rel = Path::new(&ef);
                if rel.is_relative() {
                    let src = parent.join(rel);
                    if src.is_file() {
                        if let Some(dp) = rel.parent() {
                            std::fs::create_dir_all(dest.join(dp))?;
                        }
                        let _ = std::fs::copy(&src, dest.join(rel));
                    }
                }
            }
        }
    }
    Ok(Stack {
        name: stack_name,
        compose_path: dest_compose,
    })
}

/// Relative `env_file:` targets referenced by any service (string or list form).
fn env_file_refs(yaml: &str) -> Vec<String> {
    let mut out = Vec::new();
    let Ok(doc) = serde_yaml::from_str::<serde_yaml::Value>(yaml) else {
        return out;
    };
    let Some(services) = doc.get("services").and_then(|v| v.as_mapping()) else {
        return out;
    };
    for (_, svc) in services {
        match svc.get("env_file") {
            Some(serde_yaml::Value::String(s)) => out.push(s.clone()),
            Some(serde_yaml::Value::Sequence(seq)) => {
                for e in seq {
                    if let Some(s) = e.as_str() {
                        out.push(s.to_string());
                    } else if let Some(p) = e.get("path").and_then(|p| p.as_str()) {
                        out.push(p.to_string());
                    }
                }
            }
            _ => {}
        }
    }
    out
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
