// =====================================================================
// YardDog — design discrepancy found 2026-07-27: git repo model.
// =====================================================================
package YardDogGitModelIssues {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    part issGitRepoModel : Issue {
        :>> id = "f6600077-63dd-4fad-80e0-aefbc0bc972a";
        :>> title = "Implementation versions each stack as its own git repo; decGitVersioning specifies a monorepo";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "decGitVersioning (accepted) says: 'a MONOREPO under the stacks root, one shared history'. But gitver::ensure_repo runs on each stack directory (deploy/save/restore operate per stack dir), so in practice every stack is its own repo. This surfaces now because git-remote sync (needRemoteConfigSync) is much more elegant with ONE repo + one remote for all config than with a remote per stack. Resolve the tension before building remote sync: either (a) implement the monorepo (version the stacks root, snapshot per-change with a scoped path) and migrate, or (b) supersede decGitVersioning with an accepted decision that per-stack repos are the model (and design remote sync accordingly). This is a direction/design call, so route it as a decision, not a silent code change.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    action decideGitRepoModel;
    #Resolves dependency from decideGitRepoModel to issGitRepoModel;
}
