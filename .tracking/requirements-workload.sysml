// =====================================================================
// YardDog — System Requirement for workload classification.
// =====================================================================
package YardDogWorkloadReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srWorkloadClassify : SystemRequirement {
        :>> id = "4c39762d-f423-409c-9463-134bd69d57a9";
        :>> title = "Classify each service into a workload kind (label-first, heuristic fallback)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "For each service the system shall determine a workload kind — datastore, web, worker, cron, proxy, or unknown — honoring an explicit label when present and otherwise inferring from image, published ports, mounts, healthcheck, and restart policy; the heuristic kind is exposed so a disagreement with an authored label can be surfaced.";
        :>> rationale = "A kind lets the tool apply the right behavior automatically (datastore => app-consistent backup + pin major + no auto-recreate; web => safe to recreate); two-tier (authored wins, heuristic proposes) matches the Backstage/OCI-label convention.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needWorkloadClassification by srWorkloadClassify;

    #Verify dependency from heuristicKindDoD to srWorkloadClassify;
    #Verify dependency from labelOverrideDoD to srWorkloadClassify;
    #Verify dependency from parseServicesDoD to srWorkloadClassify;
}
