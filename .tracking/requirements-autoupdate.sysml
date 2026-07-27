// =====================================================================
// YardDog — System Requirement for safe container auto-update.
// =====================================================================
package YardDogAutoUpdateReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srContainerAutoUpdate : SystemRequirement {
        :>> id = "3b76fa0d-587f-4e5e-9f22-6081c6bc023e";
        :>> title = "Detect image updates and produce a kind-gated update plan";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall detect when a service's image has a newer digest than the running one (via a registry client), and produce an update plan that, per service, either applies the update through the safe path or only notifies — gated by workload kind so a datastore is never auto-updated.";
        :>> rationale = "This is the safe/automated flavor of needSafeUpdates: the risky apply path (backup+snapshot+deploy+healthcheck+rollback+notify) already exists, so auto-update reduces to digest detection + a kind-gated policy + a plan. Datastores default to notify-only.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needContainerAutoUpdate by srContainerAutoUpdate;

    #Verify dependency from updateStatusDoD to srContainerAutoUpdate;
    #Verify dependency from updatePolicyDoD to srContainerAutoUpdate;
    #Verify dependency from buildUpdatePlanDoD to srContainerAutoUpdate;
}
