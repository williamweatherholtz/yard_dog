// =====================================================================
// YardDog — System Requirement for the self-update apply path.
// =====================================================================
package YardDogSelfUpdateApplyReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srSelfUpdateApply : SystemRequirement {
        :>> id = "f8ebad45-0925-4186-a83d-5db4b724d337";
        :>> title = "Download, verify, and atomically install a newer release";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "On `yd self-update --apply`, the system shall resolve the latest GitHub release, and if it is newer than the running version, download the platform asset and the published SHA256SUMS, refuse to install unless the asset's SHA256 matches, and then atomically replace the running executable (renaming the old binary aside as a .old backup so a running process is never overwritten in place). Without --apply it only reports status.";
        :>> rationale = "Completes needSelfUpdate beyond detection. SHA256 verification before an in-place swap keeps the highest-risk operation (replacing the running binary from the network) safe (needSecureByDefault); the rename-aside swap works on Windows and Unix while the process runs.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needSelfUpdate by srSelfUpdateApply;

    #Verify dependency from selfUpdateApplyDoD to srSelfUpdateApply;
    #Verify dependency from selfUpdateLiveDoD to srSelfUpdateApply;
}
