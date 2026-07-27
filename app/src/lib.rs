//! Yard Dog — path-intelligence and existence-guard core.
//!
//! The crate is organized so the OS/Docker-touching pieces sit behind traits,
//! keeping the classification, existence, remediation, and reporting logic
//! unit-testable on any platform against fixtures.

pub mod apply;
pub mod backup;
pub mod classify;
pub mod compose;
pub mod deploy;
pub mod hostfs;
pub mod mounttable;
pub mod notify;
pub mod ownership;
pub mod remediation;
pub mod report;
pub mod retention;
pub mod stacks;
pub mod transport;
pub mod verify;

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
