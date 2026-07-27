// =====================================================================
// YardDog — project process-policy Decisions (how THIS project runs the
// delivery loop). These are project-level choices authored in .tracking/; they
// do not modify the engine (.engine/), only how this project records gates and
// paces work. Accepted by wweatherholtz 2026-07-26.
// =====================================================================
package YardDogProcess {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;

    part decNoReviewSignoff : Decision {
        :>> id = "b65878e7-3f3e-4c9f-bba0-4e55fa4fa57d";
        :>> title = "Sprint reviews are AI-judged inspections; no blocking human sign-off gate";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::accepted;
        :>> context = "This is a solo+AI project on Claude Enterprise, where sessions can run very long. A blocking human review-confirmation gate at the end of every sprint is high friction and stalls autonomous delivery. Honest state does not depend on that gate: coverage, traceability, and the honest-state guards are computed, and any sprint's evidence remains reviewable after the fact (the sitting-review is explicitly batchable/async, D0049).";
        :>> decision = "For this project, the sprint review gate is recorded as a method=inspect verification judged by the AI, not a method=confirmation gate requiring human attestation. Human sign-off is NOT required to close a sprint. The human supervises asynchronously via `keel orient` / `keel coverage` and may record an explicit sitting-review at their own cadence. This relaxation applies ONLY to sprint reviews — Decision acceptance still requires a genuine human attestation (D0016/D0066; guard:confirmation-authenticity), never AI-fabricated.";
        :>> rationale = "Removes the main blocker to long autonomous runs while preserving honesty: the engine never hard-mandated a human review gate (sitting-coverage is a VIEW, not a gate), so recording review as an AI inspection is within the engine's rules and needs no `.engine/` edit. Alternatives considered: (a) edit the Delivery workflow in `.engine/` — rejected, the engine is the tool and must not be modified; (b) keep human review but batch it — rejected as still blocking. Criteria: honest-state preserved x no engine edit x unblocks autonomy.";
        :>> consequences = "Future sprints record `reviewGate` as method=inspect / judgedBy=ai and close without waiting on the human. The human can still review any sprint's computed evidence and record a sitting-review later. Decision-acceptance sign-off is unaffected and stays human-attested.";
    }

    part decAutonomousCadence : Decision {
        :>> id = "435b4aa6-d3f9-499a-9b96-c79d597a0097";
        :>> title = "Run at least 5 sprints per session before pausing for confirmation";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::accepted;
        :>> context = "Claude Enterprise supports very long sessions; the human wants sustained autonomous delivery rather than per-sprint check-ins.";
        :>> decision = "The AI drives the full delivery loop (refine -> standup -> implement -> AI-review -> closeOut -> retro) for at least 5 sprints in a row before returning for confirmation, selecting each next sprint's scope from the prioritized Needs. It pauses early only for a genuine blocker: a hard-to-reverse choice not derivable from the recorded Needs/Decisions, an ambiguity that changes direction, or a failure it cannot resolve.";
        :>> rationale = "Maximizes throughput on a solo+AI Enterprise setup. Pairs with decNoReviewSignoff (no blocking review gate). The human retains control via async orient/coverage review and can redirect at any checkpoint.";
        :>> consequences = "Fewer, larger check-ins. Scope decisions for sprints are AI-selected from the backlog of Needs and recorded as (proposed) Decisions where they are genuinely architectural, for later human acceptance.";
    }

    verification decNoReviewSignoffAccept : Test { :>> id = "0c05d569-ef8f-4580-9ce0-160c375a7dc0"; :>> method = VerificationMethod::confirmation; :>> procedureText = "wweatherholtz directed on 2026-07-26 that sprint reviews no longer require human sign-off (AI-judged inspection)."; }
    part decNoReviewSignoffAcceptR1 : TestResult { :>> id = "d7e6f2a1-0000-4000-8000-00000000c001"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9295978"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "wweatherholtz"; }

    verification decAutonomousCadenceAccept : Test { :>> id = "6b7c591e-ae5b-450e-92a3-e3871320af5c"; :>> method = VerificationMethod::confirmation; :>> procedureText = "wweatherholtz directed on 2026-07-26 to run at least 5 sprints per session autonomously before pausing (Claude Enterprise long sessions)."; }
    part decAutonomousCadenceAcceptR1 : TestResult { :>> id = "d7e6f2a1-0000-4000-8000-00000000c002"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9295978"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "wweatherholtz"; }
}
