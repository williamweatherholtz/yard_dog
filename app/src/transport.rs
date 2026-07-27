//! Mirror a backup directory to a destination through a pluggable Transport.
//! A LocalTransport (mounted dir / stand-in remote) ships now; object-store /
//! SFTP transports (e.g. rclone) drop in behind the same trait later.

use std::io;
use std::path::{Path, PathBuf};

/// A destination that stores a file at a relative path.
pub trait Transport {
    fn put(&self, rel_path: &str, contents: &[u8]) -> io::Result<()>;
}

fn walk(dir: &Path, out: &mut Vec<PathBuf>) -> io::Result<()> {
    for entry in std::fs::read_dir(dir)? {
        let entry = entry?;
        if entry.file_type()?.is_dir() {
            walk(&entry.path(), out)?;
        } else {
            out.push(entry.path());
        }
    }
    Ok(())
}

/// Send every file under `local_dir` through `transport`, preserving relative
/// paths. Returns the number of files sent.
pub fn sync_dir(local_dir: &Path, transport: &dyn Transport) -> io::Result<usize> {
    let mut files = Vec::new();
    walk(local_dir, &mut files)?;
    let mut count = 0;
    for path in files {
        let rel = path
            .strip_prefix(local_dir)
            .unwrap_or(&path)
            .to_string_lossy()
            .replace('\\', "/");
        let contents = std::fs::read(&path)?;
        transport.put(&rel, &contents)?;
        count += 1;
    }
    Ok(count)
}

/// A transport that writes files under a target directory.
pub struct LocalTransport {
    pub target: PathBuf,
}
impl Transport for LocalTransport {
    fn put(&self, rel_path: &str, contents: &[u8]) -> io::Result<()> {
        let dest = self.target.join(rel_path);
        if let Some(parent) = dest.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(dest, contents)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;

    #[derive(Default)]
    struct RecTransport {
        puts: RefCell<Vec<String>>,
    }
    impl Transport for RecTransport {
        fn put(&self, rel_path: &str, _contents: &[u8]) -> io::Result<()> {
            self.puts.borrow_mut().push(rel_path.to_string());
            Ok(())
        }
    }

    #[test]
    fn sync_sends_every_file_with_relative_paths() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("a.txt"), b"a").unwrap();
        std::fs::create_dir(dir.path().join("sub")).unwrap();
        std::fs::write(dir.path().join("sub").join("b.txt"), b"b").unwrap();

        let rec = RecTransport::default();
        let n = sync_dir(dir.path(), &rec).unwrap();
        assert_eq!(n, 2);
        let mut puts = rec.puts.borrow().clone();
        puts.sort();
        assert_eq!(puts, vec!["a.txt".to_string(), "sub/b.txt".to_string()]);
    }

    #[test]
    fn local_transport_mirrors_into_target() {
        let src = tempfile::tempdir().unwrap();
        std::fs::create_dir(src.path().join("sub")).unwrap();
        std::fs::write(src.path().join("sub").join("b.txt"), b"payload").unwrap();
        let target = tempfile::tempdir().unwrap();

        let n = sync_dir(
            src.path(),
            &LocalTransport {
                target: target.path().to_path_buf(),
            },
        )
        .unwrap();
        assert_eq!(n, 1);
        let mirrored = target.path().join("sub").join("b.txt");
        assert!(mirrored.exists());
        assert_eq!(std::fs::read(mirrored).unwrap(), b"payload");
    }
}
