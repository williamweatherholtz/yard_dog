// =====================================================================
// YardDog — Sprint 9 delivery: operational visibility.
// Health-event model + pluggable notification channel; `yd notify`.
// =====================================================================
package Sprint9Notify {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyNotify : Story {
        :>> id = "08bd836b-06dc-4703-bc40-5932ccd2e9a7";
        :>> title = "Health events + pluggable notifications (`yd notify`)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyNotify to needOperationalVisibility;

        action healthEvents;
        verification healthEventsDoD : Test { :>> id = "758269b8-2e7a-415c-9128-b896d33ebe28"; :>> method = VerificationMethod::test; :>> procedureText = "events_from_states maps container states to events — Exited=>Down, Unhealthy/Restarting=>Unhealthy, Running=>none; unit-tested."; }
        part healthEventsDoDR1 : TestResult { :>> id = "abe732d2-c43b-4682-8cbc-dbdfd7fa9552"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "dbc0753"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action notifyDispatch;
        verification notifyDispatchDoD : Test { :>> id = "d9872af7-2c4c-44b0-9128-b896d407ac70"; :>> method = VerificationMethod::test; :>> procedureText = "format_event renders a message naming the container and its condition; dispatch sends one message per event via a Notifier; recording-notifier unit test."; }
        part notifyDispatchDoDR1 : TestResult { :>> id = "83828e19-4321-48de-8cbc-dbdfd90d0786"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "dbc0753"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliNotify;
        verification cliNotifyDoD : Test { :>> id = "fd2bfca7-a665-4d08-9128-b896d4cd28b0"; :>> method = VerificationMethod::test; :>> procedureText = "yd notify --message MSG sends MSG via the stdout notifier; integration test asserts stdout contains MSG."; }
        part cliNotifyDoDR1 : TestResult { :>> id = "da36a86f-e474-4d56-8cbc-dbdfda7516ea"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "dbc0753"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint9Backlog { }

    verification refineGate9 : Test { :>> id = "99829ad8-5069-467c-ae24-c86547c28ffa"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope clear; DoD tasks authored."; }
    part refineGate9R1 : TestResult { :>> id = "17f5efec-0f6b-4b6c-9128-b896d6c582c0"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "dbc0753"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate9 : Test { :>> id = "f28c0d9d-aec3-49ec-9c57-12de57d4b08a"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (43 lib + 9 integration, 0 warnings); health events derived from states, dispatched via a Notifier; `yd notify --message` sends via stdout."; }
    part reviewGate9R1 : TestResult { :>> id = "9fa57f95-51e6-4fc8-8839-16b715ca2f74"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "dbc0753"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate9 : Test { :>> id = "d8edc74e-c470-4236-a7fa-ad23cc722708"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srNotifications verified; needOperationalVisibility covered."; }
    part closeOutGate9R1 : TestResult { :>> id = "6e8d5e42-95d7-401c-8839-16b716d98464"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "dbc0753"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
