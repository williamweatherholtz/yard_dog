//! Pure parsing of a Linux mount table (`/proc/mounts` format) to resolve the
//! filesystem type backing a path. Kept separate from I/O so it is unit-testable
//! on any platform against fixture tables.

/// True when `path` lies at or under mount point `mp`.
fn is_under(path: &str, mp: &str) -> bool {
    mp == "/" || path == mp || path.starts_with(&format!("{mp}/"))
}

/// Given the contents of a `/proc/mounts`-style table, return the filesystem
/// type of the longest mount point containing `path` (e.g. `"nfs4"`, `"ext4"`).
pub fn fstype_from_table(table: &str, path: &str) -> Option<String> {
    let mut best: Option<(usize, String)> = None;
    for line in table.lines() {
        let mut fields = line.split_whitespace();
        let _device = fields.next();
        let Some(mount_point) = fields.next() else {
            continue;
        };
        let Some(fs_type) = fields.next() else {
            continue;
        };
        if is_under(path, mount_point) {
            let len = mount_point.len();
            if best.as_ref().map_or(true, |(l, _)| len > *l) {
                best = Some((len, fs_type.to_string()));
            }
        }
    }
    best.map(|(_, fs)| fs)
}

#[cfg(test)]
mod tests {
    use super::*;

    const TABLE: &str = "\
/dev/sda1 / ext4 rw,relatime 0 0
nas:/export /mnt/nfs nfs4 rw 0 0
//smb/share /mnt/smb cifs rw 0 0
";

    #[test]
    fn resolves_longest_matching_mount() {
        assert_eq!(fstype_from_table(TABLE, "/mnt/nfs/movies").as_deref(), Some("nfs4"));
        assert_eq!(fstype_from_table(TABLE, "/mnt/smb/docs").as_deref(), Some("cifs"));
        // falls back to the root mount
        assert_eq!(fstype_from_table(TABLE, "/srv/data").as_deref(), Some("ext4"));
        // a similarly-named sibling must not match /mnt/nfs
        assert_eq!(fstype_from_table(TABLE, "/mnt/nfsother/x").as_deref(), Some("ext4"));
        // empty table -> unknown
        assert_eq!(fstype_from_table("", "/x"), None);
    }
}
