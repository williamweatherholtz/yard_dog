// =====================================================================
// YardDog — System Requirement: a single unified preflight (yd doctor).
// =====================================================================
package YardDogPreflightReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srUnifiedPreflight : SystemRequirement {
        :>> id = "f66d11a0-e796-4b3d-b705-d7a7a2684fb1";
        :>> title = "One command reports a stack's readiness (preflight)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall provide a single preflight assessment that aggregates a stack's guardrail findings (block/warn counts) and lifecycle state into one go/no-go verdict: not-ready when any block-severity guardrail finding exists OR the stack is Archived; ready otherwise. The verdict shall be surfaced by one command with a success/failure exit code.";
        :>> rationale = "The user asked for simple. Rather than running check, inspect, and lifecycle separately and correlating them by hand, one preflight answers 'is this stack ready to deploy?' with a single verdict and exit code — the same block/archived rules the deploy flow enforces, made visible before the operator commits.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needSimplicity by srUnifiedPreflight;

    #Verify dependency from preflightCountsDoD to srUnifiedPreflight;
    #Verify dependency from preflightArchivedDoD to srUnifiedPreflight;
    #Verify dependency from doctorExitCodeDoD to srUnifiedPreflight;
}
