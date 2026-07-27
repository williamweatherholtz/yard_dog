// =====================================================================
// YardDog — Sprint 18 delivery: update pinning.
// read/write pins (.yd-pins) + apply_pins over the update plan; `yd pin`.
// =====================================================================
package Sprint18Pinning {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyPinning : Story {
        :>> id = "ff9cd184-6aac-49f5-a8d7-3d7c996941de";
        :>> title = "Update pinning (persist pins + respect them in the plan) + `yd pin`";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyPinning to needSafeUpdates;

        action pinStore;
        verification pinStoreDoD : Test { :>> id = "a9b7554f-9036-4276-80eb-31887a27da12"; :>> method = VerificationMethod::test; :>> procedureText = "write_pin(dir, service) appends to .yd-pins (deduped) and read_pins(dir) returns the pinned services; unit-tested including dedupe and missing-file empty."; }
        part pinStoreDoDR1 : TestResult { :>> id = "9691eaf9-77fb-4e9f-9123-f996950bf4f1"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3ba54a2"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action applyPins;
        verification applyPinsDoD : Test { :>> id = "41e04f99-69fe-421e-80eb-31887af4a696"; :>> method = VerificationMethod::test; :>> procedureText = "apply_pins(plan, pins) sets a pinned service's action to None even when an update is available, leaving unpinned services' actions unchanged; unit-tested."; }
        part applyPinsDoDR1 : TestResult { :>> id = "045f1936-657c-442f-9123-f99696259059"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3ba54a2"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliPin;
        verification cliPinDoD : Test { :>> id = "31999e6e-d0fb-4a4a-80eb-31887bbd9736"; :>> method = VerificationMethod::test; :>> procedureText = "yd pin add --repo DIR --service S records a pin; yd pin list --repo DIR lists it; integration test asserts an added pin appears in the list."; }
        part cliPinDoDR1 : TestResult { :>> id = "864b39ce-def7-46cb-9123-f996979d4409"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3ba54a2"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint18Backlog { }

    verification refineGate18 : Test { :>> id = "b38574a2-492b-4a58-afd7-be85e4e92974"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope clear; DoD tasks authored; builds on the update plan."; }
    part refineGate18R1 : TestResult { :>> id = "a278e11d-a8f3-44b6-80eb-31887eb36f6a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3ba54a2"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate18 : Test { :>> id = "bc0639cf-3e82-45b9-904f-274c6cf392aa"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (64 lib + 16 integration, 0 warnings); read_pins/write_pin (.yd-pins, deduped), apply_pins holds pinned services, `yd pin add|list`."; }
    part reviewGate18R1 : TestResult { :>> id = "753e5be5-3d75-4ec8-8eee-0b3aff14d464"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3ba54a2"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate18 : Test { :>> id = "db319202-4f2e-4547-8b3e-f6c09c78c280"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srUpdatePinning verified; needSafeUpdates covered (review + snapshot + rollback already delivered; pinning completes it)."; }
    part closeOutGate18R1 : TestResult { :>> id = "7d31a879-3a7b-48a8-8eee-0b3b00175878"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3ba54a2"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
