// =====================================================================
// YardDog — Sprint 15 delivery: pre-deploy policy guardrails.
// run_guardrails over a compose (floating tag, healthcheck, restart, limits,
// plaintext secrets) + a warn/block verdict; `yd check`.
// =====================================================================
package Sprint15Guardrails {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyGuardrails : Story {
        :>> id = "eb7a051f-737a-485e-bef6-0e72b243e8ff";
        :>> title = "Pre-deploy policy guardrails (`yd check`)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyGuardrails to needDeployGuardrails;

        action guardrailChecks;
        verification guardrailChecksDoD : Test { :>> id = "5ae5d500-6622-4ff4-9fca-bd8dca13aba8"; :>> method = VerificationMethod::test; :>> procedureText = "run_guardrails(yaml) flags floating image tags (block), missing healthcheck/restart/limits (warn), and plaintext secret env values (block); a clean service produces no blocking findings and ${VAR} secret refs are not flagged; unit-tested."; }
        part guardrailChecksDoDR1 : TestResult { :>> id = "b31faa4a-e0ee-4907-8ffd-8b7f5a456c2d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0e4d005"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action guardrailVerdict;
        verification guardrailVerdictDoD : Test { :>> id = "dbd90f63-d8d4-4e40-9fca-bd8dcacf6c1c"; :>> method = VerificationMethod::test; :>> procedureText = "verdict(findings) passes when there are no Block findings and fails when any Block is present; unit-tested (block fails, warn-only passes, empty passes)."; }
        part guardrailVerdictDoDR1 : TestResult { :>> id = "79a371d5-031a-4b8b-8ffd-8b7f5b4da081"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0e4d005"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliCheck;
        verification cliCheckDoD : Test { :>> id = "a8424ce8-3c84-4620-9fca-bd8dcba3e708"; :>> method = VerificationMethod::test; :>> procedureText = "yd check <compose> prints findings and exits non-zero on a blocking finding; integration test asserts a :latest+plaintext-secret compose fails and a clean compose passes."; }
        part cliCheckDoDR1 : TestResult { :>> id = "9bb13434-b0fe-4b83-8ffd-8b7f5ca12b29"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0e4d005"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint15Backlog { }

    verification refineGate15 : Test { :>> id = "23d23d57-6237-431f-9bfc-a838adadebc9"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope clear; DoD tasks authored; reuses compose parsing."; }
    part refineGate15R1 : TestResult { :>> id = "83828e19-4321-4560-9fca-bd8dcdf7d280"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0e4d005"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate15 : Test { :>> id = "91dbb289-6bd9-4307-98e5-e47eec8c88a7"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (56 lib + 13 integration, 0 warnings); run_guardrails flags floating tags/plaintext secrets (block) + missing healthcheck/restart/limits (warn); verdict blocks on Block; `yd check` exits non-zero on a blocking finding."; }
    part reviewGate15R1 : TestResult { :>> id = "a3ff3de1-ef61-45c5-8b79-c656bac9f353"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0e4d005"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate15 : Test { :>> id = "9d1bce6c-7f99-478d-b740-32b54b66e347"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srDeployGuardrails verified; needDeployGuardrails covered. Batch S11-S15 complete."; }
    part closeOutGate15R1 : TestResult { :>> id = "d85033a8-ff0f-4dd9-8b79-c656bbdcbd6b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0e4d005"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
