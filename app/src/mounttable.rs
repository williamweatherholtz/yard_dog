//! Pure parsing of a Linux mount table (`/proc/mounts` format) to resolve the
//! filesystem type backing a path. Kept separate from I/O so it is unit-testable
//! on any platform against fixture tables.

/// True when `path` lies at or under mount point `mp`.
fn is_under(path: &str, mp: &str) -> bool {
    mp == "/" || path == mp || path.starts_with(&format!("{mp}/"))
}

/// `/proc/mounts` octal-escapes whitespace and backslashes in the mount point
/// (space→`\040`, tab→`\011`, newline→`\012`, backslash→`\134`). Undo them so a
/// mount point containing a space compares against a real filesystem path.
fn unescape_mount(s: &str) -> String {
    let bytes = s.as_bytes();
    let mut out = String::with_capacity(s.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'\\' && i + 3 < bytes.len() {
            let oct = &bytes[i + 1..i + 4];
            if oct.iter().all(|d| (b'0'..=b'7').contains(d)) {
                if let Ok(code) = u8::from_str_radix(std::str::from_utf8(oct).unwrap_or(""), 8) {
                    out.push(code as char);
                    i += 4;
                    continue;
                }
            }
        }
        out.push(bytes[i] as char);
        i += 1;
    }
    out
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
        let mount_point = unescape_mount(mount_point);
        let Some(fs_type) = fields.next() else {
            continue;
        };
        if is_under(path, &mount_point) {
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
    fn resolves_mount_point_with_octal_escaped_space() {
        let table = "//server/share /mnt/my\\040share cifs rw 0 0\n/dev/sda1 / ext4 rw 0 0\n";
        assert_eq!(fstype_from_table(table, "/mnt/my share/x").as_deref(), Some("cifs"));
    }

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
