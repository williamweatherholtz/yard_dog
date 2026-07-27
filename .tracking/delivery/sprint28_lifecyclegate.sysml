// =====================================================================
// YardDog — Sprint 28 delivery: lifecycle-gated deploy/upgrade.
// The flow FSM refuses to deploy/upgrade an Archived stack (Blocked, no side
// effects); Draft/Active/Deprecated proceed.
// =====================================================================
package Sprint28LifecycleGate {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyLifecycleGate : Story {
        :>> id = "8eb1a30c-bf20-4a0f-823e-af45b3acf403";
        :>> title = "Lifecycle-gated deploy: refuse to deploy/upgrade an archived stack";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyLifecycleGate to needSafeDeploy;

    action archivedBlocks;
    verification archivedBlocksDoD : Test { :>> id = "81a86dd5-4dfa-4d32-bbdc-507fe22b79c9"; :>> method = VerificationMethod::test; :>> procedureText = "flow::run on a stack whose lifecycle is Archived returns Outcome::Blocked before backup/apply and does not invoke the deployer; the trace is [Guardrails] only. Verified for both a plain deploy and an upgrade change."; }
    part archivedBlocksDoDR1 : TestResult { :>> id = "a5363530-1c9e-4a1d-848f-47503b28e647"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "821914d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action activeProceeds;
    verification activeProceedsDoD : Test { :>> id = "16c06793-88b6-4a7b-8d80-c1074f9b1f17"; :>> method = VerificationMethod::test; :>> procedureText = "flow::run on Draft/Active/Deprecated stacks is NOT blocked by the lifecycle gate (a healthy deploy still returns Deployed); the gate is specific to Archived."; }
    part activeProceedsDoDR1 : TestResult { :>> id = "aee7f2e7-bbf6-4449-848f-47503c83b6a7"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "821914d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate28 : Test { :>> id = "672643e6-49ac-448b-8652-fded524a2d9f"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; SR srLifecycleGate satisfies needSafeDeploy; two DoD tasks with #Verify edges; ties the lifecycle FSM into the deploy flow as a preventative guardrail."; }
    part refineGate28R1 : TestResult { :>> id = "16a0d273-5cfb-42e3-8bd1-321d847c1936"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "821914d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate28 : Test { :>> id = "bcc1668a-04b0-4317-b6de-cab8b919a275"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 2/2 DoD green (94 lib + 21 integration, 0 build warnings). flow::run's Guardrails phase now reads the stack lifecycle first: Archived => Blocked before any backup/apply, deployer never called, trace [Guardrails]; Draft/Active/Deprecated proceed. Surfaces to the CLI as the existing Blocked path (exit 3). README safety-model note added (doc-sync)."; }
    part reviewGate28R1 : TestResult { :>> id = "1d6cdc0c-9f14-4cd8-962a-f8161cb4304a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "821914d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate28 : Test { :>> id = "cedb1d9b-929f-4aee-8206-08d0d06a3b5e"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass; srLifecycleGate verified via #Verify edges. The lifecycle states are now an enforced preventative guardrail, not just a label. Only needSimplicity remains uncovered (satisfied-by-design Decision next)."; }
    part closeOutGate28R1 : TestResult { :>> id = "db6789db-f9a2-4d93-aa3b-0e62a82305b6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "821914d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
