// =====================================================================
// YardDog — System Requirement for git-backed config versioning (realizes
// decGitVersioning; re-satisfies needVersionedCompose after srConfigHistory was
// superseded).
// =====================================================================
package YardDogGitVerReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srGitVersioning : SystemRequirement {
        :>> id = "4430d66d-4d40-4b10-b132-dc458ed9472b";
        :>> title = "Version stack config in a git repo (snapshot / history / restore)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall version stack configuration in a git repository — initialising it with an opinionated .gitignore (volume data + secret files excluded) and .gitattributes (eol=lf), snapshotting changes as commits by a single bot committer, listing history newest-first, and restoring a prior version by creating a NEW commit matching it (never a bare checkout leaving a detached/dirty tree).";
        :>> rationale = "Realizes decGitVersioning: git gives diffable history + tags/branches for archive/deprecate/instantiate, matches the files-on-disk pillar, and replaces the bespoke copy-based history. Guardrails (exclude data/secrets; restore-as-new-commit) keep it safe.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    satisfy needVersionedCompose by srGitVersioning;

    #Verify dependency from gitInitDoD to srGitVersioning;
    #Verify dependency from gitSnapshotHistoryDoD to srGitVersioning;
    #Verify dependency from gitRestoreDoD to srGitVersioning;
    #Verify dependency from migrateSafeDeployDoD to srGitVersioning;
}
