// =====================================================================
// YardDog — System Requirement for backup integrity verification.
// =====================================================================
package YardDogBackupVerifyReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srBackupVerify : SystemRequirement {
        :>> id = "d27d3bb0-47b4-485b-81d0-37c243de1aa6";
        :>> title = "Record a checksum manifest and verify a backup's integrity on demand";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall record a checksum (SHA-256 + size) manifest at backup time and, on demand, verify that a backup still matches it — every file present and unchanged — surfacing any missing or corrupted entry, so a backup's restorability is demonstrated rather than assumed.";
        :>> rationale = "'An untested backup is not a backup' is a near-universal community lesson; automatic integrity verification is a clean, unserved differentiator and the foundation for restore confidence.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    satisfy needRestoreVerification by srBackupVerify;

    #Verify dependency from buildManifestDoD to srBackupVerify;
    #Verify dependency from verifyManifestDoD to srBackupVerify;
}
