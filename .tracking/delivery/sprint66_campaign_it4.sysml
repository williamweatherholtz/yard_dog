// =====================================================================
// YardDog — Sprint 66 delivery: iteration 4 of the 5-iteration correctness
// campaign. Implements the eight fixable iteration-4 findings; two genuinely-low
// items (issTermReapOnEof, issContainerNonRoot) are filed OPEN.
// =====================================================================
package Sprint66CampaignIt4 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyCampaignIt4 : Story {
        :>> id = "dba5b2b0-65a3-4600-8c55-559f09032e39";
        :>> title = "Campaign iteration 4: secret-detection regression, permissions CWD, drift asymmetric-digest, fleet-backup honesty, restore round-trip coverage, exit codes, pin/self-update lows";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 13;
    }

    #CharteredBy dependency from storyCampaignIt4 to needSecureByDefault;

    verification fixSecretDetectionRegressionDoD : Test { :>> id = "eeae5057-5d9b-4ebd-9a54-5e57ea908b2c"; :>> method = VerificationMethod::demo; :>> procedureText = "looks_interpolated treats a leading `$name` as a reference only when there's no SECOND `$` — letter-led MCF hashes ($apr1$/$argon2id$/$y$) flag again while `$PREFIX-suffix` passes. New assertions cover the hashes + the partial reference. Guardrail tests green."; }
    part fixSecretDetectionRegressionDoDR1 : TestResult { :>> id = "0e664daa-928f-4883-a584-c1b9c70278ad"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d8485c"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixPermissionsCwdDoD : Test { :>> id = "bda10fa6-c32e-4efd-b269-e5fb651f2887"; :>> method = VerificationMethod::demo; :>> procedureText = "permissions_json resolves relative binds against the stack dir (resolve_bind_sources), matching mounts_json and the CLI analyzer — ownership findings now target the real host path. Suite green."; }
    part fixPermissionsCwdDoDR1 : TestResult { :>> id = "e34b3916-6254-481c-86ec-e916d8af3f23"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d8485c"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixDriftAsymmetricDigestDoD : Test { :>> id = "92847d76-086f-4d60-844b-0453e9989e7d"; :>> method = VerificationMethod::demo; :>> procedureText = "images_match compares structured (repo,tag,digest): tag-only declared vs tag@digest running matches; both-digests compare digests (re-push = drift); tag-only vs digest-only can't prove drift so matches; different repos/tags drift. New test covers all. Suite green."; }
    part fixDriftAsymmetricDigestDoDR1 : TestResult { :>> id = "276d884a-3883-40e7-9ed6-3a0b72ed0a46"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d8485c"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixFleetBackupSilentFailureDoD : Test { :>> id = "b7608f05-fe9f-4067-8504-39651d64b30e"; :>> method = VerificationMethod::inspect; :>> procedureText = "fleet backup canonicalizes every compose path up front (before any run_backup chdir) and returns a non-zero error when any stack fails — no more exit 0 on failures, no more relative-path misresolution after the first stack."; }
    part fixFleetBackupSilentFailureDoDR1 : TestResult { :>> id = "d4667f5e-3a3f-4e00-9d94-574cc8563fa9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d8485c"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixRestoreCoverageGapDoD : Test { :>> id = "f7a9df31-a746-4f94-9574-43cc4e0048b5"; :>> method = VerificationMethod::demo; :>> procedureText = "New RUNNABLE cli test backup_then_restore_round_trip_recovers_bind_data: back up a bind, corrupt the live file, `yd restore --from <bak> --yes`, assert the original content is recovered (no Docker). The Docker e2e test de-staled to the `data-<hash>` subdir + a real restore round-trip. 23 cli tests green."; }
    part fixRestoreCoverageGapDoDR1 : TestResult { :>> id = "513451e1-fcba-467a-a567-8e801c3a9e2e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d8485c"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixCliExitCodeConsistencyDoD : Test { :>> id = "0488d8c6-020b-4fcb-8f77-fc96eb917a71"; :>> method = VerificationMethod::inspect; :>> procedureText = "restore's missing/unparseable-manifest refusal exits 3 (like verify-fail); `yd drift` exits 3 when drift is detected (0 in sync / running-state unavailable); README exit-code table documents both. The pre-existing drift cli test made robust to docker presence."; }
    part fixCliExitCodeConsistencyDoDR1 : TestResult { :>> id = "e3523091-1c20-49e0-af3b-77104cc8a56a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d8485c"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixPinValidationAtomicDoD : Test { :>> id = "ab2b4651-4ed4-4654-bba2-f94313485b03"; :>> method = VerificationMethod::demo; :>> procedureText = "write_pin rejects an invalid service name (is_valid_service_name) and writes atomically (temp+rename), closing the phantom-pin-via-newline and concurrent-clobber gaps. Suite green."; }
    part fixPinValidationAtomicDoDR1 : TestResult { :>> id = "2753841b-83ab-4a77-8946-f2a85df49786"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d8485c"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixWinUpdateTmpCleanupDoD : Test { :>> id = "113d01f7-109c-4139-84e1-7162832eb46b"; :>> method = VerificationMethod::inspect; :>> procedureText = "The Windows apply_update branch removes the downloaded .yd-update.tmp on both failure paths; the running binary is left intact in every path (unchanged)."; }
    part fixWinUpdateTmpCleanupDoDR1 : TestResult { :>> id = "5b440b51-de5d-4a69-83b0-930b05d9ad90"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d8485c"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification refineGate66 : Test { :>> id = "fa4b6c60-7261-4ede-b8df-b316d4f8820e"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (13); charter to needSecureByDefault. Iteration 4: three hostile critiques (it3 regression, PTY/pin/self-update/packaging, backup→restore lifecycle). Eight findings implemented; two genuinely-low items (term reap-on-EOF, container non-root) filed OPEN with rationale (risk-to-fix / moot vs the socket boundary)."; }
    part refineGate66R1 : TestResult { :>> id = "cef9bc8e-0eb8-4c03-8d60-73c8876f7bb1"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d8485c"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification reviewGate66 : Test { :>> id = "6dda32ae-f399-45fb-8c42-6f200d08a250"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery. (correctness+honesty) the battery again caught a self-inflicted regression — iteration-3's secret-detection fix let letter-led MCF password hashes evade — now corrected + tested. (correctness) the highest-value target, the backup→restore data path, is verified sound by the lifecycle reviewer AND now has RUNNABLE coverage (a real round-trip test) where it previously had none. drift no longer false-positives on an asymmetric digest; fleet backup no longer reports success on failure. (consistency) restore/drift exit codes reconciled + documented. (security) permissions panel no longer probes the CWD. Low items (pin validation/atomicity, Windows update tmp) fixed; two deferred openly. 148 lib + 23 cli + 28 Playwright green; clean release build, no warnings."; }
    part reviewGate66R1 : TestResult { :>> id = "4170ee9f-4edc-457b-bef3-32ba1e1068ad"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d8485c"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification closeOutGate66 : Test { :>> id = "28c72adf-913c-446f-887d-80d6490caacd"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: eight iteration-4 issues resolved; two filed OPEN (term reap-on-EOF, container non-root) plus the four iteration-2 backup-redesign follow-ons still OPEN. cargo build clean (no warnings); 148 lib + 23 cli + 28 Playwright tests green; keel validate + guard green. Iteration 4 complete — iteration 5 (the final battery) may begin."; }
    part closeOutGate66R1 : TestResult { :>> id = "f69d98a8-8875-49fa-bd3d-6f0c6c0db168"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d8485c"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }
}
