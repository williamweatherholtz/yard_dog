//! Program self-update: compare the running version to the latest release,
//! download the platform binary, verify its SHA256 against the published
//! SHA256SUMS, and atomically replace the running executable. Parsing and the
//! replace step are pure/IO-injectable (unit-tested); the HTTP is a thin `ureq`
//! adapter validated against a real GitHub release.

use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};

/// Result of a self-update check.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SelfUpdateStatus {
    UpToDate,
    UpdateAvailable(String),
    Unknown,
}

/// Resolves the latest available release version (e.g. from GitHub releases).
pub trait ReleaseSource {
    fn latest_version(&self) -> Option<String>;
}

fn parse_semver(v: &str) -> Option<(u32, u32, u32)> {
    let v = v.trim().trim_start_matches('v');
    let mut it = v.split('.');
    let major = it.next()?.parse().ok()?;
    let minor = it.next().unwrap_or("0").parse().ok()?;
    let patch = it
        .next()
        .unwrap_or("0")
        .split(['-', '+'])
        .next()
        .unwrap_or("0")
        .parse()
        .ok()?;
    Some((major, minor, patch))
}

/// True when `latest` is a strictly newer semantic version than `current`.
pub fn version_is_newer(current: &str, latest: &str) -> bool {
    match (parse_semver(current), parse_semver(latest)) {
        (Some(c), Some(l)) => l > c,
        _ => false,
    }
}

/// Check for a newer release via `source`.
pub fn check(current: &str, source: &dyn ReleaseSource) -> SelfUpdateStatus {
    match source.latest_version() {
        Some(latest) if version_is_newer(current, &latest) => {
            SelfUpdateStatus::UpdateAvailable(latest)
        }
        Some(_) => SelfUpdateStatus::UpToDate,
        None => SelfUpdateStatus::Unknown,
    }
}

// ---- apply path -------------------------------------------------------------

/// A release and its downloadable assets (name -> URL).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Release {
    pub version: String,
    pub assets: Vec<(String, String)>,
}

impl Release {
    pub fn asset_url(&self, name: &str) -> Option<&str> {
        self.assets.iter().find(|(n, _)| n == name).map(|(_, u)| u.as_str())
    }
}

/// Parse a GitHub `releases/latest` API response into a [`Release`].
pub fn parse_latest_release(json: &str) -> Option<Release> {
    let v: serde_json::Value = serde_json::from_str(json).ok()?;
    let version = v.get("tag_name").and_then(|t| t.as_str())?.to_string();
    let assets = v
        .get("assets")
        .and_then(|a| a.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|a| {
                    let name = a.get("name").and_then(|n| n.as_str())?;
                    let url = a.get("browser_download_url").and_then(|u| u.as_str())?;
                    Some((name.to_string(), url.to_string()))
                })
                .collect()
        })
        .unwrap_or_default();
    Some(Release { version, assets })
}

/// Parse `sha256sum`-format text into a filename -> lowercase-hex map.
pub fn parse_sha256sums(text: &str) -> HashMap<String, String> {
    let mut out = HashMap::new();
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        // "<hex>␠␠<filename>" (the filename may have a leading '*' for binary).
        if let Some((hex, name)) = line.split_once(char::is_whitespace) {
            let name = name.trim().trim_start_matches('*');
            out.insert(name.to_string(), hex.trim().to_ascii_lowercase());
        }
    }
    out
}

/// True if `bytes` hashes to `expected_hex` (SHA256, case-insensitive).
pub fn verify_sha256(bytes: &[u8], expected_hex: &str) -> bool {
    let mut h = Sha256::new();
    h.update(bytes);
    let got = format!("{:x}", h.finalize());
    got.eq_ignore_ascii_case(expected_hex.trim())
}

