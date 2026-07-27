// =====================================================================
// YardDog — Decision: adopt git as the config-versioning substrate, superseding
// the Sprint 7 copy-based config history (srConfigHistory). PROPOSED pending
// human sign-off. Grounded in the 2026-07-27 research into git-as-substrate.
// =====================================================================
package YardDogGitDecision {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part decGitVersioning : Decision {
        :>> id = "34790dc3-8e82-4297-82d1-45654412919d";
        :>> title = "Version stack config in git (monorepo), superseding the copy-based history";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::accepted;
        :>> context = "Sprint 7 shipped a copy-based config history (srConfigHistory: numbered .history/ snapshots + rollback). The operator wants a strongly-versioned, holistic system (archive/restore/deprecate/instantiate) and asked whether git can own versioning. Research (2026-07-27) confirmed git is the proven substrate (Komodo/Portainer/Argo/Flux) but forces specific guardrails, and that config versioning is a different axis from data/state.";
        :>> decision = "Adopt git as the config-versioning substrate for stacks. Layout: a MONOREPO under the stacks root, one shared history, tags for archive points. The tool is the sole bot committer (author 'Yard Dog', real-user trailer), writes are serialized, user hand-edits enter via an explicit import step, and restore is 'create a new commit matching version N' — never a bare checkout that leaves detached-HEAD/dirty. Ship an opinionated .gitignore (exclude volume/data dirs + secret files) and a .gitattributes (eol=lf, exec bit); the tool refuses to stage data/secret paths and reasserts ownership on checkout. Secrets are EXCLUDED now; encrypted-in-git via SOPS/age is a later increment. Config versioning stays DISTINCT from data backup (git = config time-travel; the backup pillar = data restore). Retire/replace the copy-based srConfigHistory. Rust: git2 (libgit2) preferred, or shell out to `git`; final choice at implementation.";
        :>> rationale = "Git gives diffable history, tags/branches (archive/deprecate/instantiate), offsite remotes, and aligns with the files-on-disk pillar — far better than a bespoke numbered-copy scheme, and not worth reinventing. The downsides are all guardrail-manageable and several (data exclusion, secrets discipline, drift) are wanted regardless. Monorepo chosen by the operator for single-host simplicity and atomic cross-stack history; the accepted tradeoff is a wider blast radius for a leaked secret/data and a shared conflict surface, mitigated by the opinionated ignore + single committer + serialized writes.";
        :>> consequences = "srConfigHistory (copy-based) is superseded and its stacks.rs history code retired in a future sprint, replaced by a git-backed versioning requirement. New guardrail need needSecretDataSafety becomes must-have. The backup pillar remains the DATA axis and needDriftDetection (git-intended vs actually-running) remains open. Monorepo secret exposure is bounded by never committing plaintext (needSecretDataSafety).";
    }

    verification decGitVersioningAccept : Test { :>> id = "5a66352c-88e3-45f1-8731-e7a3d8a561a1"; :>> method = VerificationMethod::confirmation; :>> procedureText = "wweatherholtz accepted decGitVersioning on 2026-07-27: adopt git (monorepo, sole bot committer, data/secrets excluded, config distinct from data backup), superseding the copy-based srConfigHistory."; }
    part decGitVersioningAcceptR1 : TestResult { :>> id = "52a7da6b-ecf5-4b7f-9079-20878a9f6bc2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "5aa64f9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "wweatherholtz"; }

    // Scope: this Decision supersedes the copy-based config-history requirement.
    #Supersede dependency from decGitVersioning to srConfigHistory;
}
