// =====================================================================
// YardDog — Sprint 29 delivery: unified preflight (yd doctor).
// One go/no-go verdict from guardrails + lifecycle; satisfies needSimplicity.
// =====================================================================
package Sprint29Preflight {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyPreflight : Story {
        :>> id = "5f0d9a67-3f73-4e8d-a3a3-e9c1995c29c0";
        :>> title = "yd doctor: one preflight verdict (guardrails + lifecycle) with an exit code";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyPreflight to needSimplicity;

    action preflightCounts;
    verification preflightCountsDoD : Test { :>> id = "73551ea5-eed4-4f06-ac7a-fb272a95a3f3"; :>> method = VerificationMethod::test; :>> procedureText = "assess(yaml, lifecycle) counts guardrail block and warn findings and sets ready=false iff a block exists (for a non-archived stack); a clean compose yields ready=true with zero blocks; a floating-tag/plaintext-secret compose yields ready=false with blocks>0."; }
    part preflightCountsDoDR1 : TestResult { :>> id = "07d145aa-eeea-45f5-84e2-f4de24a647af"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c30d1b9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action preflightArchived;
    verification preflightArchivedDoD : Test { :>> id = "bf50c4c5-55a5-465a-8cfe-cba54b42a6c2"; :>> method = VerificationMethod::test; :>> procedureText = "assess treats an Archived stack as not-ready even when the compose is guardrail-clean (mirrors the deploy-flow lifecycle gate); Draft/Active/Deprecated with a clean compose are ready."; }
    part preflightArchivedDoDR1 : TestResult { :>> id = "77f05854-88f4-4839-84e2-f4de2614a0d7"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c30d1b9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action doctorExitCode;
    verification doctorExitCodeDoD : Test { :>> id = "960046c9-0fef-4717-8a73-8e6a118b21f3"; :>> method = VerificationMethod::test; :>> procedureText = "`yd doctor <compose>` prints the verdict and exits 0 when ready, non-zero when not ready; integration test: a clean stack succeeds, a floating-tag stack fails."; }
    part doctorExitCodeDoDR1 : TestResult { :>> id = "7d6a5ea9-0354-4d79-84e2-f4de27699d07"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c30d1b9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate29 : Test { :>> id = "6e056001-272f-4a9c-96b4-02639c1a928c"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; SR srUnifiedPreflight satisfies needSimplicity; three DoD tasks with #Verify edges; reuses guardrails + lifecycle, same rules as the deploy gate."; }
    part refineGate29R1 : TestResult { :>> id = "72e7e0fb-25d4-4d78-9ee4-4d66c1e63642"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c30d1b9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate29 : Test { :>> id = "8228be31-836f-49c6-9e2b-f40e9e13aa57"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (99 lib + 22 integration, 0 build warnings). preflight::assess aggregates guardrail block/warn counts + lifecycle into a ready verdict using the SAME rule as the deploy gate (any block, or Archived, => not ready). `yd doctor <compose>` prints READY/NOT READY with counts, lists the findings, and exits 0/3; integration-tested (clean passes, floating-tag fails). README updated (doc-sync)."; }
    part reviewGate29R1 : TestResult { :>> id = "06bb02f4-c8be-44d9-a8ca-a02ce441080e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c30d1b9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate29 : Test { :>> id = "bd47ddff-36ab-4d38-9b35-d812843d6471"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srUnifiedPreflight verified via #Verify edges; needSimplicity now covered (verified tier). All product needs are now covered — the preflight gives the operator one go/no-go answer consistent with what the deploy flow will enforce."; }
    part closeOutGate29R1 : TestResult { :>> id = "6a4f292c-5d72-4062-bf5e-3a99edef1831"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c30d1b9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
