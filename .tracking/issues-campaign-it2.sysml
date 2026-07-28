// =====================================================================
// YardDog — 5-iteration correctness campaign, ITERATION 2 findings. Five parallel
// hostile critiques over the backup/verify/retention path, the deploy/health FSM,
// fresh modules (report/hostfs/mounttable/compose/secrets), a regression pass on
// iteration-1's own concurrency fixes, and a web-API/CLI round-2. Fresh findings
// are filed here; the still-open battery-2 items they also close are resolved in
// Sprint 64. The larger backup-snapshot redesign is filed as OPEN follow-ons for
// iteration-3 refinement to prioritize.
// =====================================================================
package YardDogCampaignIt2 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    // ---- fresh findings, resolved in Sprint 64 -------------------------------

    part issBackupPruneDataLoss : Issue {
        :>> id = "2fb0b825-89e9-468d-8111-00d515341d22";
        :>> title = "`prune` deleted live backup DATA (not old snapshots); backups were non-atomic and self-clobbering";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "CRITICAL: retention treated every subdir of the dest as a 'snapshot', but backups write bind-DATA subdirs (e.g. html-1a2b3c4d) FLAT into the same dest — so `yd prune --keep N` lexically sorted those data dirs and remove_dir_all'd the oldest, silently destroying part of the only recovery point. Fixed: LocalStore::list now counts a subdir only if it carries its own manifest.json (data subdirs never do → prune can't touch them; a data-only dest yields zero snapshots = a safe no-op, and run_prune says so rather than reporting a misleading 'pruned 0'). Relatedly the backup overwrote its dest in place (a mid-run failure destroyed the previous good backup): now built into a temp sibling and swapped in atomically only on success (previous backup kept until the new one lands). backup_stack (the deploy pre-change hook) now also writes a manifest, so those backups are verifiable + restorable.";
        :>> discoveredInField = true;
        :>> severity = Severity::Critical;
    }
    part issBackupFidelity : Issue {
        :>> id = "29bbe9cf-fe54-4ae5-a6f2-5971fb93ac00";
        :>> title = "Redis dump captured junk; copies aborted on symlinks/sockets; verify read whole files; dump hit wrong project; no torn-copy warning";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "High: (a) the Redis dump used `redis-cli --rdb /data/dump.rdb`, which writes INSIDE the container and emits only progress on stdout — so the captured redis.dump was empty while redis-cli exited 0 (silent data loss); now `--rdb -` streams the RDB to the captured stdout. (b) copy_tree / copy_dir_all / the verify walk branched on is_dir() else file, so a symlink-to-directory (is_dir()==false) was handed to fs::copy/fs::read and aborted the WHOLE backup/restore/manifest, and a live DB socket/fifo blocked it; now symlinks are recreated (not dereferenced) and special files skipped. (c) verify/manifest read entire files into RAM (OOM on multi-GB tars); now streamed via io::copy. (d) the pre-change dump relied on process CWD (wrong compose project when invoked from the deploy hook, which doesn't chdir); RealRunner now carries the compose path and passes `docker compose -f <compose> exec`. (e) bind/volume copies run against LIVE containers with no quiesce and verify only proves copy==manifest (not point-in-time) — a loud warning now says so at backup time (the Quiescer stop/start trait is filed as a follow-on).";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issTypeMismatchDead : Issue {
        :>> id = "d85639cc-c0fa-48e1-92ee-e30ded5b73b3";
        :>> title = "Wrong-kind bind detection was dead code; symlink bind sources misread ownership / hid dangling links";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "High: Issue::TypeMismatch (file-where-dir-expected, or vice-versa) was defined with full remediation but NEVER constructed outside a unit test — so the tool's core 'prevent the mount footgun' promise silently passed a wrong-kind bind as healthy. build_report now emits TypeMismatch on a strong target-shape signal (trailing-slash ⇒ directory; a recognized config extension ⇒ file), conservatively to avoid false positives on extensionless targets. Relatedly hostfs read a symlink bind source's ownership from the LINK node (usually the creating user/root) rather than the target Docker binds, and reported a dangling symlink as exists/healthy; RealFs now resolves symlinks for kind + ownership and reports a broken target as Missing.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issWebGetSideEffects : Issue {
        :>> id = "110a288f-54d6-4b02-8369-d42a7183959d";
        :>> title = "GET side effects/expense unlocked; /api/restore sha unvalidated; per-stack lock key not normalized; logs uncapped; signing seed on argv";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med (round-2 web/CLI): GET /api/git ran an unlocked `git fetch` (a side effect on read, racing a concurrent read) — the fetch is now serialized under the cross-process index lock. /api/restore (and the CLI `version restore`) passed `sha` unvalidated toward a git option slot — now gated with is_git_sha, matching /api/diff. The per-stack lock keyed on the RAW compose string, so `immich/…` vs `./immich/…` got different mutexes and did NOT serialize the same stack — the key is now lexically normalized. The lock map grew unbounded on distinct keys — now bounded (evict entries no request holds). /api/logs took an unvalidated `tail` and buffered all output — now clamped and output-capped at 1 MiB. `sign-release --key-hex <seed>` exposed the ed25519 seed via argv (ps/CI logs) — the key now comes from $YD_SIGNING_KEY by default (argv is opt-in for local use).";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issRegressionIt1 : Issue {
        :>> id = "7fd4fa77-b63d-45b9-b82a-5d9765ad062b";
        :>> title = "Regressions in iteration-1 fixes: git file-lock ownership/stale race, lifecycle temp collision, drift normalize gaps, whole-disk device aliases, mount-space escapes, selfupdate nits";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med: the gitver index file-lock removed the lockfile on Drop unconditionally and broke a lock after a fixed WAIT (not the file's age) — two waiters could double-hold, and a Windows sharing-violation degrade path could cross-delete a live holder's lock; now IndexLock tracks ownership (Drop removes only a lock it created) and staleness is measured by the lock FILE's mtime. lifecycle write_state used a fixed `.tmp` sibling (CLI/web race on the same stack) — now pid-unique. drift normalize_image missed index.docker.io/registry-1.docker.io prefixes and a tag-plus-digest ref (false drift) — now handled (host:port colon preserved). guardrails is_dangerous_device missed whole-disk udev symlinks (/dev/disk/by-id, /dev/mapper, /dev/block) — now blocked. mounttable ignored /proc/mounts octal escapes (\\040 space) — now unescaped. selfupdate: a whitespace-only pubkey would fail-closed and block all updates (now treated as unconfigured); a missing SHA256SUMS asset line was mislabeled ChecksumMismatch (now ChecksumMissing).";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issComposeInterpolation : Issue {
        :>> id = "559ec55c-2f68-4b44-9d1e-694166388662";
        :>> title = "compose `$$` escape not honored; nested braced default `${A:-${B}}` truncated at first brace";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low: interpolate() did not consume `$$` (Docker's escaped literal `$`), so `pass$$word` stayed doubled and `$${VAR}` wrongly interpolated; and a braced capture stopped at the FIRST `}`, so `${A:-${B}}` captured a truncated inner and left a stray `}`. Both fixed (a `$$` arm + brace-depth-aware capture; resolve_braced already re-interpolates the default).";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }

    action fixBackupPruneDataLoss; action fixBackupFidelity; action fixTypeMismatchDead;
    action fixWebGetSideEffects; action fixRegressionIt1; action fixComposeInterpolation;
    #Resolves dependency from fixBackupPruneDataLoss to issBackupPruneDataLoss;
    #Resolves dependency from fixBackupFidelity to issBackupFidelity;
    #Resolves dependency from fixTypeMismatchDead to issTypeMismatchDead;
    #Resolves dependency from fixWebGetSideEffects to issWebGetSideEffects;
    #Resolves dependency from fixRegressionIt1 to issRegressionIt1;
    #Resolves dependency from fixComposeInterpolation to issComposeInterpolation;

    // ---- OPEN follow-ons: the backup-snapshot redesign (iteration-3 refinement
    // prioritizes these; each has a resolver action but no passing DoD yet) ------

    part issBackupSnapshotLayer : Issue {
        :>> id = "8c244eb4-b45e-4a9d-be38-1b4158727dce";
        :>> title = "Backup lacks a real timestamped multi-snapshot layer (so prune/recovery-points are only partially useful)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "High (follow-on): the data-loss risk is closed (prune is now safe), but the sound design is per-run timestamped snapshot dirs (.yd-backups/<ts>/ each with its own manifest + data), which would make prune genuinely useful and wire the recovery-points UI that web.rs already speculatively supports. This is a feature-sized change spanning run_backup, the pre-change hook, restore, backups_json, and the UI, and warrants integration tests — deferred from iteration 2 to be prioritized in iteration-3 refinement.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issBackupQuiesceTrait : Issue {
        :>> id = "a7085eb6-d91d-44cd-9ff8-3681b8a89f29";
        :>> title = "No quiesce (stop/start) around bind/volume copies for a guaranteed point-in-time backup";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "High (follow-on): a loud warning now tells the operator copies aren't point-in-time (iteration 2), but the sound fix is a Quiescer trait (docker compose stop/start the services owning the copied targets, DB dumps first while up) behind a `--quiesce` flag, kept trait-abstracted so Windows-fixture unit tests still run. Deferred to iteration-3.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issBackupOwnershipPreserve : Issue {
        :>> id = "60ba83a2-c10d-443f-8220-834af3bb68a8";
        :>> title = "Host-side copy does not preserve uid/gid/xattrs (restored DB dir may not start)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med (follow-on): std::fs::copy preserves mode but not ownership/xattrs, so restoring a Postgres data dir via the host-side copy leaves it owned by the yd process user and the container may refuse to start. The sound fix is a tar-in-container archive/restore path for volume/DB-data trees; needs Docker integration. Deferred to iteration-3.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issBackupManifestMetadata : Issue {
        :>> id = "1250fba7-3243-4d40-9937-26f63fb40cd0";
        :>> title = "Manifest records only content+size (misses mode, symlink target, empty dirs)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med (follow-on): verify is a content-equality check for regular files; it cannot detect a mode/ownership change, a file→symlink swap that preserves content, or a missing empty directory, and empty dirs are not restorable. Record dir entries + mode + symlink target and define explicitly what 'intact' covers. Couples to the snapshot-layer work; deferred to iteration-3.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }

    action fixBackupSnapshotLayer; action fixBackupQuiesceTrait;
    action fixBackupOwnershipPreserve; action fixBackupManifestMetadata;
    #Resolves dependency from fixBackupSnapshotLayer to issBackupSnapshotLayer;
    #Resolves dependency from fixBackupQuiesceTrait to issBackupQuiesceTrait;
    #Resolves dependency from fixBackupOwnershipPreserve to issBackupOwnershipPreserve;
    #Resolves dependency from fixBackupManifestMetadata to issBackupManifestMetadata;
}
