// =====================================================================
// YardDog — Sprint 62 delivery: remediate the CRITICAL/HIGH findings from the
// second antagonistic critique battery (deploy-FSM lies, guardrail evasion, path
// confinement, backup/restore data-safety, server concurrency). Lower-severity
// findings filed open for the next refinement.
// =====================================================================
package Sprint62Battery2 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyBattery2 : Story {
        :>> id = "b3aa81a3-54c1-4f40-aee3-ea3011e288ac";
        :>> title = "Remediate battery-2 CRITICAL/HIGH findings (deploy lies, guardrail evasion, path/backup/concurrency safety)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 8;
    }

    #CharteredBy dependency from storyBattery2 to needSecureByDefault;

    verification fixDeploySafetyLiesDoD : Test { :>> id = "84389163-60e2-4703-be98-ac943814cdda"; :>> method = VerificationMethod::demo; :>> procedureText = "flow.rs no longer lies about a rollback: when there is no prior snapshot (the FIRST deploy of a stack) OR the restore step errors, a failed health-gate returns RegressFailed (exit 4) with the failed change flagged as still live — never Outcome::Regressed/exit 0. An empty (no-services) compose returns Blocked, not Deployed. Proven by new flow tests (first_deploy_failure_with_no_prior_is_regress_failed_not_clean; empty_compose_is_not_a_successful_deploy) plus the existing rollback tests — 12 flow tests green. Resolves issDeploySafetyLies."; }
    part fixDeploySafetyLiesDoDR1 : TestResult { :>> id = "c0e82cc1-860e-47c2-94ee-a3ef0aa3a3f3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0a8031b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixGuardrailEvasionDoD : Test { :>> id = "8b2052f6-3e76-4af8-9205-b0c465471c62"; :>> method = VerificationMethod::demo; :>> procedureText = "guardrails.rs closes the security-lens false-negatives: truthy `privileged` (bool/string/int); sensitive host-root binds (/, /etc, /var/run, /proc, /sys, /dev, /var/lib/docker, /boot) Block; `devices:` passthrough Block; expanded host-escape capabilities (SYS_MODULE, SYS_PTRACE, SYS_RAWIO, DAC_READ_SEARCH, DAC_OVERRIDE, BPF, SYS_BOOT, MKNOD, ALL, SYS_ADMIN) Block; `cap_add` as a scalar string handled; `security_opt: seccomp/apparmor unconfined` Block; `ipc: host` Warn. New test security_lens_catches_evasion_variants asserts each variant is blocked while ordinary relative/named data binds still pass. 7 guardrail tests green. Resolves issGuardrailEvasion."; }
    part fixGuardrailEvasionDoDR1 : TestResult { :>> id = "4db8f661-1f4f-48cf-9b3c-653b27e75a15"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0a8031b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixPathConfinementHolesDoD : Test { :>> id = "18544d5a-0bc8-4cbb-acd0-c094c35c871b"; :>> method = VerificationMethod::demo; :>> procedureText = "web.rs + apply.rs close the confinement holes: /api/backup/restore confines `name` unconditionally (the `.yd-backups` prefix escape hatch is gone); safe_join is now symlink-resistant (canonicalizes the nearest existing ancestor and requires it under the canonical root, best-effort when root exists); is_protected_path lexically resolves `.`/`..`/duplicate slashes so `/etc/.`, `//etc`, `/etc/../etc` are all caught (with new test cases); diff_json rejects `from`/`to` that aren't plain hex shas (git-arg-injection guard). 152 Rust tests green. Resolves issPathConfinementHoles."; }
    part fixPathConfinementHolesDoDR1 : TestResult { :>> id = "3a235c7f-7724-4624-9531-25a0079cb98b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0a8031b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixBackupRestoreSafetyDoD : Test { :>> id = "8c03dc3f-736e-4095-a54f-a196a8e00137"; :>> method = VerificationMethod::demo; :>> procedureText = "backup.rs/main.rs/gitver.rs make backup/restore data-safe: restore now FAILS CLOSED (a missing or unparseable manifest is refused, not skipped) then refuses on any integrity mismatch; restore is atomic (copy into a sibling temp, then swap — a mid-copy failure never half-overwrites live data, and the original is put back on a swap error); backup subdirs are collision-free (basename + full-path hash, symmetric between backup and restore) so same-basename sources can't cross-contaminate; restore reports skipped named-volume/dump targets instead of implying they were restored; the .gitignore uses depth-independent **/ patterns + more data extensions (incl. *.rdb) so deep layouts don't leak. Backup/restore/verify tests updated + green (152 Rust tests). Resolves issBackupRestoreSafety."; }
    part fixBackupRestoreSafetyDoDR1 : TestResult { :>> id = "b820274b-d95e-4f79-8851-4fe980d96905"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0a8031b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixServerConcurrencyRaceDoD : Test { :>> id = "7b4ef078-60d7-47de-a83a-f4454c159772"; :>> method = VerificationMethod::demo; :>> procedureText = "web.rs adds a global mutation lock: all mutating POST actions serialize (the monorepo shares one .git/index), while terminal I/O and GET reads stay concurrent (a long deploy no longer stalls the terminal). Proven live: 10/10 concurrent /api/save succeed with distinct shas and no `.git/index.lock` race. term.rs close() now kills+reaps on a detached thread so a slow wait() can't stall the idle sweeper. Resolves issServerConcurrencyRace (the race this session's own thread-per-request change introduced)."; }
    part fixServerConcurrencyRaceDoDR1 : TestResult { :>> id = "8ec9977a-3e87-4788-a256-893543970377"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0a8031b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate62 : Test { :>> id = "0bce0def-80ff-45ae-80cf-325de5fae27c"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (8); charter to needSecureByDefault. Five parallel hostile reviewers critiqued the safety-critical core (deploy FSM, backup/restore) + the new thread-per-request server + a regression pass. 2 CRITICAL + ~9 HIGH findings triaged for this sprint; 5 MED/LOW filed open (issHealthGateWeak, issHealthTimeoutConflation, issUpgradeSnapshotDrift, issBackupNoQuiesce, issSecretDetectionGaps), correctness/security first."; }
    part refineGate62R1 : TestResult { :>> id = "9f725a6e-c321-42ea-90f8-236b7de961be"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0a8031b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate62 : Test { :>> id = "47867322-fb26-4c47-9a01-176078525111"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery (meta). (correctness) the two 'tool lies about safety' holes (first-deploy false-rollback; fail-open restore verify) are the worst class and are fixed with regression tests; the guardrail + path + concurrency fixes each carry a test or a live proof (10/10 concurrent saves; live GET-405/415 for the CSRF read already done). (honesty) the reviewers ALSO confirmed the core is otherwise sound — backup-before-mutation, guardrail-block leaves no side effect, snapshot captures what deploys, restore_scoped is correctly path-scoped, panic isolation holds — so the fixes were targeted, not a rewrite. (self-audit value) the concurrency HIGH was introduced by THIS session's own prior remediation and was caught + fixed here — the battery is self-correcting. (scope) 5 MED/LOW filed open rather than rushed. No finding silently dropped; 152 Rust + 28 Playwright green."; }
    part reviewGate62R1 : TestResult { :>> id = "83664ac7-c48b-44a7-bd5f-11e77522ad59"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0a8031b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate62 : Test { :>> id = "9cc9b012-2b8d-4e42-b7fd-adb47733864b"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issDeploySafetyLies, issGuardrailEvasion, issPathConfinementHoles, issBackupRestoreSafety, issServerConcurrencyRace resolved. cargo build + 152 Rust tests + 28 Playwright UI tests green; concurrency + guardrail + path + backup fixes verified by tests/live proof; keel validate + guard green. Five lower-severity findings remain open for the next refinement."; }
    part closeOutGate62R1 : TestResult { :>> id = "e145ccfc-8671-4ca4-a776-bf4c1977faf3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0a8031b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
