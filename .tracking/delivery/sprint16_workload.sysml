// =====================================================================
// YardDog — Sprint 16 delivery: workload classification.
// classify(view) label-first + heuristic_kind fallback; parse_services from
// compose; `yd classify`.
// =====================================================================
package Sprint16Workload {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyWorkload : Story {
        :>> id = "597267c1-3b03-4690-9862-e8c1f7fa56bc";
        :>> title = "Workload classification (kind heuristic + label override) + `yd classify`";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyWorkload to needWorkloadClassification;

        action heuristicKind;
        verification heuristicKindDoD : Test { :>> id = "ada5a3f6-668d-4926-9b66-6999c54c3c46"; :>> method = VerificationMethod::test; :>> procedureText = "heuristic_kind(view) classifies from image/ports/mounts/restart: a DB image => Datastore, a proxy image (traefik/caddy/haproxy) + web ports => Proxy, restart=no => Cron, published ports => Web, no ports + restart => Worker, else Unknown; unit-tested per case."; }
        part heuristicKindDoDR1 : TestResult { :>> id = "1c8267ae-ab2f-4bca-928e-b02bccfd11fa"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3e4231a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action labelOverride;
        verification labelOverrideDoD : Test { :>> id = "5caf9dc7-309f-421e-9b66-6999c6100626"; :>> method = VerificationMethod::test; :>> procedureText = "classify(view) returns the authored label kind when present (overriding the heuristic); a helper surfaces disagreement when the authored kind differs from the heuristic; unit-tested."; }
        part labelOverrideDoDR1 : TestResult { :>> id = "c1c3f481-8591-4286-928e-b02bce15a93a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3e4231a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action parseServices;
        verification parseServicesDoD : Test { :>> id = "0e3e357a-a582-4bbe-9b66-6999c6cb6d26"; :>> method = VerificationMethod::test; :>> procedureText = "parse_services(yaml) extracts a ServiceView per service (image, ports, has_persistent_mount, has_healthcheck, restart, label kind); unit-tested over a multi-service compose."; }
        part parseServicesDoDR1 : TestResult { :>> id = "2420f3e3-3169-4d9e-928e-b02bcf9c63ca"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3e4231a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliClassify;
        verification cliClassifyDoD : Test { :>> id = "37084d20-2330-414a-9b66-6999c78b8232"; :>> method = VerificationMethod::test; :>> procedureText = "yd classify <compose> prints each service and its kind; integration test asserts a postgres service is Datastore and an nginx web service is Web."; }
        part cliClassifyDoDR1 : TestResult { :>> id = "ada5a3f6-668d-49db-8721-669b541ff039"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3e4231a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint16Backlog { }

    verification refineGate16 : Test { :>> id = "5cd51e44-8030-4680-8294-ac3fb3407128"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edge set; scope clear; DoD tasks authored; reuses compose parsing + db-engine detection."; }
    part refineGate16R1 : TestResult { :>> id = "6ea40d88-e62e-4a62-9b66-6999ca39c8ea"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3e4231a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate16 : Test { :>> id = "823ff6fe-d756-4b37-953c-f2111a6f0152"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 4/4 DoD green (59 lib + 14 integration, 0 warnings); heuristic_kind (datastore/proxy/cron/web/worker/unknown), label override + disagreement, parse_services, `yd classify`."; }
    part reviewGate16R1 : TestResult { :>> id = "03b59877-77e5-4236-897b-31a1706ee09e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3e4231a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate16 : Test { :>> id = "f579424f-1089-4bdb-b40b-413584050925"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 4/4 DoD pass; srWorkloadClassify verified; needWorkloadClassification covered — unblocks kind-gated updates + guardrails."; }
    part closeOutGate16R1 : TestResult { :>> id = "4bbf6bdd-aa04-4b0e-897b-31a17182650a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3e4231a"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
