// =====================================================================
// YardDog — System Requirements for base compose management (files-on-disk
// stack discovery + versioned config history).
// =====================================================================
package YardDogComposeReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srStackDiscovery : SystemRequirement {
        :>> id = "53ff211b-93de-494d-8b39-3df61ff7a5cc";
        :>> title = "Discover compose stacks from disk, files remaining operator-owned";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall discover the compose stacks under a root directory — each subdirectory containing a compose file — and operate on those files in place, so the operator's compose/.env remain plain files on disk, never locked in the tool's own store.";
        :>> rationale = "Files-on-disk is the #1 reason self-hosters leave Portainer; discovery-over-adoption keeps the operator in control and is the surface the pillars attach to.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    requirement srConfigHistory : SystemRequirement {
        :>> id = "da72dfca-315b-49a2-b158-59876c85c57d";
        :>> title = "Version a stack's compose config with snapshot, list, and rollback";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall snapshot a stack's compose configuration to a version history, list prior versions, and roll back to any of them on confirmation — so a bad edit or failed change never loses the last-known-good config.";
        :>> rationale = "Versioned compose + rollback is a decade-old unmet ask (docker/compose #1174); a simple copy-based history delivers it without requiring git.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    satisfy needComposeManagement by srStackDiscovery;
    satisfy needFilesOnDisk by srStackDiscovery;
    satisfy needVersionedCompose by srConfigHistory;

    #Verify dependency from discoverStacksDoD to srStackDiscovery;
    #Verify dependency from snapshotConfigDoD to srConfigHistory;
    #Verify dependency from rollbackConfigDoD to srConfigHistory;
}