/// The release asset filename for the platform this binary was built for.
pub fn platform_asset_name() -> &'static str {
    #[cfg(all(target_os = "windows", target_arch = "x86_64"))]
    { "yd-x86_64-windows.exe" }
    #[cfg(all(target_os = "linux", target_arch = "x86_64"))]
    { "yd-x86_64-linux" }
    #[cfg(all(target_os = "linux", target_arch = "aarch64"))]
    { "yd-aarch64-linux" }
    #[cfg(all(target_os = "macos", target_arch = "x86_64"))]
    { "yd-x86_64-macos" }
    #[cfg(all(target_os = "macos", target_arch = "aarch64"))]
    { "yd-aarch64-macos" }
    #[cfg(not(any(
        all(target_os = "windows", target_arch = "x86_64"),
        all(target_os = "linux", target_arch = "x86_64"),
        all(target_os = "linux", target_arch = "aarch64"),
        all(target_os = "macos", target_arch = "x86_64"),
        all(target_os = "macos", target_arch = "aarch64"),
    )))]
    { "yd-unknown" }
}

/// Replace the running executable at `current_exe` with `new_bytes`, keeping the
/// old binary as a `.old` sibling. The running executable is first renamed aside
/// (permitted on Windows and Unix while running) and the new file moved into its
/// place, so a running process is never overwritten in situ. Returns the backup
/// path. Verify `new_bytes` BEFORE calling this.
pub fn apply_update(current_exe: &Path, new_bytes: &[u8]) -> io::Result<PathBuf> {
    let dir = current_exe.parent().unwrap_or_else(|| Path::new("."));
    let tmp = dir.join(".yd-update.tmp");
    std::fs::write(&tmp, new_bytes)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&tmp, std::fs::Permissions::from_mode(0o755))?;
    }
    let backup = current_exe.with_extension("old");
    let _ = std::fs::remove_file(&backup);
    std::fs::rename(current_exe, &backup)?;
    if let Err(e) = std::fs::rename(&tmp, current_exe) {
        // best-effort restore if the swap-in failed
        let _ = std::fs::rename(&backup, current_exe);
        return Err(e);
    }
    Ok(backup)
}

/// A GitHub-releases-backed source (public repo, anonymous). Thin `ureq` adapter.
pub struct GithubReleases {
    pub repo: String,
}

impl GithubReleases {
    fn get_text(&self, url: &str) -> Option<String> {
        ureq::get(url)
            .set("User-Agent", "yard-dog-selfupdate")
            .call()
            .ok()?
            .into_string()
            .ok()
    }
    pub fn latest_release(&self) -> Option<Release> {
        let url = format!("https://api.github.com/repos/{}/releases/latest", self.repo);
        parse_latest_release(&self.get_text(&url)?)
    }
    pub fn download(&self, url: &str) -> Option<Vec<u8>> {
        use std::io::Read;
        let resp = ureq::get(url).set("User-Agent", "yard-dog-selfupdate").call().ok()?;
        let mut buf = Vec::new();
        resp.into_reader().read_to_end(&mut buf).ok()?;
        Some(buf)
    }
}

impl ReleaseSource for GithubReleases {
    fn latest_version(&self) -> Option<String> {
        self.latest_release().map(|r| r.version)
    }
}

/// Outcome of an apply attempt.
#[derive(Debug)]
pub enum ApplyOutcome {
    UpToDate,
    Updated { from: String, to: String, backup: PathBuf },
    NoAsset(String),
    ChecksumMismatch,
    Unreachable,
}

