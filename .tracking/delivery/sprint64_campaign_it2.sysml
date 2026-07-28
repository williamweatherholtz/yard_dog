// =====================================================================
// YardDog — Sprint 64 delivery: iteration 2 of the 5-iteration correctness
// campaign. Implements the fresh iteration-2 findings AND closes the five still-
// open battery-2 items the same work resolves (health-gate weak, health/timeout
// conflation, upgrade snapshot drift, secret-detection gaps, backup-no-quiesce
// [warning tier]). The larger backup-snapshot redesign is filed OPEN for
// iteration-3 refinement to prioritize (correctness-first).
// =====================================================================
package Sprint64CampaignIt2 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyCampaignIt2 : Story {
        :>> id = "86f2f604-f5cb-464c-ba24-8aaf196cbd16";
        :>> title = "Campaign iteration 2: backup safety, deploy-health honesty, dead-detector wiring, secret evasion, web/CLI round-2, it1 regressions";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 21;
    }

    #CharteredBy dependency from storyCampaignIt2 to needSecureByDefault;

    // ---- fresh iteration-2 resolvers -----------------------------------------

    verification fixBackupPruneDataLossDoD : Test { :>> id = "23ce0d15-e426-4b0d-91d7-d5713ea36b6c"; :>> method = VerificationMethod::demo; :>> procedureText = "LocalStore::list counts a subdir as a snapshot only if it holds its own manifest.json, so `prune` can never delete flat bind-DATA subdirs (new cli + unit tests assert a manifest-less data dir is never pruned); a data-only dest yields zero snapshots (run_prune says 'nothing to prune', not 'pruned 0'). Backups build into a temp sibling and swap in atomically only on success (previous backup kept until the new lands); the pre-change hook writes a manifest too. 145 lib + 22 cli tests green."; }
    part fixBackupPruneDataLossDoDR1 : TestResult { :>> id = "49e74dea-0ca4-4085-adcd-526cea0b1995"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixBackupFidelityDoD : Test { :>> id = "69e9922b-6760-447e-a24b-d503b6860fcd"; :>> method = VerificationMethod::demo; :>> procedureText = "Redis dump streams to stdout (`--rdb -`); copy_tree/copy_dir_all/verify-walk recreate symlinks and skip sockets/fifos instead of aborting; verify streams file hashes (no whole-file reads); the dump passes `docker compose -f <compose> exec` (right project regardless of CWD); a loud not-point-in-time warning prints at backup time. Full suite green."; }
    part fixBackupFidelityDoDR1 : TestResult { :>> id = "73911dbb-d423-4350-b53c-e5f84856e788"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixTypeMismatchDeadDoD : Test { :>> id = "3925a666-e70f-4ff8-8a78-3be84446ea91"; :>> method = VerificationMethod::demo; :>> procedureText = "build_report now emits Issue::TypeMismatch on a strong target-shape signal (trailing-slash ⇒ dir, recognized config extension ⇒ file) — new test proves file-where-dir and dir-where-file are flagged and an extensionless matching-kind bind is not. hostfs resolves symlink sources for kind + ownership and reports a dangling link as Missing. Tests green."; }
    part fixTypeMismatchDeadDoDR1 : TestResult { :>> id = "c06247db-c515-47d2-8a3b-4805b2583d65"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixWebGetSideEffectsDoD : Test { :>> id = "c51d9b04-eaaa-40e7-8b76-cc91f3a8958d"; :>> method = VerificationMethod::demo; :>> procedureText = "GET /api/git's fetch is serialized under the gitver index lock; /api/restore + CLI version-restore validate the sha; the per-stack lock key is lexically normalized (same stack ⇒ same mutex) and the map is bounded; /api/logs clamps tail + caps output at 1 MiB; sign-release reads the seed from $YD_SIGNING_KEY (argv opt-in) and the CI step no longer passes it on argv. Tests + clean build green."; }
    part fixWebGetSideEffectsDoDR1 : TestResult { :>> id = "3e1835cb-073e-4a1e-8d0f-c08334140405"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixRegressionIt1DoD : Test { :>> id = "0e6cb01b-c5a0-4088-9dee-863d326930f9"; :>> method = VerificationMethod::demo; :>> procedureText = "gitver IndexLock tracks ownership (Drop removes only a lock it created) and breaks stale locks by the lock FILE's mtime (no double-hold, no Windows cross-delete); lifecycle write_state uses a pid-unique temp; drift normalize_image handles index/registry-1.docker.io + tag-plus-digest (host:port preserved) with a test; guardrails blocks whole-disk udev symlinks (by-id/mapper/block) with a test; mounttable unescapes \\040 with a test; selfupdate treats a whitespace pubkey as unconfigured and distinguishes ChecksumMissing. Tests green."; }
    part fixRegressionIt1DoDR1 : TestResult { :>> id = "199d3f8a-142e-4fc3-993c-9ee2e1c81101"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixComposeInterpolationDoD : Test { :>> id = "5f39fd20-aa5b-450b-9f78-edfb24111969"; :>> method = VerificationMethod::demo; :>> procedureText = "interpolate() honors `$$` as an escaped literal `$` and captures `${...}` to the MATCHING brace so `${A:-${B}}` resolves — two new tests assert pass$$word/`$${VAR}` and the nested default. Green."; }
    part fixComposeInterpolationDoDR1 : TestResult { :>> id = "933f401a-2f5e-42f0-a087-c092ad5cd864"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    // ---- close the five still-open battery-2 items this work also resolves ----

    verification fixHealthGateWeakDoD : Test { :>> id = "3dbc8d50-cc89-4601-be1f-999bf59b1d5c"; :>> method = VerificationMethod::demo; :>> procedureText = "The deploy/upgrade Outcome now carries `health_unverified` (services with no healthcheck — running but not proven healthy); the FSM populates it at Decide and the CLI prints 'deployed but health NOT verified — no healthcheck on: …', so exit 0 no longer implies verified health. New flow test asserts the list. README exit-code section documents it."; }
    part fixHealthGateWeakDoDR1 : TestResult { :>> id = "6252c50a-f42e-43f5-b8a5-e55ab4bffba5"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixHealthTimeoutConflationDoD : Test { :>> id = "a8ccca3b-f12d-4ed6-b4aa-d152d6bf077c"; :>> method = VerificationMethod::demo; :>> procedureText = "A `--wait-timeout <secs>` flag threads into compose_up_args (test asserts --wait-timeout N is emitted); RealDeployer captures docker's stderr and classifies timeout vs unhealthy in the regress reason (and tells the operator to raise --wait-timeout for a slow start), rather than one opaque message."; }
    part fixHealthTimeoutConflationDoDR1 : TestResult { :>> id = "0a5bbb3f-d0ac-420f-aa63-f11f68f4afcd"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixUpgradeSnapshotDriftDoD : Test { :>> id = "55e59947-ff34-41ff-be06-a7f7382444a6"; :>> method = VerificationMethod::demo; :>> procedureText = "flow::run captures the compose's original bytes before the Apply image-edit and restores them if set_service_image OR the snapshot fails — so a snapshot failure can no longer leave uncommitted new-image drift on disk. Also anchored images preserve their `&anchor` and aliased images are declined (tests)."; }
    part fixUpgradeSnapshotDriftDoDR1 : TestResult { :>> id = "1c872c99-787c-45c3-bcf6-238bf85aa62f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixBackupNoQuiesceDoD : Test { :>> id = "0ef2d7a1-06a6-462e-bbdc-eb21e7635914"; :>> method = VerificationMethod::demo; :>> procedureText = "Minimum-viable tier (the critique's ship-now recommendation): backup prints a loud warning that bind/volume copies against live containers are NOT point-in-time consistent and that verify checks copy==manifest, not consistency. The full Quiescer stop/start trait is filed as issBackupQuiesceTrait (OPEN) for iteration-3."; }
    part fixBackupNoQuiesceDoDR1 : TestResult { :>> id = "9cc7761d-95a3-4ff8-8639-d9ea91da15c5"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixSecretDetectionGapsDoD : Test { :>> id = "b3c70355-9970-46a3-b95a-6f840066ef7d"; :>> method = VerificationMethod::demo; :>> procedureText = "is_plaintext no longer treats a `$$`-escaped literal or `$<digit>` as interpolation (only `${...}` or a whole-value `$NAME` reference), and a key-independent value-shape rule flags credentials embedded in a connection URL (postgres://u:p@h) as 'embedded-credentials' — with a portful host (redis://cache:6379) NOT tripping it. New test covers all four cases."; }
    part fixSecretDetectionGapsDoDR1 : TestResult { :>> id = "cf35a46c-aad5-45b4-9c65-43191954a89e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    // ---- sprint gates --------------------------------------------------------

    verification refineGate64 : Test { :>> id = "9b7fc9ff-7ac9-448c-b16e-ab7a99b8617a"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (21); charter to needSecureByDefault. Iteration 2 of the 5-iteration campaign: five hostile critiques over backup/verify/retention, the deploy/health FSM, fresh modules, an it1-regression pass, and web/CLI round-2. Per the operator's directive this iteration implements ALL findings of every severity; the four feature-sized backup-redesign items are filed OPEN (issBackupSnapshotLayer/QuiesceTrait/OwnershipPreserve/ManifestMetadata) for iteration-3 refinement to prioritize first."; }
    part refineGate64R1 : TestResult { :>> id = "0385e9ea-a380-4442-9e7a-0846868c512a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification reviewGate64 : Test { :>> id = "6d5f5f86-d5bd-456d-b79a-832f9518ac0e"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery. (correctness) the CRITICAL prune data-loss is closed by requiring a manifest.json marker (data subdirs can never be pruned), proven by a cli test with a manifest-less data dir; backups are now atomic + non-clobbering; the dead TypeMismatch detector is wired; the deploy health-gate no longer lets exit 0 imply verified health. (security) URL-embedded + $$-escaped secrets are caught; the signing seed leaves argv; /api/restore validates its sha; GET-fetch races are serialized. (honesty) four feature-sized backup items are filed OPEN and flagged for iteration-3, not silently claimed done; the quiesce warning is explicitly the minimum tier. (docs) README exit-code table reconciled across check/deploy/doctor/restore and documents the health-unverified note. (concision) shared helpers (publish_backup, expected_kind, has_embedded_credentials, normalize_stack_key). 145 lib + 22 cli tests green; clean release build, no warnings."; }
    part reviewGate64R1 : TestResult { :>> id = "30590b07-c23d-4f64-8030-c2678afa0936"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification closeOutGate64 : Test { :>> id = "54935af2-79a0-4907-a683-b266504b5b1f"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: eleven issues resolved (6 fresh + the 5 still-open battery-2 items); four backup-redesign follow-ons filed OPEN for iteration-3. cargo build clean (no warnings); 145 lib + 22 cli tests green; keel validate + guard green. Iteration 2 complete — iteration 3 may begin, refining the open backup Issues first."; }
    part closeOutGate64R1 : TestResult { :>> id = "429c523f-9a1b-4134-b67f-0d1ce8d2ae4c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9bb3fa0"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }
}
