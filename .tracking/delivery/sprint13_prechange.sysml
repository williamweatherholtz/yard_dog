// =====================================================================
// YardDog — Sprint 13 delivery: real pre-change backup.
// backup_stack (build+execute in one call) + a git-excluded default dest;
// main's pre-change hook now runs a real backup before deploy.
// =====================================================================
package Sprint13PreChange {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyPreChange : Story {
        :>> id = "ba985b66-945a-48f2-95ca-10ee5ea0076c";
        :>> title = "Real pre-change backup (backup_stack + default dest, wired into deploy)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyPreChange to needPreChangeBackup;

        action defaultBackupDest;
        verification defaultBackupDestDoD : Test { :>> id = "9822fd90-799e-4359-ae90-f2b9885dcd67"; :>> method = VerificationMethod::test; :>> procedureText = "default_backup_dest(stack_dir) returns a predictable, git-excluded location (stack_dir/.yd-backups) for pre-change backups; unit-tested."; }
        part defaultBackupDestDoDR1 : TestResult { :>> id = "6b433571-4f7c-4d5a-9a28-1310d5400222"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "dfdb62a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action backupStack;
        verification backupStackDoD : Test { :>> id = "e89ce18d-62a3-4a69-ae90-f2b9893260ef"; :>> method = VerificationMethod::test; :>> procedureText = "backup_stack(yaml, env, dest, confirmed, vols, net, runner, archiver) builds the plan and executes it in one call; fixture test asserts dumps+copies happen when confirmed and nothing when not."; }
        part backupStackDoDR1 : TestResult { :>> id = "4ed6db38-f216-4a8e-9a28-1310d6492202"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "dfdb62a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint13Backlog { }

    verification refineGate13 : Test { :>> id = "bb2ed389-83e9-49d0-a396-eba62379e584"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope clear; DoD tasks authored; reuses the backup engine + deploy hook."; }
    part refineGate13R1 : TestResult { :>> id = "1d3d3cca-8b82-46b5-ae90-f2b98be499cf"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "dfdb62a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate13 : Test { :>> id = "a576da02-c57d-454b-8be5-f54dad068bdc"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 2/2 DoD green (52 lib + 11 integration, 0 warnings); backup_stack + default_backup_dest; RealBackupHook now runs a real stack backup into .yd-backups before deploy."; }
    part reviewGate13R1 : TestResult { :>> id = "c721f0a6-51ff-42fa-ac7e-e1089c06a1fe"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "dfdb62a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate13 : Test { :>> id = "9ed2f5e8-5053-42b3-898d-a8e613810a2b"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass; srRealPreChangeBackup verified; the backup pillar is complete (plan/execute/verify/retain/remote/volumes + real pre-change hook)."; }
    part closeOutGate13R1 : TestResult { :>> id = "a28438c0-d11f-4652-ac7e-e1089d3bbda2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "dfdb62a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
