// =====================================================================
// YardDog — Sprint 45 delivery: per-container resource stats in the UI.
// =====================================================================
package Sprint45Stats {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyStats : Story {
        :>> id = "08a62c95-bb17-4404-b6c0-8ea3d04bf58b";
        :>> title = "Per-service CPU/memory (docker stats) in the Overview";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyStats to needOperationalVisibility;

    action statsParser;
    verification statsParserDoD : Test { :>> id = "52f501c7-185a-46f3-887f-3df6d6d12acf"; :>> method = VerificationMethod::test; :>> procedureText = "stats::parse_container_stats parses tab-separated `docker stats` output (NAME/CPU%/MEMUSAGE) into a container-name -> {cpu,mem} map; unit-tested (two containers parsed; empty/garbage input is safe)."; }
    part statsParserDoDR1 : TestResult { :>> id = "e1b6d9d9-6b98-489b-980e-0c1c3de25e1b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b6306d9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action statsLive;
    verification statsLiveDoD : Test { :>> id = "a967a4e3-1052-4854-97d1-c37a2e04d0ad"; :>> method = VerificationMethod::demo; :>> procedureText = "Against real Docker: GET /api/stats joins `docker compose ps` (service->name) with `docker stats --no-stream` (name->cpu/mem); verified live it returns {service:web, cpu:0.00%, mem:17.52MiB / 15.48GiB} for a running stack. The Overview services table shows CPU + Mem columns, refreshed with the drift/update chips."; }
    part statsLiveDoDR1 : TestResult { :>> id = "5c5d9d06-cc61-47e1-975f-565e0ec43000"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b6306d9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    #Verify dependency from statsLiveDoD to ucResourceStats;

    verification refineGate45 : Test { :>> id = "ec798f73-fab5-4e48-a1ed-2aa3bf75e6a0"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope = surface per-container CPU/memory in the UI (ucResourceStats); pure parser unit-tested, docker join live-verified."; }
    part refineGate45R1 : TestResult { :>> id = "33a5ef4c-06a6-45d9-8ff9-086f52aeee7d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b6306d9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate45 : Test { :>> id = "a6dc2744-354f-43df-976b-4f308c11cbf9"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 2/2 DoD green (121 lib + 23 integration, 0 warnings). New stats.rs (pure parser + docker adapter) and drift::running_names_via_docker (service->container name); /api/stats joins them; UI Overview gains CPU/Mem columns loaded with the status chips. Also filed issGitRepoModel (impl uses per-stack repos vs decGitVersioning's monorepo) as a design finding to resolve before git-remote sync."; }
    part reviewGate45R1 : TestResult { :>> id = "ede63d3f-391e-46bd-8175-e873d82f4283"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b6306d9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate45 : Test { :>> id = "4241240b-b676-4209-b8f1-00dec141cec8"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass; ucResourceStats validated live. Remaining recorded UI use cases: import wizard, notifications, bulk ops, and git remote sync (gated on the issGitRepoModel decision)."; }
    part closeOutGate45R1 : TestResult { :>> id = "872a21c6-c8d2-4d0f-ac86-d5a6c0554290"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b6306d9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
