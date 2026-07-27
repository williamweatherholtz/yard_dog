// =====================================================================
// YardDog — integration finding from real-Docker testing (post-Sprint 31).
// The first live `yd deploy` against a Docker daemon failed: the versioning
// repo is mis-wired. Found only by running against a real daemon.
// =====================================================================
package YardDogIntegrationIssuesS32 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    // -- CORRECTNESS (High): the deploy versioning repo is never created / wrong dir --
    part issDeployRepoWiring : Issue {
        :>> id = "f49ea880-e064-485b-97c7-c47e716e6f4f";
        :>> title = "yd deploy fails: versioning repo (.yd-history) is never initialized and does not contain the compose";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "run_deploy passes stack_dir/.yd-history as the git repo to safe_deploy, but (1) that directory is never created or `git init`ed, so the first snapshot fails with 'cannot change to .yd-history: No such file or directory' and the deploy aborts; and (2) it is a separate subdirectory from where the compose lives (stack_dir), so even if initialized it would neither snapshot the compose nor restore it on rollback. Confirmed by the first live deploy against Docker 29.5 / Compose v5. Fix: version the stack directory itself (which gitver's .gitignore already scopes to exclude data/secrets/.yd-backups), ensuring the repo exists (gitver::ensure_repo) before the first snapshot; run_upgrade must ensure its --repo likewise.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }

    #Resolves dependency from fixDeployRepoWiring to issDeployRepoWiring;
}
