// =====================================================================
// YardDog — Sprint 3 delivery: start the backup pillar with a reviewable plan.
// Detect DB engines, enumerate a stack's persistent data (reusing the path
// classifier), and assemble an application-consistent backup plan the operator
// can review. No backup is executed yet — that is a later increment.
// =====================================================================
package Sprint3BackupPlan {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyBackupPlan : Story {
        :>> id = "eab16389-7a64-4373-894f-c9a9287f1e36";
        :>> title = "Backup planner: detect DB engines, enumerate stack data, assemble a reviewable plan";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyBackupPlan to needDbConsistentBackup;
    #CharteredBy dependency from storyBackupPlan to needBackupCoverage;

        action detectDbEngine;
        verification detectDbEngineDoD : Test { :>> id = "1d268d84-3b2b-464c-b8d9-1c5bd7cd1958"; :>> method = VerificationMethod::test; :>> procedureText = "From a service's image and environment, identify the DB engine (Postgres/MySQL/MariaDB/MongoDB/Redis) and its consistent-dump command template; unknown images yield None. Unit-tested per engine."; }
        part detectDbEngineDoDR1 : TestResult { :>> id = "fb56dc3d-b3bb-472f-84a6-07b2bf24cae1"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "589f81c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action enumerateStackData;
        verification enumerateStackDataDoD : Test { :>> id = "b6a2894b-f022-4624-b8d9-1c5bd88d37c4"; :>> method = VerificationMethod::test; :>> procedureText = "Given parsed+classified mounts, enumerate backup targets — named volumes and bind/host paths — excluding anonymous mounts; network mounts are included and flagged. Unit-tested."; }
        part enumerateStackDataDoDR1 : TestResult { :>> id = "812b4ec3-38fd-4a7f-84a6-07b2c0310cb5"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "589f81c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action backupPlan;
        verification backupPlanDoD : Test { :>> id = "d5af8b96-a64b-457c-b8d9-1c5bd95b0870"; :>> method = VerificationMethod::test; :>> procedureText = "Assemble a BackupPlan combining a dump step per detected DB and a data-copy step per enumerated volume/bind; unit-tested over a multi-service compose (a Postgres service + a bind + a named volume)."; }
        part backupPlanDoDR1 : TestResult { :>> id = "d32aedb3-fb7a-45b3-84a6-07b2c1887981"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "589f81c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliBackupPlan;
        verification cliBackupPlanDoD : Test { :>> id = "57579e5c-2ec1-4fe8-b8d9-1c5bda175520"; :>> method = VerificationMethod::test; :>> procedureText = "yd backup <compose> --plan prints the reviewable plan (dumps + data copies) and runs no backup; integration test asserts the plan lists the DB dump and the volume/bind targets."; }
        part cliBackupPlanDoDR1 : TestResult { :>> id = "d5f8f452-f4ec-425f-84a6-07b2c2da8365"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "589f81c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint3Backlog { }

    verification refineGate3 : Test { :>> id = "17e97afe-1b63-4587-99e7-35def06207b4"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: estimatedPoints set (5); charter edges set to the backup Needs; scope/acceptance clear; DoD tasks authored; reuses the Sprint 1-2 path core."; }
    part refineGate3R1 : TestResult { :>> id = "92322ff3-0fef-499c-b8d9-1c5bdcd36718"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "589f81c"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "ai"; }

    verification reviewGate3 : Test { :>> id = "fb70cad7-dde6-4b58-9aae-30f8db5a6b85"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 4/4 DoD tests green (25 lib + 3 integration, 0 warnings); DB-engine detection, stack-data enumeration, plan assembly, and `yd backup --plan` all working."; }
    part reviewGate3R1 : TestResult { :>> id = "5456de47-3707-404c-9dda-65d96f0f20d8"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "589f81c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate3 : Test { :>> id = "8c6dbb92-cdc6-4885-827d-57b961b9203d"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 4/4 DoD pass; backup SRs verified via #Verify edges."; }
    part closeOutGate3R1 : TestResult { :>> id = "382e91e1-caa6-45b0-9dda-65d97010536c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "589f81c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
