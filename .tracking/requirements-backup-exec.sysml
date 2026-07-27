// =====================================================================
// YardDog — System Requirement for executing a backup plan (Pillar 2, exec).
// =====================================================================
package YardDogBackupExecReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srExecuteBackup : SystemRequirement {
        :>> id = "9c95e75e-d20c-48f3-87f6-4620f4674cf7";
        :>> title = "Execute a backup plan to a destination, only on confirmation";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall execute a backup plan — running each database's consistent dump and copying each enumerated volume/bind — to a destination, only on explicit operator confirmation, producing a manifest of what was backed up; without confirmation it performs no writes.";
        :>> rationale = "Realizes the DB-consistent, full-coverage backup the plan describes; the confirmation gate keeps execution safe-by-default, consistent with the guided-remediation posture.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    satisfy needDbConsistentBackup by srExecuteBackup;
    satisfy needBackupCoverage by srExecuteBackup;

    // verify: the Sprint 4 execution DoD tests are the evidence.
    #Verify dependency from executeDumpsDoD to srExecuteBackup;
    #Verify dependency from backupManifestDoD to srExecuteBackup;
}
