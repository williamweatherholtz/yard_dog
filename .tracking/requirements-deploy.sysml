// =====================================================================
// YardDog — System Requirements for safe deployment + pre-change backup.
// =====================================================================
package YardDogDeployReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srSafeDeploy : SystemRequirement {
        :>> id = "ee0ac076-39f0-4e15-adfb-1e7447eb0d8f";
        :>> title = "Atomic deploy: snapshot, deploy, roll back to last-good on failure";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "When applying a change to a stack, the system shall snapshot the current config, attempt the deploy, and on failure restore the previous last-good config — so a failed deploy never leaves a broken stack nor loses the operator's prior working configuration.";
        :>> rationale = "Failed deploys leaving a broken stack / losing edits is a repeatedly-cited pain across Portainer/Coolify/Dokku; snapshot-and-rollback makes deploys safe-by-default.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    requirement srPreChangeBackup : SystemRequirement {
        :>> id = "312b9b82-280b-4db3-8164-e93168397dad";
        :>> title = "Automatic backup before applying a change";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "Before a change is applied to a running stack, the system shall run a backup hook; if the pre-change backup fails, the deploy is aborted rather than risking unrecoverable data.";
        :>> rationale = "Ties backup integrity to deploy safety: a recovery point exists before every change, so a bad change is reversible.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    satisfy needSafeDeploy by srSafeDeploy;
    satisfy needPreChangeBackup by srPreChangeBackup;

    #Verify dependency from safeDeploySuccessDoD to srSafeDeploy;
    #Verify dependency from safeDeployRollbackDoD to srSafeDeploy;
    #Verify dependency from preChangeBackupHookDoD to srPreChangeBackup;
}
