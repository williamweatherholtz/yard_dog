// =====================================================================
// YardDog — System Requirement for backup retention + destination abstraction.
// =====================================================================
package YardDogBackupRetentionReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srRetentionStore : SystemRequirement {
        :>> id = "3b57595c-8b0d-442c-b88f-bdd78198d70e";
        :>> title = "Retain backups under a rotation policy over a pluggable destination";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall store backup snapshots via a destination abstraction and enforce a retention policy that keeps the N most recent snapshots and removes older ones. The abstraction admits a local destination now and a remote destination (object storage / SFTP) in a later increment.";
        :>> rationale = "Retention prevents unbounded growth and is table-stakes for real backups; the destination abstraction is the seam remote transports plug into, partially advancing the remote-destination need now and fully later.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    satisfy needRemoteBackup by srRetentionStore;

    // verify: Sprint 5 retention DoD tests are the evidence.
    #Verify dependency from retentionPolicyDoD to srRetentionStore;
    #Verify dependency from snapshotStoreDoD to srRetentionStore;
}
