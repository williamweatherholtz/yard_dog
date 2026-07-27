// =====================================================================
// YardDog — Sprint 8 delivery: safe deploy + pre-change backup.
// safe_deploy orchestrates pre-change backup -> config snapshot -> deploy ->
// rollback-to-last-good on failure, behind traits so it is testable without
// Docker. `yd deploy <stack>` (dry-run unless --yes).
// =====================================================================
package Sprint8Deploy {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyDeploy : Story {
        :>> id = "3188ec31-674d-43fd-a451-05b7c8fae233";
        :>> title = "Safe deploy (snapshot + rollback-on-failure) with pre-change backup hook";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyDeploy to needSafeDeploy;
    #CharteredBy dependency from storyDeploy to needPreChangeBackup;

        action safeDeploySuccess;
        verification safeDeploySuccessDoD : Test { :>> id = "0fb93a9b-c3c5-44a6-a7a3-a9f0a8abd42e"; :>> method = VerificationMethod::test; :>> procedureText = "safe_deploy snapshots the current config and, on a successful Deployer, returns Deployed with the snapshot recorded; unit-tested with a fixture deployer."; }
        part safeDeploySuccessDoDR1 : TestResult { :>> id = "31ee5ece-47c6-4d09-bc6c-2b603a84965f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b765cc"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action safeDeployRollback;
        verification safeDeployRollbackDoD : Test { :>> id = "22d34d4e-b3d4-4cfa-a7a3-a9f0a96e9e32"; :>> method = VerificationMethod::test; :>> procedureText = "on a failing Deployer, safe_deploy restores the previous last-good config to disk and returns RolledBack; unit-tested (compose reverts from the broken edit to the good version)."; }
        part safeDeployRollbackDoDR1 : TestResult { :>> id = "4dd89a1a-8db3-47a9-bc6c-2b603b99233f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b765cc"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action preChangeBackupHook;
        verification preChangeBackupHookDoD : Test { :>> id = "eca73a63-e6ed-4456-a7a3-a9f0aa3ff40a"; :>> method = VerificationMethod::test; :>> procedureText = "safe_deploy runs the pre-change backup hook before deploying; if the hook fails it returns BackupFailed and the Deployer is never called; unit-tested."; }
        part preChangeBackupHookDoDR1 : TestResult { :>> id = "66e97724-b202-4995-bc6c-2b603d043f1b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b765cc"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliDeploy;
        verification cliDeployDoD : Test { :>> id = "c39f11a5-42cb-4ece-a7a3-a9f0ab06c102"; :>> method = VerificationMethod::test; :>> procedureText = "yd deploy <compose> without --yes is a no-op (Skipped, no snapshot); integration test asserts no history is created on a dry run."; }
        part cliDeployDoDR1 : TestResult { :>> id = "5b9aad62-7be5-4ed5-bc6c-2b603e669e3f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b765cc"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint8Backlog { }

    verification refineGate8 : Test { :>> id = "36032b2e-f23e-4234-a9e1-48252fe40559"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edges set; scope clear; DoD tasks authored; reuses stacks config history."; }
    part refineGate8R1 : TestResult { :>> id = "34459e24-51e9-4d12-a7a3-a9f0adeb12e2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b765cc"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate8 : Test { :>> id = "14cc56b4-683b-4a77-87ba-e916975916c8"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 4/4 DoD green (41 lib + 8 integration, 0 warnings); safe_deploy backs up, snapshots, deploys, and rolls back to last-good on failure; `yd deploy` dry-run is a no-op."; }
    part reviewGate8R1 : TestResult { :>> id = "b7796897-7e68-4476-8355-afc7a79226de"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b765cc"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate8 : Test { :>> id = "949d3097-aeeb-4b64-80c6-110956ad666e"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 4/4 DoD pass; srSafeDeploy + srPreChangeBackup verified; needSafeDeploy/needPreChangeBackup covered."; }
    part closeOutGate8R1 : TestResult { :>> id = "d91bbb51-6529-4452-8355-afc7a8adafa2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b765cc"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
