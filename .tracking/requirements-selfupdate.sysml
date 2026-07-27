// =====================================================================
// YardDog — System Requirement for program self-update (detection + seam).
// =====================================================================
package YardDogSelfUpdateReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srSelfUpdateCheck : SystemRequirement {
        :>> id = "d242be72-5727-4017-9cd9-7a3180ed4165";
        :>> title = "Detect a newer Yard Dog release and expose the apply as a seam";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall compare the running Yard Dog version to the latest release (via a release source) and report whether a newer version is available; the actual download-verify-atomic-replace apply is behind a seam (a later increment) so detection ships first.";
        :>> rationale = "Semantic version comparison + a release-source seam is the testable core of self-update; the platform-specific binary replacement (incl. the Windows exe-lock swap) plugs into the seam next, mirroring how the container-update registry client was staged.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needSelfUpdate by srSelfUpdateCheck;

    #Verify dependency from versionCompareDoD to srSelfUpdateCheck;
    #Verify dependency from selfUpdateCheckDoD to srSelfUpdateCheck;
}
