// =====================================================================
// YardDog — product backlog: candidate work not yet pulled into a sprint.
// (Empty for now — the compose-interpolation fix was pulled into Sprint 2 as
// `interpolationForms`, which now carries the #Resolves edge to its Issue.)
// =====================================================================
package YardDogBacklog {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

        action fixHealthGateWait;
        verification fixHealthGateWaitDoD : Test { :>> id = "8a0c29e9-14a1-4a34-9c89-134f5a49ca44"; :>> method = VerificationMethod::test; :>> procedureText = "RealDeployer waits for health: docker compose up -d --wait (with timeout handling) so safe_deploy/safe_upgrade gate on actual healthchecks; a failed/timed-out wait is treated as unhealthy (regress)."; }
        part fixHealthGateWaitDoDR1 : TestResult { :>> id = "13c39372-480e-4f89-934d-a02ee30e8a2f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "323d525"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action deployRunsGuardrails;
        verification deployRunsGuardrailsDoD : Test { :>> id = "5f7da466-2a11-4c28-9c89-134f5b133848"; :>> method = VerificationMethod::test; :>> procedureText = "safe_deploy/safe_upgrade run run_guardrails before deploying and surface findings (especially a missing healthcheck, floating tag, plaintext secret); block or warn per policy."; }
        part deployRunsGuardrailsDoDR1 : TestResult { :>> id = "546790d3-bcce-42b5-934d-a02ee4ae5e23"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "323d525"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action preserveComposeFormat;
        verification preserveComposeFormatDoD : Test { :>> id = "59817f25-9837-4ebc-9c89-134f5bd8db98"; :>> method = VerificationMethod::test; :>> procedureText = "set_service_image edits the image in place preserving comments/formatting (no full serde_yaml round-trip); unit test asserts a comment survives an image change."; }
        action deployUpgradeFsm;
        verification deployUpgradeFsmDoD : Test { :>> id = "cb4e5066-4ecc-4170-9c89-134f5c96f150"; :>> method = VerificationMethod::test; :>> procedureText = "Model the deploy/upgrade lifecycle as an explicit FSM (states + guarded transitions, invalid transitions unrepresentable) shared by safe_deploy and safe_upgrade; unit-tested transition table."; }
        part deployUpgradeFsmDoDR1 : TestResult { :>> id = "1ce27fb1-4a26-41ad-934d-a02ee629d1fb"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "323d525"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action dedupeDeployUpgrade;
        verification dedupeDeployUpgradeDoD : Test { :>> id = "be411580-765d-4664-9c89-134f5d638fbc"; :>> method = VerificationMethod::test; :>> procedureText = "Extract the shared backup->snapshot->deploy->regress orchestration so safe_upgrade and safe_deploy do not duplicate it; behavior-preserving, tests still green."; }
        part dedupeDeployUpgradeDoDR1 : TestResult { :>> id = "bc9eae8c-81fd-4721-934d-a02ee798aff3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "323d525"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action gitRestoreRemovesStray;
        verification gitRestoreRemovesStrayDoD : Test { :>> id = "45b7eef9-efff-4e1c-9c89-134f5e259ddc"; :>> method = VerificationMethod::test; :>> procedureText = "gitver::restore also removes files not present in the target commit (true restore), not only restoring tracked content; unit test asserts a file added after the target is gone after restore."; }
        action addReadme;
        verification addReadmeDoD : Test { :>> id = "8ebaa895-28e7-4b44-9c89-134f5edebc18"; :>> method = VerificationMethod::test; :>> procedureText = "A README documents the yd commands + the safety model (backup/verify/git-versioning/safe-deploy/upgrade/guardrails); doc-sync keeps it current on commit."; }
        action regressRedeploys;
        verification regressRedeploysDoD : Test { :>> id = "a266f7a6-4821-47ea-a980-91bc36d827ae"; :>> method = VerificationMethod::test; :>> procedureText = "On regress, the FSM re-deploys the restored last-good config (not only restoring the file) so the live stack actually returns to the good version; unit test asserts the deployer is invoked a second time with the restored config and a still-failing rollback is surfaced (RegressFailed) rather than silently leaving broken containers up."; }
        action upgradeGuardrailPostApply;
        verification upgradeGuardrailPostApplyDoD : Test { :>> id = "64403433-8678-49b8-a557-f5961121d095"; :>> method = VerificationMethod::test; :>> procedureText = "For an upgrade, guardrails evaluate the POST-Apply compose (the image actually being deployed), so an upgrade that introduces a floating tag / plaintext secret is blocked and one that fixes a violation is not; unit test covers both directions."; }
    action def ProductBacklog { }
}
