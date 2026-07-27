//! Yard Dog — path-intelligence and existence-guard core.
//!
//! The crate is organized so the OS/Docker-touching pieces sit behind traits,
//! keeping the classification, existence, remediation, and reporting logic
//! unit-testable on any platform against fixtures.

pub mod classify;
pub mod compose;
pub mod hostfs;
pub mod ownership;
pub mod remediation;
pub mod report;

/// Crate version, surfaced by the CLI.
pub fn version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn crate_reports_a_version() {
        assert!(!version().is_empty());
    }
}
