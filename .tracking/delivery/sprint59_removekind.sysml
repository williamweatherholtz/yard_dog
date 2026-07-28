// =====================================================================
// YardDog — Sprint 59 delivery: remove the workload "kind" from the Rust backend
// (classify, `yd classify`, `yd new --kind`, update-gating), completing
// decRemoveWorkloadKind. The cautious-update value is re-keyed off a persistent
// data mount, not a classified kind.
// =====================================================================
package Sprint59RemoveKind {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyRemoveKind : Story {
        :>> id = "9e816271-d76f-4a4a-8710-d246941d177d";
        :>> title = "Remove workload kind from the backend (classify / yd new --kind / update-gating)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyRemoveKind to needSimplicity;

    verification fixRemoveKindBackendDoD : Test { :>> id = "4234d2fe-b624-44c9-92cf-84a19d6ae3db"; :>> method = VerificationMethod::demo; :>> procedureText = "Workload kind is gone from the Rust backend: workload.rs no longer has WorkloadKind/classify/heuristic/disagreement (just parse_services -> {name, image, has_persistent_mount}); the `yd classify` command and `yd new --kind` flag are removed (one guardrail-clean starter template); web.rs stops sending `kind` in the /api/stack services JSON; updates.rs re-keys the cautious path off `has_persistent_mount` (a data-backed service is notify-only) instead of kind. classify.rs (MOUNT typing — the product pillar) is untouched. Verified: cargo build clean; 147 Rust tests green (workload/updates/instantiate/cli tests rewritten off kind; the update-policy test now asserts data-backed=notify, stateless=auto); 28 Playwright UI tests still green; README updated (no classify/--kind/kind-gated)."; }
    part fixRemoveKindBackendDoDR1 : TestResult { :>> id = "abbc84c7-d928-4ffd-949d-d66428675f1e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "04e51f0"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate59 : Test { :>> id = "c3261af1-2515-4aab-a66f-e9e6fe1423d8"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (3); charter to needSimplicity. Completes the accepted decRemoveWorkloadKind ('Remove entirely'): the UI dropped the Kind column in Sprint 56; this removes the backend. Plan: strip WorkloadKind/classify/`yd classify`/`yd new --kind`, re-key update caution off a data mount, keep MOUNT classify."; }
    part refineGate59R1 : TestResult { :>> id = "3f468289-d7e2-461a-ac41-740fd4ecff00"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "04e51f0"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate59 : Test { :>> id = "6b77b752-7c5a-4b13-868b-02dae634fcce"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery. (correctness) full removal verified by the whole test suite going green after rewriting the kind-dependent tests to the new model — no test was deleted to hide a gap; the update-policy safety property is preserved and re-proven (data-backed=notify, stateless=auto). (design) the fuzzy heuristic 'kind' taxonomy is gone; the one real safety use is now keyed off a concrete, honest signal (a declared volume). (naming clarity) MOUNT classify (classify.rs) and drift/backup 'kind' fields are deliberately NOT touched — only the workload taxonomy was removed. (docs) README + command help updated. (scope honesty) decRemoveWorkloadKind #Supersedes needWorkloadClassification + needInstantiateFromKind, so the burndown reflects the deliberate cut rather than carrying dead scope. (concision) removed ~200 lines of classification + a CLI command."; }
    part reviewGate59R1 : TestResult { :>> id = "360373aa-c1d5-4704-9dd6-e479746c6fd2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "04e51f0"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate59 : Test { :>> id = "ba1348d8-4d43-46c6-a6a8-41251d0898f7"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issRemoveKindBackend resolved; decRemoveWorkloadKind fully realized (UI + CLI + backend + update-gating). needWorkloadClassification + needInstantiateFromKind superseded. cargo build + 147 Rust tests + 28 Playwright UI tests green; keel validate + guard green; 0 open issues."; }
    part closeOutGate59R1 : TestResult { :>> id = "afe607fb-86da-4e33-8348-38ae5ebc11d9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "04e51f0"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
