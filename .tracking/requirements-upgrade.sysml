// =====================================================================
// YardDog — System Requirement for the one-shot safe upgrade flow.
// =====================================================================
package YardDogUpgradeReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srSafeUpgrade : SystemRequirement {
        :>> id = "54e7da01-a155-49ec-9568-945798e65c8c";
        :>> title = "Orchestrate a health-gated upgrade with regress-or-accept";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall upgrade a service to a target image by: running a pre-change backup, snapshotting the config in git, rewriting the service's image, deploying, and then — on a failed healthcheck regressing to the last-good config; on a passing healthcheck either accepting (auto or on user acceptance) or regressing if not accepted. Without confirmation it performs no change.";
        :>> rationale = "Composes existing, verified primitives (pre-change backup, git snapshot, deploy + healthcheck-gated rollback) into a single safe-upgrade verb; the only new logic is set-service-image and the accept/regress-even-if-healthy branch.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needSafeUpgrade by srSafeUpgrade;

    #Verify dependency from setServiceImageDoD to srSafeUpgrade;
    #Verify dependency from safeUpgradeDoD to srSafeUpgrade;
}