/// Download the platform asset for the latest release, verify its SHA256 against
/// the published SHA256SUMS, and atomically replace `current_exe`.
pub fn perform_update(
    gh: &GithubReleases,
    current_version: &str,
    current_exe: &Path,
) -> io::Result<ApplyOutcome> {
    let Some(release) = gh.latest_release() else {
        return Ok(ApplyOutcome::Unreachable);
    };
    if !version_is_newer(current_version, &release.version) {
        return Ok(ApplyOutcome::UpToDate);
    }
    let asset = platform_asset_name();
    let (Some(asset_url), Some(sums_url)) = (release.asset_url(asset), release.asset_url("SHA256SUMS")) else {
        return Ok(ApplyOutcome::NoAsset(asset.to_string()));
    };
    let (Some(bin), Some(sums)) = (gh.download(asset_url), gh.download(sums_url).and_then(|b| String::from_utf8(b).ok())) else {
        return Ok(ApplyOutcome::Unreachable);
    };
    let Some(expected) = parse_sha256sums(&sums).get(asset).cloned() else {
        return Ok(ApplyOutcome::ChecksumMismatch);
    };
    if !verify_sha256(&bin, &expected) {
        return Ok(ApplyOutcome::ChecksumMismatch);
    }
    let backup = apply_update(current_exe, &bin)?;
    Ok(ApplyOutcome::Updated {
        from: current_version.to_string(),
        to: release.version,
        backup,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Src(Option<&'static str>);
    impl ReleaseSource for Src {
        fn latest_version(&self) -> Option<String> {
            self.0.map(String::from)
        }
    }

    #[test]
    fn version_compare_is_semantic() {
        assert!(version_is_newer("0.1.0", "0.2.0"));
        assert!(version_is_newer("v0.1.0", "v0.1.1"));
        assert!(!version_is_newer("1.0.0", "1.0.0"));
        assert!(!version_is_newer("1.2.0", "1.1.9"), "older latest is not newer");
        assert!(version_is_newer("1.9.0", "1.10.0"), "numeric, not lexical");
    }

    #[test]
    fn check_reports_status() {
        let src = Src(Some("0.2.0"));
        assert_eq!(
            check("0.1.0", &src),
            SelfUpdateStatus::UpdateAvailable("0.2.0".into())
        );
        assert_eq!(check("0.2.0", &src), SelfUpdateStatus::UpToDate);
        assert_eq!(check("0.1.0", &Src(None)), SelfUpdateStatus::Unknown);
    }

    #[test]
    fn parses_github_latest_release() {
        let json = r#"{"tag_name":"v0.2.0","assets":[
            {"name":"yd-x86_64-linux","browser_download_url":"https://x/yd-x86_64-linux"},
            {"name":"SHA256SUMS","browser_download_url":"https://x/SHA256SUMS"}]}"#;
        let r = parse_latest_release(json).unwrap();
        assert_eq!(r.version, "v0.2.0");
        assert_eq!(r.asset_url("yd-x86_64-linux"), Some("https://x/yd-x86_64-linux"));
        assert_eq!(r.asset_url("SHA256SUMS"), Some("https://x/SHA256SUMS"));
        assert_eq!(r.asset_url("missing"), None);
    }

    #[test]
    fn parses_sha256sums_and_verifies() {
        // sha256("hello world") is known
        let hello = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9";
        let sums = format!("{hello}  yd-x86_64-linux\ndeadbeef *SHA256SUMS\n");
        let m = parse_sha256sums(&sums);
        assert_eq!(m.get("yd-x86_64-linux").map(String::as_str), Some(hello));
        assert_eq!(m.get("SHA256SUMS").map(String::as_str), Some("deadbeef"), "leading * stripped");
        assert!(verify_sha256(b"hello world", hello));
        assert!(verify_sha256(b"hello world", &hello.to_uppercase()), "case-insensitive");
        assert!(!verify_sha256(b"tampered", hello));
    }

    #[test]
    fn apply_update_swaps_binary_and_keeps_backup() {
        let dir = tempfile::tempdir().unwrap();
        let exe = dir.path().join("yd");
        std::fs::write(&exe, b"OLD-BINARY").unwrap();
        let backup = apply_update(&exe, b"NEW-BINARY").unwrap();
        assert_eq!(std::fs::read(&exe).unwrap(), b"NEW-BINARY", "running exe replaced");
        assert_eq!(std::fs::read(&backup).unwrap(), b"OLD-BINARY", "old kept as backup");
        assert!(!dir.path().join(".yd-update.tmp").exists(), "temp file consumed");
    }
}
