// =====================================================================
// YardDog — System Requirement for verify-gated data restore.
// =====================================================================
package YardDogDataRestoreReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srDataRestore : SystemRequirement {
        :>> id = "ddb73d90-c393-4503-8a23-86b0a511ecde";
        :>> title = "Restore a stack's data from a backup, verify-gated";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall restore a stack's bind-mounted data from a backup directory: it first verifies the backup against its checksum manifest and REFUSES to restore on any mismatch; then, only on explicit confirmation, copies each backed-up bind dir/file back to its source (resolved against the stack directory). Without confirmation it performs a dry run. DB dumps and named-volume archives are out of scope for this increment.";
        :>> rationale = "A backup is only worth its restore. Completing the backup pillar (capture -> verify -> RESTORE) is the headline value; refusing to restore a backup that fails integrity is the crucial safety property (never overwrite good-or-bad current data with corrupt backup data).";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    satisfy needRestoreVerification by srDataRestore;

    #Verify dependency from restoreCoreDoD to srDataRestore;
    #Verify dependency from restoreLiveDoD to srDataRestore;
}
