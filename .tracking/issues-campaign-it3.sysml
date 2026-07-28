// =====================================================================
// YardDog — 5-iteration correctness campaign, ITERATION 3 findings. Three parallel
// hostile critiques: a regression pass on the iteration-2 changes, a fresh-module
// sweep (classify/apply/instantiate/stacks/ownership), and a web-concurrency + UI
// review. All resolved in Sprint 65. (The four backup-redesign follow-ons filed in
// iteration 2 remain OPEN — feature-sized / Docker-integration-dependent.)
// =====================================================================
package YardDogCampaignIt3 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    part issNetworkVolumeStat : Issue {
        :>> id = "16e5467e-0c1a-40d6-8d6a-6e522f1dca69";
        :>> title = "A network-backed named volume was stat'd and mkdir'd by its bare name (spurious host mutation)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "High: MountType::Network merges a network-backed BIND (path source) with a network-driver NAMED VOLUME (name source). report::is_host_path(Network) is true, so build_report called check_existence on the source — for an NFS/CIFS named volume (e.g. `nas:/media`) that's the bare name `nas`, reported Missing, and `yd fix` would mkdir a junk `nas` dir in the CWD. Fixed: build_report only probes/creates a source that is actually path-shaped (classify::is_path_source, now pub); a network named volume is left to Docker.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issImportEnvFileTraversal : Issue {
        :>> id = "37d5bbdb-022b-40a0-ac63-49923d252518";
        :>> title = "`yd import` env_file traversal read/wrote outside the stacks root";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "High: import_stack copied `env_file:` companions with only an is_relative() check — a ref like `../../../etc/cron.d/evil` is relative and escaped via parent.join (reads an arbitrary host file into the managed tree) and dest.join (writes/overwrites outside stacks_root). Fixed: a companion is copied only if it is relative AND lexically confined (is_confined — all components Normal/CurDir, no `..`, no absolute/drive marker).";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issFixPathConfinement : Issue {
        :>> id = "714bc60e-5966-4413-98a9-61c1631b0b9c";
        :>> title = "`yd fix` chown/chmod followed symlinks past the protected-path guard; relative binds resolved against CWD";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med: the protected-path guard is a string check, but chown/chmod/create follow symlinks — a bind source replaced by a symlink → /etc let a confirmed `yd fix` chown the target. Fixed: RealFsMut refuses to mutate a path whose final component is a symlink (refuse_symlink). Separately, `inspect`/`fix` handed raw sources to the analyzer, so a relative bind (`./config`) was stat'd/created relative to the process CWD (the server's CWD under the UI); analyze now resolves relative path sources against the stack dir (as backup does).";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issDiscoverStacksResilience : Issue {
        :>> id = "11c94d30-d5fa-4f21-aa84-a0f73b635ec2";
        :>> title = "One unreadable subdir made the entire stack listing (CLI + fleet UI) vanish";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med: discover_stacks propagated any per-entry error (a permission error on one subdir), and every caller `.unwrap_or_default()`s it — so a single bad directory silently emptied the whole listing ('you have no stacks'). Fixed: only a failure to open the root aborts; a bad entry is skipped, not fatal.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issOwnershipRootFalsePositive : Issue {
        :>> id = "ac162dd9-494e-4509-ab62-71fee5227f8e";
        :>> title = "detect_ownership flagged RootOwned even when the container is meant to run as root";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low: RootOwned fired whenever uid==0, even when the stack declares PUID=0/PGID=0 (root is the correct owner) — advising a chown away from a correct state. Fixed: suppress RootOwned when the expected PUID is 0.";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }
    part issBackupTempOrphans : Issue {
        :>> id = "c2333349-736c-4b11-8b0d-7743d3aa49bb";
        :>> title = "Iteration-2 backup temp/old dirs were not gitignored or GC'd (could leak backup data into git)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med (regression in the iteration-2 atomic-swap): the `.partial-`/`.old-` temp dirs were named outside the `.yd-backups/` ignore, never GC'd across pids, and not removed on a publish-error — so a crash could leave orphans that a later snapshot committed backup DATA into the repo. Fixed: temps are named `.yd-backups.partial-<pid>-<seq>` / `.old-` (matched by new gitignore rules), GC'd on each backup start, removed on the publish-error path, and uniquely suffixed so two same-pid threads don't collide.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issFlowDriftRestoreMissing : Issue {
        :>> id = "0b6ee19b-d8e9-4d5d-9670-8b5e324abc84";
        :>> title = "Upgrade snapshot-failure drift-restore was claimed in iteration 2 but not actually implemented";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med (honesty + correctness): Sprint 64 recorded fixUpgradeSnapshotDrift as passing, but the described mechanism (capture original compose bytes, restore on snapshot failure) was never edited into flow.rs — set_service_image still ran before a fallible snapshot with no restore, so a snapshot failure left uncommitted new-image drift on disk. The battery-3 regression critique caught this. Now actually implemented (capture pre-edit bytes; restore on either the edit or the snapshot failing) with a test that forces a snapshot failure and asserts the compose is restored.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issWebGetLockAndThreads : Issue {
        :>> id = "7d7f7157-1651-4371-a5de-3fd0635fa2fc";
        :>> title = "Per-stack lock defeated on case-insensitive FS; unbounded request threads; GET /api/git still fetched";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med: normalize_stack_key was case-sensitive while safe_join canonicalizes, so on the Windows host `Immich/` and `immich/` resolved to the same stack under DIFFERENT locks (no serialization) — now the key is lower-cased. Thread-per-request was unbounded — now capped (MAX_INFLIGHT with a Drop-guarded counter; over-cap requests get 503). And GET /api/git still ran `git fetch` (a side effect on read) — ahead_behind now reads cached tracking refs only; an explicit POST /api/git/fetch (a UI 'Refresh' button) does the fetch.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issUiSafetySignals : Issue {
        :>> id = "37e85fb4-0b05-4711-9b75-83ab7e446347";
        :>> title = "UI misrepresented backup consistency and buried the health-not-verified signal";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med (human-factors): backup confirm dialogs promised an 'application-consistent backup' while the backend warns copies are NOT point-in-time; that warning rendered as dim stderr; and a green 'verified' chip implied consistency. The health-NOT-verified note printed as a plain console line under a green success. Fixed: dialog copy tells the truth (live copies are not point-in-time; stop the stack for consistency), a `warning:` stderr line renders as a warn (not dim), the health-not-verified note is elevated to a warn line + warn toast, and the recovery-point chip reads 'integrity ✓' with a tooltip stating it proves manifest-match, not a consistent snapshot.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issSecretPartialRefFP : Issue {
        :>> id = "7f9e323d-b9a7-456b-be18-97a9aaa07fa6";
        :>> title = "Secret detection false-positive on a partial variable reference (e.g. $PREFIX-suffix)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low: looks_interpolated required the WHOLE value after `$` to be word-chars, so a legitimate `API_KEY: $PREFIX-suffix` (a variable reference with a suffix) was treated as a plaintext secret and Blocked. Fixed: a `$` immediately followed by a variable-name start counts as interpolation regardless of trailing chars; `$$secret` and `$2b$...` literals still flag. (The complementary false-negative — a mostly-literal value with a trailing `${X}` — remains a documented trade-off.)";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }

    action fixNetworkVolumeStat; action fixImportEnvFileTraversal; action fixFixPathConfinement;
    action fixDiscoverStacksResilience; action fixOwnershipRootFalsePositive; action fixBackupTempOrphans;
    action fixFlowDriftRestoreMissing; action fixWebGetLockAndThreads; action fixUiSafetySignals;
    action fixSecretPartialRefFP;
    #Resolves dependency from fixNetworkVolumeStat to issNetworkVolumeStat;
    #Resolves dependency from fixImportEnvFileTraversal to issImportEnvFileTraversal;
    #Resolves dependency from fixFixPathConfinement to issFixPathConfinement;
    #Resolves dependency from fixDiscoverStacksResilience to issDiscoverStacksResilience;
    #Resolves dependency from fixOwnershipRootFalsePositive to issOwnershipRootFalsePositive;
    #Resolves dependency from fixBackupTempOrphans to issBackupTempOrphans;
    #Resolves dependency from fixFlowDriftRestoreMissing to issFlowDriftRestoreMissing;
    #Resolves dependency from fixWebGetLockAndThreads to issWebGetLockAndThreads;
    #Resolves dependency from fixUiSafetySignals to issUiSafetySignals;
    #Resolves dependency from fixSecretPartialRefFP to issSecretPartialRefFP;
}
