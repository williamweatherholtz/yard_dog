// =====================================================================
// YardDog — Sprint 46 delivery: implement the monorepo versioning model.
// Resolves issGitRepoModel per the operator's decision (one repo at the stacks
// root; per-stack operations scoped by path) — realizing decGitVersioning.
// =====================================================================
package Sprint46Monorepo {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyMonorepo : Story {
        :>> id = "ef93afea-328e-4fbf-9a04-9825cf512791";
        :>> title = "Monorepo config versioning: one repo at the stacks root, per-stack scoped ops";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 8;
    }

    #CharteredBy dependency from storyMonorepo to needVersionedCompose;
    #CharteredBy dependency from storyMonorepo to needRemoteConfigSync;

    // resolver for issGitRepoModel (action decideGitRepoModel in issues-gitmodel.sysml)
    verification decideGitRepoModelDoD : Test { :>> id = "f4002dac-47e8-4b50-875a-65a2e4d5a684"; :>> method = VerificationMethod::demo; :>> procedureText = "The operator chose the monorepo model (matching decGitVersioning). Implemented and verified live: `yd serve --root R` creates ONE .git at R (no per-stack .git); deploying/saving a stack snapshots ONLY that stack's path in the shared repo; /api/history and /api/diff are scoped per stack; both stacks are tracked in the single repo. The gitver::monorepo_scoped_ops_isolate_stacks unit test proves scoped snapshot/history/diff/restore isolate stacks."; }
    part decideGitRepoModelDoDR1 : TestResult { :>> id = "74dfc881-d18f-4ba4-bdd3-c692aa96810e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "261763a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action scopedGitver;
    verification scopedGitverDoD : Test { :>> id = "6cb41669-3834-44de-8326-b7d204904532"; :>> method = VerificationMethod::test; :>> procedureText = "gitver gains path-scoped snapshot_scoped/history_scoped/diff_scoped/restore_scoped (rel='.' behaves as whole-repo, so single-stack callers are unchanged) + repo_root(start). flow, safe_deploy/safe_upgrade (via repo_root), and the web save/history/diff/restore use root + stack rel-path. Unit-tested (monorepo isolation) and all existing flow/deploy/upgrade tests stay green via the '.' backward-compat path."; }
    part scopedGitverDoDR1 : TestResult { :>> id = "1fd7383a-1015-4161-a068-d26f7592c288"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "261763a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action monorepoIgnoreFix;
    verification monorepoIgnoreFixDoD : Test { :>> id = "bfd9c01a-4a5d-4752-91c1-dd559fc6ea5d"; :>> method = VerificationMethod::demo; :>> procedureText = "The opinionated .gitignore's data-dir names (data/, db/, pgdata/) collided with monorepo STACK directories of the same name. Anchored them one/two levels deep (*/data/, */db/, */pgdata/, */*/...) so a top-level stack named 'db' is versioned while a stack's own data subdir is not; data FILES (.env, *.sqlite, *.db, secrets) stay excluded anywhere. Verified live: saving a stack named 'db' now succeeds."; }
    part monorepoIgnoreFixDoDR1 : TestResult { :>> id = "24de560b-555a-4001-9dc2-d8b92c3a271d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "261763a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate46 : Test { :>> id = "3104c819-cdc6-40b5-b985-4057359f4706"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (8); charter edges set; scope per human decision (monorepo) = implement decGitVersioning's monorepo model, resolving issGitRepoModel, and unblocking git-remote sync (needRemoteConfigSync)."; }
    part refineGate46R1 : TestResult { :>> id = "040c2fd1-a95a-4d7e-94a5-7ffeab8a0d23"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "261763a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate46 : Test { :>> id = "4fb7096f-c702-4269-bb76-54d0cb59855b"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (122 lib + 23 integration + live e2e rollback, 0 warnings). Backward-compatible migration: the single-stack path (rel='.') keeps all flow/deploy/upgrade safety tests green; the live single-stack auto-rollback e2e still passes. Live monorepo: one root repo, per-stack scoped snapshot/history/diff, isolation confirmed, and the data-ignore/stack-name collision fixed. Realizes the accepted decGitVersioning and unblocks git-remote sync."; }
    part reviewGate46R1 : TestResult { :>> id = "be3ab8c5-10f7-41be-8893-929533d2df9f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "261763a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate46 : Test { :>> id = "e22b24dc-386f-4e47-8102-e6dfb1e8b15b"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; issGitRepoModel resolved (monorepo implemented). Config now versions in one repo at the stacks root with per-stack scoped history/diff/restore — the elegant substrate for git-remote sync (one remote for all config), which is now unblocked (ucGitRemote / needRemoteConfigSync)."; }
    part closeOutGate46R1 : TestResult { :>> id = "da4cd579-b51d-4c37-b27a-6b51ac09906f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "261763a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
