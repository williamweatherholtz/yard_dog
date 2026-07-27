// =====================================================================
// YardDog — System Requirement: the pre-change hook performs a real backup.
// =====================================================================
package YardDogPreChangeReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srRealPreChangeBackup : SystemRequirement {
        :>> id = "af216e4c-4212-4f49-b101-6b2dce965cb9";
        :>> title = "Pre-change hook performs an actual backup to a default location";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The pre-change backup hook shall build and execute a real backup of the stack (DB dumps + volume/bind copies) into a predictable, git-excluded default location before a deploy proceeds, so every change has a concrete recovery point — not a stub.";
        :>> rationale = "Sprint 8 wired the hook interface with a stub; this makes it real, closing the loop between deploy safety and the backup engine.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    satisfy needPreChangeBackup by srRealPreChangeBackup;

    #Verify dependency from defaultBackupDestDoD to srRealPreChangeBackup;
    #Verify dependency from backupStackDoD to srRealPreChangeBackup;
}
