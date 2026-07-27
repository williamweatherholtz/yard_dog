// =====================================================================
// YardDog — System Requirements for the backup pillar (Pillar 2). These fulfil
// the backup Needs; verification is COMPUTED from verify-edge Tests as the
// implementing sprints record passing evidence.
// =====================================================================
package YardDogBackupReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srDetectDbEngine : SystemRequirement {
        :>> id = "6d3f7149-b42c-4348-bbeb-6244cccf345a";
        :>> title = "Detect a container's database engine and its consistent-dump method";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> statement = "For each service, the system shall detect whether it runs a known database engine (PostgreSQL, MySQL/MariaDB, MongoDB, Redis) from its image and environment, and select the application-consistent dump method for that engine, so backups are logical dumps rather than copies of live files.";
        :>> rationale = "Copying live DB files corrupts backups (the near-universal community caution); automatic engine detection is what lets the tool dump consistently without the operator hand-wiring per-container commands.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    requirement srEnumerateStackData : SystemRequirement {
        :>> id = "f70f6a96-5be6-4014-9ddc-34ce42ea7c00";
        :>> title = "Enumerate all of a stack's persistent data for backup";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall enumerate every persistent-data target of a stack — named Docker volumes and bind/host paths (reusing the path classifier) — as the set to be backed up, distinguishing them from anonymous/ephemeral mounts.";
        :>> rationale = "Backups must cover named volumes AND bind mounts of arbitrary stacks (the explicit gap in Coolify/Dokploy); the path pillar already classifies mounts, so enumeration reuses it.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    requirement srBackupPlan : SystemRequirement {
        :>> id = "286241b9-7142-47d7-aba9-e7f8e3c3c363";
        :>> title = "Produce an application-consistent backup plan for a stack";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall produce, for a stack, a backup plan combining a consistent dump step per detected database and a data-copy step per enumerated volume/bind, which the operator can review before any backup runs.";
        :>> rationale = "A reviewable plan makes the backup transparent and safe (no surprise actions) and is the foundation the execution/remote/verify increments build on.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    satisfy needDbConsistentBackup by srDetectDbEngine;
    satisfy needBackupCoverage by srEnumerateStackData;
    satisfy needDbConsistentBackup by srBackupPlan;
    satisfy needBackupCoverage by srBackupPlan;

    // verify edges: Sprint 3 DoD tests are the evidence for each backup SR.
    #Verify dependency from detectDbEngineDoD to srDetectDbEngine;
    #Verify dependency from enumerateStackDataDoD to srEnumerateStackData;
    #Verify dependency from backupPlanDoD to srBackupPlan;
}
