// =====================================================================
// YardDog — System Requirement for instantiating a new stack from a kind.
// =====================================================================
package YardDogInstantiateReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srInstantiateFromKind : SystemRequirement {
        :>> id = "a6172c3e-49ce-49ff-b415-6dee720dad27";
        :>> title = "Instantiate a new stack from a workload kind";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall scaffold a new stack from a chosen workload kind (datastore, web, worker, cron, proxy) producing a starter compose that passes the guardrails by construction — a pinned image, a healthcheck, a restart policy, and a resource limit; a datastore additionally gets a named volume. Instantiation shall write the compose into a per-name stack directory and set that stack's lifecycle to Draft.";
        :>> rationale = "Realizes the holistic 'what kind of container is this?' vision: rather than a blank file, the operator starts from a guardrail-clean, kind-appropriate template in Draft — intelligent management with preventative defaults baked in, keyed off the existing workload classification and lifecycle FSM.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needInstantiateFromKind by srInstantiateFromKind;

    #Verify dependency from scaffoldCleanDoD to srInstantiateFromKind;
    #Verify dependency from datastoreVolumeDoD to srInstantiateFromKind;
    #Verify dependency from instantiateDraftDoD to srInstantiateFromKind;
}
