// =====================================================================
// YardDog — Sprint 67 delivery: iteration 5 (final) of the 5-iteration correctness
// campaign. Implements the nine fixable iteration-5 findings; one (first-deploy DB
// dump) filed OPEN as a deliberate trade-off. Concludes the operator's 5-iteration
// battery.
// =====================================================================
package Sprint67CampaignIt5 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyCampaignIt5 : Story {
        :>> id = "5ebca631-28e0-4794-9fe2-7f62fdc003a5";
        :>> title = "Campaign iteration 5 (final): pre-change backup CWD data-safety, SSRF guard, save-secret warn, regress honesty, transport/pins/update lows";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 13;
    }

    #CharteredBy dependency from storyCampaignIt5 to needSecureByDefault;

    verification fixPreChangeBackupCwdDoD : Test { :>> id = "b6f95893-9bc5-4a70-8efc-d5014dc7f271"; :>> method = VerificationMethod::demo; :>> procedureText = "RealArchiver carries stack_dir and resolves relative bind sources against it (subdir key stays the raw source, symmetric with restore); run_backup resolves a relative --dest against the stack dir and no longer mutates the process CWD. The runnable round-trip cli test (run from a foreign cwd) backs up, corrupts, restores, and recovers — proving the pre-change recovery point now captures the right path. Suite green."; }
    part fixPreChangeBackupCwdDoDR1 : TestResult { :>> id = "75390648-5a00-437e-9975-c5b431e057b5"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixRegistrySsrfGapsDoD : Test { :>> id = "113318fb-57d3-421b-b6a6-2dba040bd0c7"; :>> method = VerificationMethod::demo; :>> procedureText = "ip_is_public unmaps IPv4-mapped IPv6 + adds CGNAT 100.64/10; host_is_public resolves a DNS host and requires every resolved address be public. New unit test rejects loopback/private/link-local/CGNAT/mapped-V6/localhost literals and allows real public IPs. Suite green."; }
    part fixRegistrySsrfGapsDoDR1 : TestResult { :>> id = "e0ce9a04-fa5c-492f-94f7-d5c6aecef9a0"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixSecretCommittedOnSaveDoD : Test { :>> id = "7232acd9-fabc-4cf1-8831-8f83c617ebcf"; :>> method = VerificationMethod::inspect; :>> procedureText = "/api/save runs guardrails and returns a `warning` when the compose carries a plaintext-secret/embedded-credentials finding; the UI renders it as a warn line + warn toast so an operator sees it before it lands in git history / a push."; }
    part fixSecretCommittedOnSaveDoDR1 : TestResult { :>> id = "3786745b-4c0e-44a4-aff1-b702076d42c5"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixRegressDataHonestyDoD : Test { :>> id = "773101c6-f1f7-4be0-ad4f-56232f15ee4d"; :>> method = VerificationMethod::inspect; :>> procedureText = "deploy (RolledBack) and upgrade (Regressed) print an explicit note that only the CONFIG was rolled back and bind/volume DATA is not reverted — restore a backup if the change modified data."; }
    part fixRegressDataHonestyDoDR1 : TestResult { :>> id = "ad50c3f2-1b98-4009-b173-b9682877331f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixUpdatePolicyVolumesFromDoD : Test { :>> id = "01d1c014-4c28-4f03-9db5-0b61ee39c642"; :>> method = VerificationMethod::demo; :>> procedureText = "has_persistent_mount now also true when a service uses volumes_from, so a service inheriting data mounts is NotifyOnly (not auto-updated). Workload tests green."; }
    part fixUpdatePolicyVolumesFromDoDR1 : TestResult { :>> id = "c01c4e6c-d497-4a4a-bbac-699f35fed342"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixPinsTempGitignoreDoD : Test { :>> id = "0af20228-e6f8-4bca-9544-8ffe759c2b3e"; :>> method = VerificationMethod::inspect; :>> procedureText = "`.yd-pins.*.tmp` added to the managed GITIGNORE block so an orphaned pin temp can't be committed by a later `git add -A` snapshot."; }
    part fixPinsTempGitignoreDoDR1 : TestResult { :>> id = "edfe1095-81ad-42c6-ab18-f5989e7c8ad3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixTransportSymlinkDoD : Test { :>> id = "7c57ee69-30fa-45ba-adc2-b4f9c7803725"; :>> method = VerificationMethod::inspect; :>> procedureText = "transport::sync_dir walk() skips symlinks (mirroring only real dirs + regular files), so it can't ship an out-of-tree symlink target's contents or abort mid-mirror on a symlinked directory — consistent with the backup copy + verify walk."; }
    part fixTransportSymlinkDoDR1 : TestResult { :>> id = "916be36b-048b-4b84-842b-21163ca17e2b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixRestoreStopFirstDoD : Test { :>> id = "4d0d1349-38a2-4c29-8358-5016edc6ad90"; :>> method = VerificationMethod::inspect; :>> procedureText = "The CLI restore dry-run message + the UI restore dialog advise stopping the stack first (avoid a torn write under a running container); the pre-change backup prints the not-point-in-time caveat too."; }
    part fixRestoreStopFirstDoDR1 : TestResult { :>> id = "4314d65b-29f3-4af7-bdc3-b87739ed4f24"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixYamlGuardBlockStyleDoD : Test { :>> id = "f3ca4ca3-bfea-4b02-8e0f-29b2fa61f4c4"; :>> method = VerificationMethod::demo; :>> procedureText = "Empirically verified (repro test) that serde_yaml 0.9.34 rejects a 400k-deep block-style nesting bomb with Err (no stack overflow) — so the flow-only yaml_guard is safe redundant defense-in-depth. Kept the guard, documented the reliance, and added a canary test that fails loudly if a future serde_yaml stops capping recursion."; }
    part fixYamlGuardBlockStyleDoDR1 : TestResult { :>> id = "40e6a0eb-26de-4496-a44b-627049fb36fe"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification refineGate67 : Test { :>> id = "e9219e63-86f3-4d4e-a5d9-eaec4e108c0a"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (13); charter to needSecureByDefault. Final iteration: three hostile critiques (it4 regression + cumulative, whole-crate panic sweep, holistic data-safety). Nine findings implemented; first-deploy DB dump filed OPEN as a deliberate trade-off. The it4-regression reviewer confirmed iterations 1-4 compose coherently with no HIGH regressions."; }
    part refineGate67R1 : TestResult { :>> id = "ba979fec-122c-475c-95d3-c80ff6c333c9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification reviewGate67 : Test { :>> id = "fe29c9a7-c85a-416a-a226-81df892f4977"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery (final). (correctness/data-safety) the holistic reviewer's single most-likely data-loss path — the pre-change backup resolving binds against the CWD — is fixed and proven by a runnable round-trip test; the FSM honesty guarantees, the atomic backup publish, and the git-versioning core were independently verified sound. (security) SSRF guard closed for mapped-V6/DNS/CGNAT; the save-time plaintext-secret-into-git asymmetry is now warned; transport symlink info-disclosure closed. (honesty) regress-is-config-only is now stated; a disputed HIGH (yaml block-bomb) was resolved EMPIRICALLY (no crash) rather than assumed, with a canary left behind; one availability trade-off (first-deploy DB dump) filed OPEN rather than rushed. 150 lib + 23 cli + 28 Playwright green; clean release build, no warnings."; }
    part reviewGate67R1 : TestResult { :>> id = "a244c65e-4297-4db5-beb9-f3ac4623d0ec"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification closeOutGate67 : Test { :>> id = "646dd979-97fe-4612-b511-659ea1eef91b"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: nine iteration-5 issues resolved; one filed OPEN (first-deploy DB dump). cargo build clean (no warnings); 150 lib + 23 cli + 28 Playwright tests green; keel validate + guard green. The 5-iteration correctness campaign is COMPLETE. Remaining OPEN work: the four iteration-2 backup-redesign features (snapshot layer, Quiescer, ownership tar, manifest metadata), first-deploy DB dump, and two iteration-4 lows (PTY reap-on-EOF, container non-root) — all feature-sized or Docker-integration-dependent, recommended for a dedicated sprint with a live daemon. Standing operator action: provision the release signing key to activate signature enforcement."; }
    part closeOutGate67R1 : TestResult { :>> id = "1b29ebc2-ea0c-4bfd-822e-1057406ab96b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7514a1f"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }
}
