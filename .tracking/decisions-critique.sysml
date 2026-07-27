// =====================================================================
// YardDog — process policy: the per-sprint critique battery (correctness-first).
// Accepted by wweatherholtz 2026-07-27. Project-level; no .engine changes.
// =====================================================================
package YardDogCritiquePolicy {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;

    part decCritiqueBattery : Decision {
        :>> id = "124874fc-bdb9-47d4-b9a3-73baefa187c9";
        :>> title = "Per-sprint critique battery: correctness-first quality gates -> Issues -> reprioritize before next sprint";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::accepted;
        :>> context = "The purpose of this project is to build SOUND, defensible software with accelerating momentum — not merely to deliver features. The priority ordering is: deployment < velocity < acceleration < direction, and direction IS correctness. Correctness is king. Sprints ship features but need systematic, antagonistic quality scrutiny so quality compounds (acceleration) and correctness (direction) always leads velocity/deployment.";
        :>> decision = "At each sprint's close/commit, run a CRITIQUE BATTERY (as practical for the sprint's content): (1) DOCUMENTATION — user-facing docs (README) reflect new/changed commands and behavior (engine doc-sync + a README pass); (2) HUMAN-FACTORS critique — does the feature give the operator the right indications/affordances (e.g. warn when a healthcheck is desired but absent); (3) DESIGN-PATTERN & STATE-MACHINE critique — is the design using EXPLICIT finite state machines wherever processing has states/transitions (prefer FSMs, make invalid transitions unrepresentable), and sound patterns; (4) CODE-CONCISION antagonistic critique (/simplify + refute-first); (5) CORRECTNESS antagonistic critique (/code-review + element-critique correctness lens). ALL findings are recorded as severity-tagged Issues, each with a #Resolves resolver. Before the next sprint kicks off, its refinement ASSESSES AND PRIORITIZES these Issues — correctness/high first, ahead of new feature work. Use the engine's element-critique / architectural-critique / requirement-quality / doc-sync machinery plus the /code-review and /simplify skills.";
        :>> rationale = "Antagonistic, independent (refute-first) critique catches what self-review misses (D0080). Making critique a per-sprint gate with issue-driven reprioritization is how correctness stays the top priority in practice, not just aspiration: a correctness/high finding may preempt planned feature work, which is correct because correctness > velocity > deployment. Compounding quality is the 'acceleration' the engine is built to enable.";
        :>> consequences = "Each sprint carries a critique pass; the next sprint's scope is partly set by the prior sprint's findings. Runs 'as practical' — a trivial sprint skips lenses that do not apply. Correctness/high findings can bump planned features. The critique loop reuses the engine's Issue + #Resolves machinery (D0077).";
    }

    verification decCritiqueBatteryAccept : Test { :>> id = "bd576965-ba0b-458d-8d55-52de04c7e806"; :>> method = VerificationMethod::confirmation; :>> procedureText = "wweatherholtz directed the per-sprint critique battery + correctness-first priority ordering (deployment < velocity < acceleration < direction=correctness) on 2026-07-27."; }
    part decCritiqueBatteryAcceptR1 : TestResult { :>> id = "0a3ad6ca-095f-4d7a-b9d8-8dddf02103b8"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9d8f6ff"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "wweatherholtz"; }
}
