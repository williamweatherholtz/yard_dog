//! Program self-update: compare the running version to the latest release and
//! report whether an update is available. The download-verify-atomic-replace
//! apply plugs into the [`ReleaseSource`] seam in a later increment.

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
}
