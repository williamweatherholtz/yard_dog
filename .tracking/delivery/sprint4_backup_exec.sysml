// =====================================================================
// YardDog — Sprint 4 delivery: execute a backup plan to a local destination.
// Runs DB dumps (via a CommandRunner) and copies volumes/binds (via an
// Archiver), only on confirmation, producing a manifest. Traits keep it
// unit-testable without Docker; `yd backup --run --dest DIR` wires it up.
// =====================================================================
package Sprint4BackupExec {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyBackupExec : Story {
        :>> id = "6e496b86-dd0b-4ce2-be23-8878774f748e";
        :>> title = "Execute a backup plan to a destination (dumps + copies), confirmation-gated";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyBackupExec to needDbConsistentBackup;
    #CharteredBy dependency from storyBackupExec to needBackupCoverage;

        action executeDumps;
        verification executeDumpsDoD : Test { :>> id = "351125cc-b803-453a-b4e4-c9dd230a81c6"; :>> method = VerificationMethod::test; :>> procedureText = "execute_plan runs each DumpStep via a CommandRunner writing to the destination; a recording-runner test asserts the Postgres dump command is invoked for the db service and that nothing runs without confirmation."; }
        part executeDumpsDoDR1 : TestResult { :>> id = "6d786ddd-e11c-4344-8c13-0a8bb58508d4"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b38e47e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action copyTargets;
        verification copyTargetsDoD : Test { :>> id = "b5e25946-b233-4f6e-b4e4-c9dd23d3700e"; :>> method = VerificationMethod::test; :>> procedureText = "execute_plan copies each BackupTarget via an Archiver into the destination; a recording-archiver test asserts each volume/bind target is archived exactly once."; }
        part copyTargetsDoDR1 : TestResult { :>> id = "b784c03a-a693-4498-8c13-0a8bb6eebbc0"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b38e47e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action backupManifest;
        verification backupManifestDoD : Test { :>> id = "968bee3f-ad6a-4412-b4e4-c9dd249d3402"; :>> method = VerificationMethod::test; :>> procedureText = "execute_plan returns a manifest listing each completed dump and copy; unit-tested that the manifest matches the plan when confirmed and is empty when not confirmed."; }
        part backupManifestDoDR1 : TestResult { :>> id = "ca175918-218e-40ec-8c13-0a8bb86dc8b0"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b38e47e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliBackupRun;
        verification cliBackupRunDoD : Test { :>> id = "8a4a3b02-3b15-4d36-b4e4-c9dd255d8aae"; :>> method = VerificationMethod::test; :>> procedureText = "yd backup <compose> --run --dest DIR copies a bind's data into DIR; an integration test over tempdirs asserts the file is present after --run and absent without it."; }
        part cliBackupRunDoDR1 : TestResult { :>> id = "695cc0aa-6a17-4a3c-8c13-0a8bb9ec6fac"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b38e47e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint4Backlog { }

    verification refineGate4 : Test { :>> id = "a4d700b2-b90a-49ea-9ed9-e244aa17dfd3"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edges set; scope clear; DoD tasks authored; builds on the Sprint 3 planner."; }
    part refineGate4R1 : TestResult { :>> id = "1237dbc4-a405-4112-b4e4-c9dd2758b95a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b38e47e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate4 : Test { :>> id = "f742c039-0af1-4b55-84a6-5878c583e113"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 4/4 DoD green (27 lib + 4 integration, 0 warnings); execute_plan runs dumps + copies on confirmation only, `yd backup --run --dest` copies bind data end-to-end."; }
    part reviewGate4R1 : TestResult { :>> id = "396ae419-557e-4f25-a547-68b24e632753"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b38e47e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate4 : Test { :>> id = "0482e7fb-3c9c-4603-9484-ca9aba4cb30a"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 4/4 DoD pass; srExecuteBackup verified."; }
    part closeOutGate4R1 : TestResult { :>> id = "aa778554-ce24-49b1-a547-68b24f7207db"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b38e47e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
