// =====================================================================
// YardDog — System Requirement for remote backup transport.
// =====================================================================
package YardDogTransportReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srRemoteTransport : SystemRequirement {
        :>> id = "3ebe2edc-04e6-44d4-89d0-ae37c924f2ed";
        :>> title = "Mirror a backup to a pluggable remote destination";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall mirror a local backup directory to a destination through a pluggable Transport — a local/mounted target now, and object storage / SFTP (e.g. via rclone) behind the same seam — so backups can live off-box.";
        :>> rationale = "Off-box copies are table-stakes for real backups (3-2-1); a Transport seam keeps the core testable and lets real cloud/SFTP transports drop in without touching the backup engine.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    satisfy needRemoteBackup by srRemoteTransport;

    #Verify dependency from transportSyncDoD to srRemoteTransport;
    #Verify dependency from localTransportDoD to srRemoteTransport;
}
