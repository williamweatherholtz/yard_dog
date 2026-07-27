// =====================================================================
// YardDog — Sprint 23 delivery: regress/restore correctness (correctness-first).
// Resolves the remaining flow/gitver correctness Issues: complete the rollback
// (redeploy on regress), evaluate upgrade guardrails on the post-Apply compose,
// and make gitver::restore remove files added after the target commit. Work
// items are the ProductBacklog resolver tasks regressRedeploys,
// upgradeGuardrailPostApply, gitRestoreRemovesStray — closing issues
// issRegressNoRedeploy / issUpgradeGuardrailStale / issRestoreStray.
// =====================================================================
package Sprint23RegressFix {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyRegressFix : Story {
        :>> id = "c49affc8-71e7-49db-89e4-a31466642144";
        :>> title = "Complete rollback (redeploy on regress), post-Apply upgrade guardrails, stray-removing restore";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p0;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyRegressFix to needSafeDeploy;
    #CharteredBy dependency from storyRegressFix to needSafeUpgrade;

    verification refineGate23 : Test { :>> id = "4a3e9081-c5e8-4004-9f9a-adcf80979758"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edges set; scope = the three remaining flow/gitver correctness issues (regress redeploys the restored config or reports RegressFailed; upgrade guardrails run on post-Apply compose; restore removes stray files); work items are the ProductBacklog resolvers; correctness-first."; }
    part refineGate23R1 : TestResult { :>> id = "5cbedfe3-005c-4905-a527-290d4f809ead"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3beab6e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate23 : Test { :>> id = "328c115c-f24c-4d27-9575-8ae57bec4d81"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 resolvers green (82 lib + 19 integration, 0 build warnings). (1) flow::run Regress now restores AND redeploys the last-good config; if the rollback redeploy also fails it returns RegressFailed (CLI exit 4, CRITICAL message) instead of a false clean-roll. (2) Upgrade guardrails evaluate the post-Apply compose via the pure image_changed_yaml preview: an upgrade introducing a floating tag is blocked, one fixing a violation is not. (3) gitver::restore removes files absent from the target commit so a regress leaves no stray config. Existing regress tests updated to fail-once deployers to reflect the completed-rollback contract."; }
    part reviewGate23R1 : TestResult { :>> id = "07a1e1d2-3b4c-4d5e-9f60-718293a4b5c6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3beab6e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate23 : Test { :>> id = "1f2e3d4c-5b6a-4798-8071-627384950a1b"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 resolver DoD pass; issues issRegressNoRedeploy, issUpgradeGuardrailStale, issRestoreStray resolved via #Resolves. The rollback guarantee is now honest end-to-end (config + running stack). Remaining critique issues: issYamlReformat (Sprint 24) and issReadme (Sprint 25)."; }
    part closeOutGate23R1 : TestResult { :>> id = "2a3b4c5d-6e7f-4809-9182-73849506b1c2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3beab6e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
