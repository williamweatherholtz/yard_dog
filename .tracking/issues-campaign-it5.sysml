// =====================================================================
// YardDog — 5-iteration correctness campaign, ITERATION 5 (final) findings. Three
// parallel hostile critiques: an iteration-4 regression + cumulative-coherence
// pass (came back clean), a whole-crate panic/completeness sweep, and a holistic
// data-safety review. Nine resolved in Sprint 67; one filed OPEN (a trade-off).
// =====================================================================
package YardDogCampaignIt5 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    part issPreChangeBackupCwd : Issue {
        :>> id = "0c48913e-c12c-4c28-8a53-bc5bbe628799";
        :>> title = "Pre-change (deploy) backup resolved relative binds against the CWD — the recovery point could capture the wrong data";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "HIGH (the holistic reviewer's single most-likely data-loss path): RealArchiver resolved a relative bind source (`./data`) against the process CWD, and the deploy pre-change hook — unlike `yd backup --run`, which chdir'd — never entered the stack dir. So the recovery point the whole safety story depends on could copy `~/data` (or nothing), while verify blessed it; a later restore could then overwrite good live data with the wrong capture. Fixed: RealArchiver now carries the stack_dir and resolves relative bind sources against it (the subdir key stays the RAW source, symmetric with restore); run_backup resolves a relative --dest against the stack dir too and NO LONGER mutates the process CWD. Proven by the runnable round-trip cli test (which runs from a foreign cwd).";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issRegistrySsrfGaps : Issue {
        :>> id = "d7c12f30-c2e1-4c83-b8ed-76e0e848af2f";
        :>> title = "SSRF guard bypassable: IPv4-mapped IPv6, DNS names pointing at internal IPs, and CGNAT";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med: host_is_public checked only the literal host string. An IPv4-mapped IPv6 literal (`::ffff:169.254.169.254`) parsed as V6 and slipped every private/loopback check; a public-looking DNS name whose A record points at 169.254.169.254/10.x was dialed; CGNAT 100.64/10 was treated public. Fixed: an ip_is_public helper unmaps IPv4-mapped V6 and re-checks, adds CGNAT; a non-literal host is now RESOLVED and every resolved address must be public (reject otherwise). Residual DNS-rebind TOCTOU between check and ureq's connect is documented (would require IP pinning). New unit test covers the literal cases. Impact is bounded to a GET/HEAD returning a digest.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issSecretCommittedOnSave : Issue {
        :>> id = "f9910ac3-58fb-4caa-a5bf-96bbfe54fcf8";
        :>> title = "A plaintext secret is BLOCKED at deploy but silently committed (and pushable) via Save";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med: /api/save (and adopt / `yd version snapshot`) ran no guardrails before snapshot_scoped, so an inline `POSTGRES_PASSWORD: hunter2` a deploy would refuse was committed to git history and pushable to a remote. Fixed: /api/save now runs the guardrails and returns a `warning` when the compose carries a plaintext-secret / embedded-credentials finding; the UI surfaces it as a warn line + warn toast so the operator knows before it lands in history.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issRegressDataHonesty : Issue {
        :>> id = "5b63c7b6-b06a-4dec-a430-fa8f4786e56c";
        :>> title = "A regressed deploy/upgrade rolls back CONFIG only; the outcome implied full recovery";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med (honesty): regress = git-restore the config + redeploy; bind/volume DATA is never reverted (e.g. a DB migration the failed upgrade already ran). Reported as `Regressed`/`RolledBack`, which an operator reads as 'fully recovered'. Fixed: deploy/upgrade now print an explicit note that only the config was rolled back and to restore a backup if the change modified data.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issUpdatePolicyVolumesFrom : Issue {
        :>> id = "ddae6d8e-14bf-4487-a059-90bf9edf834d";
        :>> title = "Update policy missed volumes_from persistence → a data-bearing service could be auto-updated";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low-Med: has_persistent_mount checked only a compose `volumes:` sequence, so a service persisting via `volumes_from:` was classified stateless → AutoApply. Fixed: a service using volumes_from is now also data-bearing (NotifyOnly). (A Dockerfile `VOLUME` with no compose entry remains undetectable from compose alone — noted.)";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }
    part issPinsTempGitignore : Issue {
        :>> id = "bd729e45-80cd-4878-92f6-977e39398eba";
        :>> title = "The iteration-4 .yd-pins temp wasn't gitignored (could be committed by git add -A)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low-Med: write_pin's atomic temp `.yd-pins.<pid>.tmp` had no matching gitignore rule (the iteration-3 backup temps did), so an orphan left by a crash could be committed by a later snapshot's `git add -A`. Fixed: added `.yd-pins.*.tmp` to the managed GITIGNORE block.";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }
    part issTransportSymlink : Issue {
        :>> id = "07247759-1efc-47ba-8b8b-a342805de9ed";
        :>> title = "transport::sync_dir followed symlinks (info disclosure) and aborted mid-mirror on a symlinked dir";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low: walk() treated a symlink as a file and read its target's contents (shipping possibly out-of-tree data), and a symlink→dir made fs::read error and abort the sync after earlier files were already sent. Fixed: walk skips symlinks, mirroring only real dirs + regular files (consistent with the backup copy + verify walk).";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }
    part issRestoreStopFirst : Issue {
        :>> id = "98fd8cfe-58ae-4571-ad69-6ddc8d2bdead";
        :>> title = "Restore overwrote bind data under a live stack with no stop-first guidance; pre-change caveat missing";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low (human-factors): restore swaps bind data under a running container without advising a stop-first (a live DB especially). Fixed: the CLI dry-run message and the UI restore dialog now say to stop the stack first to avoid a torn write; and the pre-change backup prints the not-point-in-time caveat (previously only `yd backup --run` did).";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }
    part issYamlGuardBlockStyle : Issue {
        :>> id = "b8ec8cdd-9146-4039-8cda-b3120e855bd5";
        :>> title = "yaml_guard depth cap counts only flow brackets (block-style nesting bypasses it)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low/Info: the panic-sweep flagged that a block-style nesting bomb (`- - - - …`, no brackets) bypasses yaml_guard's flow-bracket depth cap. Verified EMPIRICALLY (a repro test) that serde_yaml 0.9.34 caps its own recursion and returns Err rather than overflowing — so this is not a live crash, only redundant/unsound defense-in-depth. Making the guard block-style-aware would add false-positives (block scalars), so instead: kept the guard for flow-style, documented the reliance on the library's recursion cap, and added a CANARY test that fails loudly if a future serde_yaml ever stops capping.";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }

    action fixPreChangeBackupCwd; action fixRegistrySsrfGaps; action fixSecretCommittedOnSave;
    action fixRegressDataHonesty; action fixUpdatePolicyVolumesFrom; action fixPinsTempGitignore;
    action fixTransportSymlink; action fixRestoreStopFirst; action fixYamlGuardBlockStyle;
    #Resolves dependency from fixPreChangeBackupCwd to issPreChangeBackupCwd;
    #Resolves dependency from fixRegistrySsrfGaps to issRegistrySsrfGaps;
    #Resolves dependency from fixSecretCommittedOnSave to issSecretCommittedOnSave;
    #Resolves dependency from fixRegressDataHonesty to issRegressDataHonesty;
    #Resolves dependency from fixUpdatePolicyVolumesFrom to issUpdatePolicyVolumesFrom;
    #Resolves dependency from fixPinsTempGitignore to issPinsTempGitignore;
    #Resolves dependency from fixTransportSymlink to issTransportSymlink;
    #Resolves dependency from fixRestoreStopFirst to issRestoreStopFirst;
    #Resolves dependency from fixYamlGuardBlockStyle to issYamlGuardBlockStyle;

    // ---- filed OPEN (a real trade-off; deferred deliberately) ------------------

    part issFirstDeployDbDump : Issue {
        :>> id = "7f17618f-7ff5-411e-bc24-dce139991fcf";
        :>> title = "First deploy of a DB-bearing stack is blocked by the pre-change dump (container not yet running)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med (availability, fails safe): build_backup_plan always emits a dump step for a detected DB image; on a brand-new stack the container isn't running, so `docker compose exec` fails → BackupFailed → exit 2, blocking a legitimate first deploy. The fix has a real trade-off (making the dump best-effort would silently skip a genuinely-failed dump of a running DB), so it is deferred to be designed alongside the Quiescer work: distinguish 'container not running' (skip) from 'dump failed' (error). Filed OPEN.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    action fixFirstDeployDbDump;
    #Resolves dependency from fixFirstDeployDbDump to issFirstDeployDbDump;
}
