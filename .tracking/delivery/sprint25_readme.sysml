// =====================================================================
// YardDog — Sprint 25 delivery: user-facing README (docs).
// Resolves issReadme: a README documenting the yd command surface, the safety
// model (guardrails / backup / git-versioning / health-gated deploy+upgrade /
// complete rollback), and the deploy/upgrade exit codes. Work item is the
// ProductBacklog resolver addReadme. Closes the inaugural critique battery.
// =====================================================================
package Sprint25Readme {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyReadme : Story {
        :>> id = "a691c69c-37b6-4089-b15e-6499363265e9";
        :>> title = "README: command reference + safety model + exit codes";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::documentation;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 2;
    }

    #CharteredBy dependency from storyReadme to needSimplicity;

    verification refineGate25 : Test { :>> id = "177c7dec-62b4-4a79-8d18-0393af716aab"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (2); charter edge set; scope = a README covering all yd commands (verified against the actual CLI arg definitions), the safety model, and exit codes; work item is addReadme."; }
    part refineGate25R1 : TestResult { :>> id = "f28cc577-2f3d-457e-9ef8-5237fe870e3d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d07fc8d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate25 : Test { :>> id = "a5e17697-e01e-46ff-9f4a-426b5bf6845c"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: README.md authored. Every command syntax was checked against main.rs arg definitions and corrected (positional file vs --root/--dest/--from/--to/--repo/--into/--message/--service). Documents the shared lifecycle FSM, the guardrail warn/block split, git-versioning invariants, complete rollback (config + running stack), and exit codes 0/2/3/4. Build/test instructions included."; }
    part reviewGate25R1 : TestResult { :>> id = "ffb4fd9b-d510-4c38-9996-8c562a8aa02b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d07fc8d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate25 : Test { :>> id = "1bc22819-0d95-4a08-821b-a6e80ad6eaa7"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: addReadme DoD pass; issReadme resolved via #Resolves. All seven inaugural critique-battery issues (S21) plus the two S22 findings are now resolved. Follow-up (not correctness): wire a keel doc-sync manifest so the README is machine-checked against the CLI on commit."; }
    part closeOutGate25R1 : TestResult { :>> id = "63473d4c-49be-455f-938b-8413bf83be0f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d07fc8d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
