// =====================================================================
// YardDog — System Requirement for config-vs-running drift detection.
// =====================================================================
package YardDogDriftReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srDriftDetection : SystemRequirement {
        :>> id = "5a281560-2f6a-47f9-840f-344f554da124";
        :>> title = "Detect drift between the declared compose and the running stack";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall compare the services/images declared in a stack's compose to the actually-running state (behind a running-state seam) and report drift — a declared service not running, a running service not declared, or a running image differing from the declared one — degrading gracefully when the running state is unavailable.";
        :>> rationale = "Portainer misreporting state after out-of-band docker changes is a repeatedly-cited trust-erosion driver; surfacing declared-vs-running drift is unclaimed. The diff is pure/testable; the running-state fetch (docker) plugs into the seam.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needDriftDetection by srDriftDetection;

    #Verify dependency from detectDriftDoD to srDriftDetection;
    #Verify dependency from driftReportDoD to srDriftDetection;
}
