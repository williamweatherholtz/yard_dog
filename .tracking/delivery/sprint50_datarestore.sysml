// =====================================================================
// YardDog — Sprint 50 delivery: verify-gated data restore (completes the backup
// pillar: capture -> verify -> RESTORE).
// =====================================================================
package Sprint50DataRestore {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyDataRestore : Story {
        :>> id = "420b41fe-2454-4551-9351-c71592dcc41f";
        :>> title = "Restore bind-mounted data from a backup (verify-gated) — CLI + UI";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p0;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyDataRestore to needRestoreVerification;
    #CharteredBy dependency from storyDataRestore to needBackupCoverage;

    action restoreCore;
    verification restoreCoreDoD : Test { :>> id = "5f5a5d48-a378-42f0-bd61-688e28dcbc5f"; :>> method = VerificationMethod::test; :>> procedureText = "backup::restore_bind_data verifies the backup against its manifest and returns VerifyFailed on any mismatch (refuses to restore corrupt data); with confirmation it copies each backed-up bind dir/file back to its source (resolved against the stack dir); without confirmation it is Skipped. Unit-tested: a corrupted bind file is restored to the backed-up content; a tampered backup (manifest mismatch) is refused."; }
    part restoreCoreDoDR1 : TestResult { :>> id = "9cafb92d-c809-459e-add8-95f1703b773c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "57d22d8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action restoreLive;
    verification restoreLiveDoD : Test { :>> id = "0ab4e153-56d9-4855-afaa-3f5180bf7ebd"; :>> method = VerificationMethod::demo; :>> procedureText = "Live end-to-end: `yd backup` a stack with bind data, corrupt the data, `yd restore <compose> --from .yd-backups` dry-runs, then `--yes` restores the ORIGINAL data (verified before overwrite); a tampered backup is REFUSED (exit 3). `yd restore` works from any cwd (resolves relative binds/dest against the stack dir). The UI Backups tab wires a Restore button (POST /api/backup/restore) behind an overwrite confirmation + the loopback/anti-CSRF gate."; }
    part restoreLiveDoDR1 : TestResult { :>> id = "478d93b8-e96f-4b10-b984-0f87c61b55f6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "57d22d8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    #Verify dependency from restoreLiveDoD to ucSmoothBackupRestore;

    verification refineGate50 : Test { :>> id = "be39dc4c-2fa6-43cc-a625-10f69217bd1d"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edges set; SR srDataRestore satisfies needRestoreVerification; scope = the missing half of the backup pillar (bind-data restore, verify-gated); DB dumps + volume archives are a documented later increment; correctness-first (verify before overwrite)."; }
    part refineGate50R1 : TestResult { :>> id = "1bbefa21-ded4-4ec9-976e-eedaca89cc1b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "57d22d8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate50 : Test { :>> id = "474fa590-48a1-4f6d-830b-fcd529335e30"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 2/2 DoD green (126 lib + 23 integration, 0 warnings). restore_bind_data is symmetric with backup (re-derives the bind->backup mapping from the compose, resolves relative binds against the stack dir), verifies before overwriting (refuses on mismatch), and is confirmation-gated. CLI `yd restore <compose> --from <dest> [--yes]` (dry-run by default) + web POST /api/backup/restore wired to the Backups tab behind an overwrite confirm. Verified live: data recovered after corruption; tampered backup refused. Bind-data is the safe 80%; DB/volume restore noted as follow-up."; }
    part reviewGate50R1 : TestResult { :>> id = "af97f9a6-e48d-48e3-a58e-9319a9babf40"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "57d22d8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate50 : Test { :>> id = "fa6a43ef-aa24-4373-af08-a7f67653df95"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass; srDataRestore verified; ucSmoothBackupRestore now fully realized. The backup pillar is complete end to end: capture -> verify -> mirror -> prune -> RESTORE. Follow-up: DB-dump re-import and named-volume-archive restore (docker/engine-specific)."; }
    part closeOutGate50R1 : TestResult { :>> id = "1d009dd6-fedb-4a75-97c7-69aaeaa3902e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "57d22d8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
