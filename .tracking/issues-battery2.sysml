// =====================================================================
// YardDog — findings from the SECOND antagonistic critique battery (2026-07-27),
// five parallel hostile reviewers over the safety-critical core + the new
// thread-per-request server. The CRITICAL/HIGH findings were fixed in the
// battery-2 remediation; MED/LOW ones are filed open for the next refinement.
// =====================================================================
package YardDogBattery2Issues {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    // ---- FIXED (battery-2 remediation) --------------------------------------
    part issDeploySafetyLies : Issue {
        :>> id = "b585b73f-7a4d-4ea0-81ff-4970159daaa5";
        :>> title = "Deploy FSM reports a clean rollback (exit 0) while the failed change is still live";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "CRITICAL: on the FIRST deploy of any stack (no prior snapshot), a health-gate failure fell through to Outcome::Regressed -> exit 0 'cleanly rolled back' even though nothing was restored and the broken change was still running. And a rollback whose restore step ERRORED propagated `?` -> exit 1 (generic), not the loud exit 4. Both told the operator 'safe' when the live stack was broken. Also: an empty (no-services) compose reported a successful deploy. Fixed in flow.rs: no prior OR a restore error -> RegressFailed (exit 4); empty compose -> Blocked. Regression tests added.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issGuardrailEvasion : Issue {
        :>> id = "a047bcf7-38dc-4371-a7cd-e124228c151f";
        :>> title = "Security guardrail lens has multiple false-negatives (dangerous composes pass clean)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "HIGH: the container-hardening lens missed real host-takeover configs: `privileged: \"true\"` (quoted string, as_bool()==None); host-root binds (/ , /etc, /var/run) since only a literal *docker.sock suffix was flagged; `devices:` passthrough (/dev/mem, /dev/sda) had no rule; SYS_MODULE/SYS_PTRACE were only Warn and DAC_READ_SEARCH/SYS_RAWIO/BPF/etc weren't listed; `cap_add` as a scalar string was skipped; `security_opt: seccomp/apparmor unconfined` and `ipc: host` had no rule. Fixed in guardrails.rs: truthy-privileged, sensitive host-path Block, devices Block, expanded host-escape caps Block, scalar cap_add, security_opt-unconfined Block, ipc host Warn. Evasion test added.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issPathConfinementHoles : Issue {
        :>> id = "35ebbb2f-b144-41ef-ac3a-c7560c4d4e49";
        :>> title = "Path-confinement holes: restore traversal bypass, lexical safe_join, protected-path bypass";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "HIGH (two agents): (a) /api/backup/restore's `name` bypassed safe_join via a `.yd-backups` string-prefix escape hatch (`name=.yd-backups/../../etc` -> restore source outside root). (b) safe_join was purely lexical — a symlink UNDER root escaped it (arbitrary WRITE via /api/save). (c) apply.rs is_protected_path (the this-session guard) was bypassable by `/etc/.`, `//etc`, `/etc/../etc`. (d) diff_json passed `from`/`to` into git argv unvalidated (flag-injection). Fixed: drop the prefix exception (confine unconditionally); canonicalize the nearest existing ancestor under root in safe_join; normalize `.`/`..`/slashes in is_protected_path; sha-validate diff refs. Tests added.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issBackupRestoreSafety : Issue {
        :>> id = "23017727-8088-4f27-b699-916ca19c012b";
        :>> title = "Backup/restore data-safety: fail-open verify, non-atomic restore, basename collisions, silent skips, gitignore leak";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "CRITICAL: restore was FAIL-OPEN — a missing/unparseable manifest SKIPPED verification and restored an unverified backup (interrupted backups are exactly the manifest-less ones). HIGH: restore overwrote live data in place (mid-copy failure -> half-restored corruption); backup/restore keyed the subdir on basename only, so `./app/data` + `./db/data` collided -> cross-contamination + silent data loss; restore reported success while named volumes + DB dumps were silently NOT restored; the .gitignore anchored data dirs to depth 1-2 (no **/), leaking data/secrets at depth >=3 (incl. Redis *.rdb). Fixed in backup.rs/main.rs/gitver.rs: fail closed on missing/bad manifest; atomic copy-to-temp-then-swap restore; collision-free basename+hash subdir; report skipped targets; depth-independent **/ ignore + more data extensions. Tests added.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issServerConcurrencyRace : Issue {
        :>> id = "b60b03c0-5211-43ae-8b08-64d7afda4f63";
        :>> title = "Thread-per-request removed the de-facto serializer: concurrent git/deploy races";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "HIGH (self-introduced in the prior remediation): the Sprint-60 thread-per-request change removed the sequential loop that implicitly serialized all git/docker/yd work. On the shared monorepo .git/index, two concurrent /api/save race on index.lock (one aborts; /api/save writes to disk BEFORE snapshot, so a lock-abort leaves config saved-but-unversioned); concurrent deploy/upgrade FSMs on one stack interleave (backup clobber, rollback-target skew). Also the idle sweeper's close() did child.wait() inline and could stall the single sweeper thread forever. Fixed in web.rs: a global mutation lock serializes all mutating POST actions (terminal I/O + GET reads stay concurrent) — proven with 10/10 concurrent saves; and term.rs close() now kills+reaps on a detached thread.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    action fixDeploySafetyLies; action fixGuardrailEvasion; action fixPathConfinementHoles;
    action fixBackupRestoreSafety; action fixServerConcurrencyRace;
    #Resolves dependency from fixDeploySafetyLies to issDeploySafetyLies;
    #Resolves dependency from fixGuardrailEvasion to issGuardrailEvasion;
    #Resolves dependency from fixPathConfinementHoles to issPathConfinementHoles;
    #Resolves dependency from fixBackupRestoreSafety to issBackupRestoreSafety;
    #Resolves dependency from fixServerConcurrencyRace to issServerConcurrencyRace;

    // ---- DEFERRED (open; next refinement) -----------------------------------
    part issHealthGateWeak : Issue {
        :>> id = "f2ebb5a5-dd39-4a04-a316-06bfb9c33089";
        :>> title = "Health-gate is a no-op for services without a healthcheck (deploy reports success on unhealthy)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "MED: `docker compose up -d --wait` treats a service with no healthcheck as satisfied once merely RUNNING, and missing-healthcheck is only a Warn. So a container that starts but is functionally broken (500s, wrong config) passes -> Deployed, exit 0. The core 'the health-gate is real' promise degrades to 'is it running' whenever the operator didn't add a healthcheck. Consider: surface 'deployed but health NOT verified (no healthcheck)' in the outcome/output, or make it a stronger signal at deploy time.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }
    part issHealthTimeoutConflation : Issue {
        :>> id = "4dddcf16-01ef-4ee1-b43d-78f80bca0486";
        :>> title = "Health timeout is indistinguishable from unhealthy; slow-but-healthy stacks wrongly rolled back";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "MED: the deployer collapses every non-zero `up --wait` into one Err (unhealthy/timed-out) and the --wait-timeout is neither surfaced nor configurable. A large image pull or a slow-starting service that would become healthy just past the timeout is treated as unhealthy and rolled back. Consider a configurable timeout and distinguishing timeout from unhealthy.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }
    part issUpgradeSnapshotDrift : Issue {
        :>> id = "21db2127-0e95-4466-a0eb-409be3512d45";
        :>> title = "Upgrade writes the new image to disk before snapshot; a snapshot failure leaves un-committed drift";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "LOW-MED: flow.rs set_service_image() rewrites the compose before snapshot_scoped(). If the snapshot fails, the on-disk compose holds the new image, uncommitted and un-deployed; a later plain deploy would pick it up. The running stack is unchanged (not a live-stack lie). The mutation lock removes the concurrency cause of snapshot failure; residual is a snapshot error for another reason. Consider staging the edit or cleaning up on failure.";
        :>> discoveredInField = false;
        :>> severity = Severity::Low;
    }
    part issBackupNoQuiesce : Issue {
        :>> id = "1078a3c1-a53f-430c-9e4a-71e2c99270ba";
        :>> title = "Backup/restore does not quiesce containers; a torn bind copy still passes verify (false confidence)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "MED: nothing stops/pauses containers around a bind copy, so a backup taken while a container writes captures a torn image; build_manifest then hashes it and verify() returns OK on a logically-corrupt point-in-time. verify proves internal consistency, NOT a consistent snapshot. DB *dumps* are transactionally consistent; bind-mounted databases and app state are not. Consider stop/pause (or fs freeze) around the bind copy/restore, and document that verify != point-in-time consistency.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }
    part issSecretDetectionGaps : Issue {
        :>> id = "826b20a7-29a8-4bb8-b93f-d65c3f735334";
        :>> title = "Plaintext-secret guardrail misses $-prefixed literals and creds in non-secret-named keys";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "LOW: is_plaintext treats any `$`-leading value as interpolation (so `PASSWORD: $ecretLiteral` passes), and key_is_secret only matches a fixed needle set, so a credential in a non-matching key — e.g. `DATABASE_URL: postgres://user:hunter2@db/app` (a very common leak) — is not flagged. Consider value-shape heuristics (URLs with embedded creds, high-entropy literals) alongside the key-name check.";
        :>> discoveredInField = false;
        :>> severity = Severity::Low;
    }
    action fixHealthGateWeak; action fixHealthTimeoutConflation; action fixUpgradeSnapshotDrift;
    action fixBackupNoQuiesce; action fixSecretDetectionGaps;
    #Resolves dependency from fixHealthGateWeak to issHealthGateWeak;
    #Resolves dependency from fixHealthTimeoutConflation to issHealthTimeoutConflation;
    #Resolves dependency from fixUpgradeSnapshotDrift to issUpgradeSnapshotDrift;
    #Resolves dependency from fixBackupNoQuiesce to issBackupNoQuiesce;
    #Resolves dependency from fixSecretDetectionGaps to issSecretDetectionGaps;
}
