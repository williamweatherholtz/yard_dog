// =====================================================================
// YardDog — System Requirement for update pinning (part of safe updates).
// =====================================================================
package YardDogPinningReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srUpdatePinning : SystemRequirement {
        :>> id = "8465a263-e38e-48bd-8bf2-bb49a13d69a2";
        :>> title = "Pin services so updates are held, and respect pins in the update plan";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The operator can pin a service so its updates are held; the tool persists pins and the update plan reports no action for a pinned service even when a newer image exists.";
        :>> rationale = "Pinning is the 'version-control' half of safe updates (the review, pre-update snapshot, and rollback are already delivered by `yd updates` + safe_deploy). It lets the operator freeze a service (e.g. a fragile app) while auto-updating the rest.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needSafeUpdates by srUpdatePinning;

    #Verify dependency from pinStoreDoD to srUpdatePinning;
    #Verify dependency from applyPinsDoD to srUpdatePinning;
}
