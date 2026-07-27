// =====================================================================
// YardDog — critique-battery findings (post-Sprint 22, 2026-07-27).
// The deploy/upgrade FSM (flow.rs) closed the S21 P0s; the antagonistic
// correctness lens over that new code surfaced two further gaps. Each Issue
// is triaged with a #Resolves edge to a product-backlog resolver.
// =====================================================================
package YardDogCritiqueIssuesS22 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    // -- CORRECTNESS (High): regress restores the file but not the running stack --
    part issRegressNoRedeploy : Issue {
        :>> id = "114c8b10-1143-41de-9b24-f1f9a3d078cf";
        :>> title = "Regress restores git config but does not redeploy — live containers stay on the failed version";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "flow::run's Regress phase calls gitver::restore to bring the compose file back to the last-good commit, but `docker compose up -d --wait` has already STARTED the new (unhealthy) containers, and restore does not redeploy. So after a failed deploy/upgrade the file says 'good' while the live stack is still running the broken version — the rollback is incomplete and silent. Fix: on regress, redeploy the restored config and verify it; if the rollback itself fails, surface a distinct RegressFailed outcome rather than reporting Regressed. (Pre-existing in safe_deploy; the FSM makes it explicit and testable.)";
        :>> discoveredInField = false;
        :>> severity = Severity::High;
    }

    // -- CORRECTNESS (Medium): upgrade guardrails run on pre-Apply compose --
    part issUpgradeGuardrailStale : Issue {
        :>> id = "2cb171f8-7d9f-4777-8eb0-44ba35c5573e";
        :>> title = "Upgrade guardrails evaluate the pre-Apply compose, missing changes the upgrade introduces";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "The Guardrails phase runs before Apply, reading the on-disk compose as-is. For a plain deploy that is the deployed artifact, but for an upgrade the meaningful artifact is the POST-Apply compose (with the new image). So an upgrade to a floating :latest tag or one that adds a plaintext secret is not blocked, and an upgrade that FIXES an existing violation would be wrongly blocked on stale content. Fix: for upgrades, evaluate guardrails on the post-Apply compose (or a rendered preview) so the check matches what is actually deployed.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- Triage: each finding resolved-by its product-backlog task --
    #Resolves dependency from regressRedeploys to issRegressNoRedeploy;
    #Resolves dependency from upgradeGuardrailPostApply to issUpgradeGuardrailStale;
}
