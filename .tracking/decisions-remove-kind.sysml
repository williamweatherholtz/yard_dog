// =====================================================================
// YardDog — Decision: remove the user-facing workload "kind" concept entirely.
// =====================================================================
package YardDogRemoveKindDecision {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part decRemoveWorkloadKind : Decision {
        :>> id = "c598ad7d-0d7b-405e-bab2-9ba80b7a7f88";
        :>> title = "Remove the workload 'kind' (web/datastore/worker/cron/proxy) entirely";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::accepted;
        :>> context = "The tool classified each service into a workload kind (datastore/web/worker/cron/proxy), surfaced it as a Kind column in the UI, took a --kind flag on `yd new`, exposed `yd classify`, and used kind to gate update actions (datastores got a more cautious update path). The operator judged the kind concept adds no discernible value ('I don't see how it could') and chose to remove it entirely.";
        :>> decision = "Remove workload-kind everywhere: the UI Kind column and kind-tinted mount coloring, the `yd new --kind` flag and kind-specific templates, the `yd classify` command, and the kind-gated update logic. `yd new` produces one sensible guardrail-clean template regardless of workload; update actions no longer branch on kind. The drift 'kind' (changed/missing) is a DIFFERENT field and stays.";
        :>> rationale = "Simplicity over a taxonomy the operator doesn't find useful. The classification was a guess from image/name heuristics and could mislead; removing it shrinks the model and the UI. The one real function it served — a more cautious update path for datastores — is a safety property better keyed off concrete signals (a service having a named/volume-backed data mount) than off a fuzzy 'kind' label, or dropped if it doesn't earn its keep. Chosen by the human operator on 2026-07-27 ('Remove entirely').";
        :>> consequences = "classify.rs and the `yd classify` command are removed; `yd new` drops --kind and ships one template; the updates path no longer gates on kind; web.rs stops sending `kind` in the services JSON and the UI drops the Kind column. Rust tests referencing kind are removed/rewritten. If the datastore-update caution proves worth keeping, re-introduce it keyed on data-mount presence, not kind (new decision).";
    }

    verification decRemoveWorkloadKindAccept : Test { :>> id = "f984d75c-40f2-4740-aeb9-9fecd5e5af44"; :>> method = VerificationMethod::confirmation; :>> procedureText = "Human operator wweatherholtz selected 'Remove entirely' for the workload-kind question on 2026-07-27, accepting that kind is removed from the UI, the CLI (`yd new --kind`, `yd classify`), and the update-gating logic."; }
    part decRemoveWorkloadKindAcceptR1 : TestResult { :>> id = "fa521198-b613-4eb2-a03c-fe07a499d567"; :>> outcome = VerdictKind::pass; :>> judgedAt = "2026-07-27"; :>> judgedBy = "wweatherholtz"; }

    // This scope-cut decision supersedes the two Needs the workload-kind feature served.
    // The cautious-update value they carried is preserved, re-keyed off a persistent
    // data mount (a concrete signal) rather than a classified "kind".
    #Supersede dependency from decRemoveWorkloadKind to needWorkloadClassification;
    #Supersede dependency from decRemoveWorkloadKind to needInstantiateFromKind;
}
