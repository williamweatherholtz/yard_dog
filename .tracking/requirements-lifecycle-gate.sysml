// =====================================================================
// YardDog — System Requirement: lifecycle-gated deploy/upgrade.
// =====================================================================
package YardDogLifecycleGateReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srLifecycleGate : SystemRequirement {
        :>> id = "7e9632e6-48e8-4ae6-b17d-a9f066c28b0c";
        :>> title = "Refuse to deploy or upgrade an archived stack";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall refuse to deploy or upgrade a stack whose lifecycle state is Archived, returning a Blocked outcome without applying any change, and shall proceed normally for Draft, Active, and Deprecated stacks. The archived block shall take effect before backup/apply so no side effects occur.";
        :>> rationale = "An archived stack is retired; silently redeploying it would resurrect a stack the operator deliberately shut down. Gating the deploy flow on the lifecycle FSM turns the lifecycle states into a real preventative guardrail, not just a label — the operator must explicitly restore before deploying.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needSafeDeploy by srLifecycleGate;

    #Verify dependency from archivedBlocksDoD to srLifecycleGate;
    #Verify dependency from activeProceedsDoD to srLifecycleGate;
}
