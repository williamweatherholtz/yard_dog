//! A stack's lifecycle as an explicit finite state machine. States are
//! Draft → Active → Deprecated → Archived; transitions are a fixed guarded
//! table, so an invalid lifecycle move (e.g. restoring a Draft) is not
//! representable. The current state is persisted per-stack on disk, defaulting
//! to Draft when unset — giving later features (new-stack instantiation,
//! archived-stack retention) a defined state to key off.

use std::io;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LifecycleState {
    Draft,
    Active,
    Deprecated,
    Archived,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LifecycleEvent {
    Activate,
    Deprecate,
    Archive,
    Restore,
}

impl LifecycleState {
    pub fn as_str(&self) -> &'static str {
        match self {
            LifecycleState::Draft => "draft",
            LifecycleState::Active => "active",
            LifecycleState::Deprecated => "deprecated",
            LifecycleState::Archived => "archived",
        }
    }
    pub fn parse(s: &str) -> Option<Self> {
        match s.trim() {
            "draft" => Some(LifecycleState::Draft),
            "active" => Some(LifecycleState::Active),
            "deprecated" => Some(LifecycleState::Deprecated),
            "archived" => Some(LifecycleState::Archived),
            _ => None,
        }
    }
}

impl LifecycleEvent {
    pub fn parse(s: &str) -> Option<Self> {
        match s.trim() {
            "activate" => Some(LifecycleEvent::Activate),
            "deprecate" => Some(LifecycleEvent::Deprecate),
            "archive" => Some(LifecycleEvent::Archive),
            "restore" => Some(LifecycleEvent::Restore),
            _ => None,
        }
    }
}

/// Pure guarded transition. `None` means the (state, event) pair is not a valid
/// lifecycle transition — the whole safety of the FSM lives in this table.
pub fn next(state: LifecycleState, event: LifecycleEvent) -> Option<LifecycleState> {
    use LifecycleEvent::*;
    use LifecycleState::*;
    match (state, event) {
        (Draft | Deprecated | Archived, Activate) => Some(Active),
        (Active, Deprecate) => Some(Deprecated),
        (Draft | Active | Deprecated, Archive) => Some(Archived),
        (Archived, Restore) => Some(Active),
        _ => None,
    }
}

fn state_path(dir: &Path) -> PathBuf {
    dir.join(".yd-lifecycle")
}

/// Whether this stack is managed by Yard Dog — i.e. its lifecycle has been set
/// explicitly (a discovered-but-unadopted stack has no state file yet).
pub fn is_managed(dir: &Path) -> bool {
    state_path(dir).exists()
}

/// Read the persisted state, defaulting to Draft when unset/unreadable.
pub fn read_state(dir: &Path) -> LifecycleState {
    std::fs::read_to_string(state_path(dir))
        .ok()
        .and_then(|s| LifecycleState::parse(&s))
        .unwrap_or(LifecycleState::Draft)
}

/// Persist `state` for the stack at `dir`.
pub fn write_state(dir: &Path, state: LifecycleState) -> io::Result<()> {
    // Atomic: write a temp then rename, so a crash mid-write can't truncate the
    // state file into garbage that read_state would silently treat as Draft
    // (which would bypass the archived deploy-gate).
    let path = state_path(dir);
    // A pid-unique temp name so a CLI `yd adopt` racing the web `/api/adopt` on
    // the same stack dir can't collide on one fixed `.tmp` (ENOENT on rename /
    // indeterminate content). The rename remains atomic per writer.
    let tmp = std::path::PathBuf::from(format!("{}.{}.tmp", path.display(), std::process::id()));
    std::fs::write(&tmp, state.as_str())?;
    std::fs::rename(&tmp, &path)
}

/// Apply a guarded transition on disk: read current → transition → persist.
/// Errors (without mutating state) if the event is invalid from the current state.
pub fn transition(dir: &Path, event: LifecycleEvent) -> io::Result<LifecycleState> {
    let current = read_state(dir);
    let next_state = next(current, event).ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("invalid lifecycle transition: {event:?} from {current:?}"),
        )
    })?;
    write_state(dir, next_state)?;
    Ok(next_state)
}

#[cfg(test)]
mod tests {
    use super::LifecycleEvent::*;
    use super::LifecycleState::*;
    use super::*;

    #[test]
    fn valid_transitions_follow_the_table() {
        assert_eq!(next(Draft, Activate), Some(Active));
        assert_eq!(next(Active, Deprecate), Some(Deprecated));
        assert_eq!(next(Deprecated, Archive), Some(Archived));
        assert_eq!(next(Archived, Restore), Some(Active));
        assert_eq!(next(Deprecated, Activate), Some(Active), "reactivate a deprecated stack");
        assert_eq!(next(Active, Archive), Some(Archived), "archive an active stack directly");
        assert_eq!(next(Draft, Archive), Some(Archived), "discard a draft to archive");
        assert_eq!(next(Archived, Activate), Some(Active), "activate is also valid from archived");
    }

    #[test]
    fn invalid_transitions_are_rejected() {
        assert_eq!(next(Draft, Deprecate), None);
        assert_eq!(next(Draft, Restore), None);
        assert_eq!(next(Active, Restore), None);
        assert_eq!(next(Deprecated, Restore), None);
        assert_eq!(next(Archived, Deprecate), None);
        assert_eq!(next(Active, Activate), None, "already active");
    }

    #[test]
    fn disk_transition_rejects_invalid_and_leaves_state_untouched() {
        let dir = tempfile::tempdir().unwrap();
        // default Draft; restore is invalid from Draft
        let err = transition(dir.path(), Restore).unwrap_err();
        assert_eq!(err.kind(), io::ErrorKind::InvalidInput);
        assert_eq!(read_state(dir.path()), Draft, "state must be unchanged after a rejected transition");
    }

    #[test]
    fn is_managed_reflects_explicit_state() {
        let dir = tempfile::tempdir().unwrap();
        assert!(!is_managed(dir.path()), "a discovered-but-unadopted stack is unmanaged");
        write_state(dir.path(), Active).unwrap();
        assert!(is_managed(dir.path()), "setting state marks it managed");
    }

    #[test]
    fn state_defaults_to_draft_and_round_trips() {
        let dir = tempfile::tempdir().unwrap();
        assert_eq!(read_state(dir.path()), Draft, "unset defaults to Draft");
        for s in [Draft, Active, Deprecated, Archived] {
            write_state(dir.path(), s).unwrap();
            assert_eq!(read_state(dir.path()), s, "round-trip {s:?}");
        }
    }

    #[test]
    fn disk_transition_reads_applies_and_persists() {
        let dir = tempfile::tempdir().unwrap();
        assert_eq!(transition(dir.path(), Activate).unwrap(), Active);
        assert_eq!(read_state(dir.path()), Active);
        assert_eq!(transition(dir.path(), Deprecate).unwrap(), Deprecated);
        assert_eq!(transition(dir.path(), Archive).unwrap(), Archived);
        assert_eq!(transition(dir.path(), Restore).unwrap(), Active);
    }
}
