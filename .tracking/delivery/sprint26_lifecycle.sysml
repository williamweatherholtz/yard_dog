// =====================================================================
// YardDog — Sprint 26 delivery: stack lifecycle FSM (needLifecycleStates).
// Draft -> Active -> Deprecated -> Archived with guarded transitions and
// per-stack persistence; the holistic archive/restore/deprecate lifecycle.
// =====================================================================
package Sprint26Lifecycle {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyLifecycle : Story {
        :>> id = "d6c141b3-5d67-4631-aef2-5ecded8442f5";
        :>> title = "Stack lifecycle FSM: Draft/Active/Deprecated/Archived with guarded transitions";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyLifecycle to needLifecycleStates;

    action lifecycleTransitions;
    verification lifecycleTransitionsDoD : Test { :>> id = "b90a21d0-5395-4c44-adab-04d67e2f29fc"; :>> method = VerificationMethod::test; :>> procedureText = "A pure next(state, event) implements the transition table: activate (Draft|Deprecated|Archived -> Active), deprecate (Active -> Deprecated), archive (Active|Deprecated|Draft -> Archived), restore (Archived -> Active); unit-tested over the valid table."; }
    part lifecycleTransitionsDoDR1 : TestResult { :>> id = "c9572912-e3a0-4f4f-a33a-96fc1df6c159"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bf5903e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action lifecycleGuards;
    verification lifecycleGuardsDoD : Test { :>> id = "460d1ae5-8de2-4ccd-b514-3792442cffb1"; :>> method = VerificationMethod::test; :>> procedureText = "Transitions not in the table are rejected (next returns None), e.g. deprecate on Draft/Archived, restore on Active/Draft/Deprecated; a disk transition() surfaces an invalid event as an error and does not mutate persisted state."; }
    part lifecycleGuardsDoDR1 : TestResult { :>> id = "535df812-303f-43b7-a33a-96fc1f54e9f9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bf5903e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action lifecyclePersist;
    verification lifecyclePersistDoD : Test { :>> id = "597f1d76-d5cf-4f7f-a93c-03efb968f598"; :>> method = VerificationMethod::test; :>> procedureText = "read_state defaults to Draft when unset; write_state + read_state round-trip each state; transition(dir, event) reads current, applies the guarded transition, persists, and returns the new state."; }
    part lifecyclePersistDoDR1 : TestResult { :>> id = "5c718cae-0a2b-49d3-a33a-96fc20abab49"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bf5903e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate26 : Test { :>> id = "06bc0e50-e9fe-4710-8ad3-0076d16fe980"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edge set; SR srLifecycleFsm authored and satisfies needLifecycleStates; three DoD tasks (transitions, guards, persistence) authored with #Verify edges; correctness-first, FSM-first."; }
    part refineGate26R1 : TestResult { :>> id = "e079012d-c26a-4d00-80d7-d89bdb6a7f9b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bf5903e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate26 : Test { :>> id = "c8724a57-4a48-414b-aac6-108886d76fdb"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (89 lib + 20 integration, 0 build warnings). lifecycle.rs models the stack lifecycle as an explicit FSM: a pure next(state,event) whose match IS the transition table, so invalid moves return None (unrepresentable); on-disk transition() reads current, applies the guard, persists to .yd-lifecycle, and errors (InvalidInput) without mutating state on an invalid event; read_state defaults to Draft. Wired `yd lifecycle --repo <dir> [--event ...]` with an integration test (default draft, activate, reject restore-from-active, state preserved). README updated (doc-sync)."; }
    part reviewGate26R1 : TestResult { :>> id = "b837ee17-b3ca-4094-a27b-3013f6a96f40"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bf5903e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate26 : Test { :>> id = "aa1c9f3e-7b62-4d84-9c05-2e6f1a0b3c47"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srLifecycleFsm verified via #Verify edges; needLifecycleStates now covered (verified tier). The holistic archive/restore/deprecate lifecycle the user asked for is built as a guarded FSM, giving needInstantiateFromKind a defined state to key off next."; }
    part closeOutGate26R1 : TestResult { :>> id = "bb2d0a4f-8c73-4e95-8d16-3f7a2b1c4d58"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bf5903e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
