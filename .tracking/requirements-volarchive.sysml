// =====================================================================
// YardDog — System Requirement for named-volume archiving.
// =====================================================================
package YardDogVolArchiveReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srVolumeArchive : SystemRequirement {
        :>> id = "083a1d2b-26dd-4f60-8d51-8cd69db6b3a6";
        :>> title = "Archive a named Docker volume via a container tar";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall archive a named Docker volume by running a throwaway container that tars the volume's contents into the backup destination, so backup coverage includes named volumes (not just bind/host paths).";
        :>> rationale = "Named-volume data lives at a root-only path Docker manages; the portable way to capture it is a `docker run -v vol:/src ... tar` — completing the volume side of backup coverage that Coolify/Dokploy leave to bind mounts or managed DBs only.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needBackupCoverage by srVolumeArchive;

    #Verify dependency from volumeArchiveArgvDoD to srVolumeArchive;
    #Verify dependency from archiveVolumeDoD to srVolumeArchive;
    #Verify dependency from volumeArchiverDoD to srVolumeArchive;
}
