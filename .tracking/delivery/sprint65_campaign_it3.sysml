// =====================================================================
// YardDog — Sprint 65 delivery: iteration 3 of the 5-iteration correctness
// campaign. Implements ALL findings from the three iteration-3 hostile critiques
// (regression on iteration-2, fresh-module sweep, web-concurrency + UI). The four
// backup-redesign follow-ons (issBackupSnapshotLayer/QuiesceTrait/OwnershipPreserve/
// ManifestMetadata) remain OPEN — feature-sized / Docker-integration-dependent.
// =====================================================================
package Sprint65CampaignIt3 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyCampaignIt3 : Story {
        :>> id = "f4eafb5c-9b49-44bf-87fb-ab7f5c23c961";
        :>> title = "Campaign iteration 3: network-volume/import/fix confinement, discover resilience, backup-temp orphans, drift-restore (for real), web locks/threads, UI safety signals";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 18;
    }

    #CharteredBy dependency from storyCampaignIt3 to needSecureByDefault;

    verification fixNetworkVolumeStatDoD : Test { :>> id = "c2fc14b3-376b-4f9e-ae77-d833f3a63b01"; :>> method = VerificationMethod::demo; :>> procedureText = "build_report probes/creates only a path-shaped source (classify::is_path_source, now pub); a network-backed named volume (bare name) is no longer stat'd or mkdir'd. Suite green."; }
    part fixNetworkVolumeStatDoDR1 : TestResult { :>> id = "c6f78f8e-7872-4d98-9d40-9d61accc7203"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixImportEnvFileTraversalDoD : Test { :>> id = "63a6d748-c722-4674-9f92-012c66eb8317"; :>> method = VerificationMethod::demo; :>> procedureText = "import copies an env_file companion only when relative AND confined (is_confined rejects `..`/absolute), closing the read/write traversal out of stacks_root. Suite green."; }
    part fixImportEnvFileTraversalDoDR1 : TestResult { :>> id = "65020169-bf1b-45ee-8fe2-0c39e1efc625"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixFixPathConfinementDoD : Test { :>> id = "568d06a5-cf71-44ad-bd80-158f059a688a"; :>> method = VerificationMethod::demo; :>> procedureText = "RealFsMut refuses to chown/chmod/create through a symlink (refuse_symlink), so the string-based protected-path guard can't be bypassed by a symlink → /etc. analyze resolves relative bind sources against the stack dir (not the process/server CWD). Suite green."; }
    part fixFixPathConfinementDoDR1 : TestResult { :>> id = "cc06a2e6-315d-4a5d-a110-846f29eb7937"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixDiscoverStacksResilienceDoD : Test { :>> id = "3da82a98-e84c-4f3a-8401-5cb64d5bded5"; :>> method = VerificationMethod::inspect; :>> procedureText = "discover_stacks skips an unreadable entry instead of aborting the whole scan; only a failure to open the root is fatal — so one bad subdir no longer empties the CLI/fleet listing."; }
    part fixDiscoverStacksResilienceDoDR1 : TestResult { :>> id = "77b80917-986c-406b-a271-a498c6a1576b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixOwnershipRootFalsePositiveDoD : Test { :>> id = "b1f4bdbd-bb8b-42fb-b30c-4c803d873880"; :>> method = VerificationMethod::demo; :>> procedureText = "detect_ownership suppresses RootOwned when the container expects PUID=0 (root is the correct owner) — new test asserts a root-owned path with expected (0,0) yields no finding. Suite green."; }
    part fixOwnershipRootFalsePositiveDoDR1 : TestResult { :>> id = "de2c692b-c81a-46c3-bc29-de92d5006e0d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixBackupTempOrphansDoD : Test { :>> id = "0f4ac43a-aa52-4b74-822f-579f698946c6"; :>> method = VerificationMethod::demo; :>> procedureText = "Backup temps are named `.yd-backups.partial-<pid>-<seq>` / `.old-` (new gitignore rules match them), GC'd at each backup start, removed on the publish-error path, and uniquely suffixed. A crash can no longer leave orphans that commit backup DATA into git. Suite green; clean build."; }
    part fixBackupTempOrphansDoDR1 : TestResult { :>> id = "dbc5575d-5ce2-4772-b3a6-1db7cf4df764"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixFlowDriftRestoreMissingDoD : Test { :>> id = "a7f9a427-2225-4322-892a-bdd73778a989"; :>> method = VerificationMethod::demo; :>> procedureText = "flow::run now captures the compose's pre-edit bytes and restores them if the image edit OR the snapshot fails — the iteration-2 claim is now actually implemented. New test forces a snapshot failure (non-git repo) and asserts the compose is restored to the original image with no uncommitted drift. Suite green."; }
    part fixFlowDriftRestoreMissingDoDR1 : TestResult { :>> id = "af130339-1d03-41e4-9977-d49920699e71"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixWebGetLockAndThreadsDoD : Test { :>> id = "07baaf4e-a5db-4a11-b53f-5d3042631770"; :>> method = VerificationMethod::demo; :>> procedureText = "normalize_stack_key lower-cases components (same stack serializes on a case-insensitive FS); request threads are capped (MAX_INFLIGHT + Drop-guarded counter, 503 over cap); ahead_behind reads cached refs (no GET side effect) with an explicit POST /api/git/fetch + UI Refresh. Suite + e2e green."; }
    part fixWebGetLockAndThreadsDoDR1 : TestResult { :>> id = "8fcb4f74-ab6a-4dfe-be1e-67aa6fa21569"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixUiSafetySignalsDoD : Test { :>> id = "4f31e67f-91c2-44db-83c8-1df0f4dcacdc"; :>> method = VerificationMethod::inspect; :>> procedureText = "Backup dialogs state copies are NOT point-in-time (stop the stack for consistency); a `warning:` stderr line and the health-NOT-verified note render as warn (not dim/plain) with a warn toast; the recovery-point chip reads 'integrity ✓' with a tooltip that it proves manifest-match, not a consistent snapshot. 28 Playwright e2e green."; }
    part fixUiSafetySignalsDoDR1 : TestResult { :>> id = "b52f0daf-a48a-4c2e-8abc-47fbfe0de530"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixSecretPartialRefFPDoD : Test { :>> id = "66ec1a68-6c40-4fcb-b569-3a6928163093"; :>> method = VerificationMethod::demo; :>> procedureText = "looks_interpolated treats a leading `$name` token as a variable reference regardless of trailing chars, so `$PREFIX-suffix` is no longer falsely Blocked; `$$secret`/`$2b$...` literals still flag. Guardrail tests green."; }
    part fixSecretPartialRefFPDoDR1 : TestResult { :>> id = "fe33ea51-6c29-431f-9284-707f088189d8"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification refineGate65 : Test { :>> id = "a399c14c-e431-4f9b-baef-047ab61833c2"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (18); charter to needSecureByDefault. Iteration 3: three hostile critiques (it2 regression, fresh modules, web/UI). Per the operator directive, ALL findings of every severity are implemented this iteration. The four backup-redesign follow-ons stay OPEN (feature-sized / Docker-integration-dependent) for a dedicated sprint."; }
    part refineGate65R1 : TestResult { :>> id = "cbf253aa-b07d-4cc9-bf5b-44977d316997"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification reviewGate65 : Test { :>> id = "e8deadaa-92cf-45ea-b5d1-f2bddb296883"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery. (correctness+honesty) the battery caught that iteration 2's fixUpgradeSnapshotDrift was recorded passing but never coded — now actually implemented + tested; the iteration-2 atomic-swap's own orphan-temp/gitignore regression is fixed. (security) network-volume spurious mkdir, import env_file traversal (read+write escape), and fix-path symlink bypass are all closed; the case-insensitive per-stack lock hole on the Windows host is closed. (human-factors) the UI no longer calls a live copy 'application-consistent', surfaces the not-point-in-time + health-not-verified signals as warnings, and moves the git fetch off a GET. (reviewers verified safe, unchanged: no XSS, JSON escaping, host-allowlist, lock eviction, TypeMismatch surfacing.) 147 lib + 22 cli + 28 Playwright tests green; clean release build, no warnings."; }
    part reviewGate65R1 : TestResult { :>> id = "310d9739-b63f-4c17-a116-1ad8fb2538e7"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification closeOutGate65 : Test { :>> id = "84452469-9405-4424-a28a-9000d7a51700"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: ten iteration-3 issues resolved. cargo build clean (no warnings); 147 lib + 22 cli + 28 Playwright tests green; keel validate + guard green. The four backup-redesign follow-ons remain OPEN and are the recommended scope for a dedicated sprint (Docker-integration validation needed). Iteration 3 complete — iteration 4 may begin."; }
    part closeOutGate65R1 : TestResult { :>> id = "2bebf225-1d65-4905-ad5e-2b3ed1b44fc3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "be4aa14"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }
}
