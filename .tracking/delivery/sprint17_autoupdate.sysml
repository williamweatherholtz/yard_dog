// =====================================================================
// YardDog — Sprint 17 delivery: safe container auto-update.
// update_status + RegistryClient seam + kind-gated update_policy +
// build_update_plan; `yd updates`.
// =====================================================================
package Sprint17AutoUpdate {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyAutoUpdate : Story {
        :>> id = "73b57e5f-2a2b-48c8-aef3-f21c0720842c";
        :>> title = "Container update detection + kind-gated plan (`yd updates`)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyAutoUpdate to needContainerAutoUpdate;

        action updateStatus;
        verification updateStatusDoD : Test { :>> id = "d8342979-511d-485d-82c1-7e1d46ad9e23"; :>> method = VerificationMethod::test; :>> procedureText = "update_status(running_digest, remote_digest) returns UpToDate when equal, UpdateAvailable when different, Unknown when either is missing; a RegistryClient trait supplies the remote digest; unit-tested with a stub client."; }
        part updateStatusDoDR1 : TestResult { :>> id = "246a5c9f-8009-4ac2-b79b-ede215eccdae"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "f266c9b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action updatePolicy;
        verification updatePolicyDoD : Test { :>> id = "d6590c55-93e3-47cd-82c1-7e1d4772c27f"; :>> method = VerificationMethod::test; :>> procedureText = "update_policy(kind) is NotifyOnly for Datastore and Unknown (never auto), AutoApply for Web/Worker/Proxy/Cron; unit-tested per kind."; }
        part updatePolicyDoDR1 : TestResult { :>> id = "2b2156fb-f237-4c82-b79b-ede216e85192"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "f266c9b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action buildUpdatePlan;
        verification buildUpdatePlanDoD : Test { :>> id = "e82b752d-d0f0-4bf9-82c1-7e1d483a344f"; :>> method = VerificationMethod::test; :>> procedureText = "build_update_plan(services, running_digests, registry) yields per-service {status, kind, action} where an available update on a datastore => Notify, on a web => Apply, and up-to-date => None; unit-tested."; }
        part buildUpdatePlanDoDR1 : TestResult { :>> id = "a6672fc4-7f4b-4d3a-b79b-ede21840289e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "f266c9b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliUpdates;
        verification cliUpdatesDoD : Test { :>> id = "701915f0-39e0-4fd5-82c1-7e1d48ff671f"; :>> method = VerificationMethod::test; :>> procedureText = "yd updates <compose> lists each service with its kind and update action, degrading gracefully (exit 0) when the registry is unavailable; integration test asserts it runs and lists the services."; }
        part cliUpdatesDoDR1 : TestResult { :>> id = "0557ff6b-6c45-4796-b79b-ede2198ddf16"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "f266c9b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint17Backlog { }

    verification refineGate17 : Test { :>> id = "bd2ab317-a61b-4baa-b4a4-c582967e541b"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edge set; scope clear; DoD tasks authored; reuses workload classification + the safe deploy path."; }
    part refineGate17R1 : TestResult { :>> id = "e568c631-ffaa-4b55-82c1-7e1d4af554df"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "f266c9b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate17 : Test { :>> id = "070bf17f-4fb4-4ec5-9b9d-313ab112deac"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 4/4 DoD green (62 lib + 15 integration, 0 warnings); update_status digest compare, kind-gated update_policy (datastores notify-only), build_update_plan, `yd updates`. Registry client is a seam; running-digest resolution is the next increment."; }
    part reviewGate17R1 : TestResult { :>> id = "82bd032a-a797-4130-b318-28b98c2bf798"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "f266c9b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate17 : Test { :>> id = "95d505e5-e6ef-480f-b416-0b03e8da217b"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 4/4 DoD pass; srContainerAutoUpdate verified; needContainerAutoUpdate covered — safe auto-update plan gated by workload kind."; }
    part closeOutGate17R1 : TestResult { :>> id = "a85e5717-ea76-49d1-a7aa-df2910369443"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "f266c9b"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
