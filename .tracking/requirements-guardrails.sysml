// =====================================================================
// YardDog — System Requirement for pre-deploy policy guardrails.
// =====================================================================
package YardDogGuardrailReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srDeployGuardrails : SystemRequirement {
        :>> id = "b667fe08-4206-47c3-accb-7566b6efdb84";
        :>> title = "Run preventative policy guardrails over a compose stack";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall check a compose stack against preventative guardrails — image tags pinned (no floating :latest), healthcheck present, restart policy set, resource limits present, and no plaintext secrets — classifying each finding as warn or block, and shall fail (block) when any blocking finding is present.";
        :>> rationale = "Cheap policy-as-code catches the most common self-hosted outages/leaks before deploy; a warn/block split avoids alert fatigue. First increment is a flat ruleset; kind-modulation follows once workload classification lands.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needDeployGuardrails by srDeployGuardrails;

    #Verify dependency from guardrailChecksDoD to srDeployGuardrails;
    #Verify dependency from guardrailVerdictDoD to srDeployGuardrails;
}
