// =====================================================================
// YardDog — System Requirement for git-remote sync of the config monorepo.
// =====================================================================
package YardDogGitRemoteReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srGitRemoteSync : SystemRequirement {
        :>> id = "987aa29e-9cc0-4351-9e57-4f40c00dcbb5";
        :>> title = "Connect the config monorepo to a git remote and push/pull";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall let the operator connect the config monorepo (the stacks-root repo) to a git remote (an https/ssh/git URL or a local/NAS bare-repo path), push and fast-forward-pull it, and see remote + ahead/behind status — from the browser (a global Git panel) and the CLI (`yd git`). Authentication is delegated to the operator's own git (credential helper / SSH agent); Yard Dog never handles or stores raw tokens. Secrets and data remain excluded from what is pushed.";
        :>> rationale = "Local-only versioning does not survive losing the box; offsite config sync makes the homelab recoverable and reproducible. Reusing the operator's existing git auth is both the elegant path (no re-entering credentials) and the secure one (no token storage in a no-auth loopback tool). The monorepo (one repo at the root) means one remote syncs all config.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needRemoteConfigSync by srGitRemoteSync;

    #Verify dependency from gitverRemoteDoD to srGitRemoteSync;
    #Verify dependency from gitRemoteLiveDoD to srGitRemoteSync;
}
