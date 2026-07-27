// =====================================================================
// YardDog — Sprint 27 delivery: instantiate a new stack from a kind.
// Guardrail-clean, kind-appropriate starter compose in Draft lifecycle.
// =====================================================================
package Sprint27Instantiate {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyInstantiate : Story {
        :>> id = "a80e840a-0115-41da-a183-6fe7ad87cf8f";
        :>> title = "Instantiate a new stack from a workload kind (guardrail-clean starter in Draft)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyInstantiate to needInstantiateFromKind;

    action scaffoldClean;
    verification scaffoldCleanDoD : Test { :>> id = "dc46611f-f14a-4187-9bf1-73fff2bdace1"; :>> method = VerificationMethod::test; :>> procedureText = "scaffold(kind, service) produces a compose that passes run_guardrails (no Block finding) for every kind: pinned image, healthcheck, restart policy, and a resource limit are present; unit-tested across all workload kinds."; }
    part scaffoldCleanDoDR1 : TestResult { :>> id = "da58af59-5cf7-4df2-8b25-1e29dc3bc4fa"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d4ebd1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action datastoreVolume;
    verification datastoreVolumeDoD : Test { :>> id = "88227e09-e2fd-4e4b-9f2f-086a957e7bb9"; :>> method = VerificationMethod::test; :>> procedureText = "A datastore scaffold includes a named volume (a top-level volumes: entry and a service mount) so its data is not anonymous/ephemeral; a non-datastore kind (web) does not add a volume."; }
    part datastoreVolumeDoDR1 : TestResult { :>> id = "5112105f-4e47-41b2-8b25-1e29ddbe64c2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d4ebd1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action instantiateDraft;
    verification instantiateDraftDoD : Test { :>> id = "fd4e6aba-0af5-48e4-a811-4a142fdcefac"; :>> method = VerificationMethod::test; :>> procedureText = "instantiate(root, name, kind, service) writes the starter compose into root/name/docker-compose.yml and sets that stack's lifecycle to Draft; unit-tested (file exists, guardrail-clean, lifecycle::read_state == Draft)."; }
    part instantiateDraftDoDR1 : TestResult { :>> id = "776e3968-717a-4ea6-8b25-1e29df1e9936"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d4ebd1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate27 : Test { :>> id = "4fa2d6ba-eda3-4ec2-adc4-144f50c936b9"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edge set; SR srInstantiateFromKind satisfies needInstantiateFromKind; three DoD tasks with #Verify edges; builds on workload classification + lifecycle FSM + guardrails."; }
    part refineGate27R1 : TestResult { :>> id = "416e6a45-7315-49fc-8640-e1a2179b6815"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d4ebd1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate27 : Test { :>> id = "44fcf7bf-d6a3-4be2-9033-6747d1dc40bd"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (92 lib + 21 integration, 0 build warnings). instantiate.rs scaffolds a kind-appropriate starter compose (pinned image per kind, healthcheck, restart, mem_limit; datastore also a named volume) that passes run_guardrails by construction for every kind; instantiate() writes root/name/docker-compose.yml and sets lifecycle=Draft. CLI `yd new --into --name --kind [--service]` wired with an integration test (file written, `yd check` clean, lifecycle draft). README updated (doc-sync)."; }
    part reviewGate27R1 : TestResult { :>> id = "068c7205-2903-46fa-9b62-15b8631976b3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d4ebd1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate27 : Test { :>> id = "392026f2-6b79-45e6-9380-d61b9706b33c"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srInstantiateFromKind verified via #Verify edges; needInstantiateFromKind now covered (verified tier). Only needSimplicity remains uncovered — best recorded as a satisfied-by-design Decision next."; }
    part closeOutGate27R1 : TestResult { :>> id = "29adb214-f21e-4b55-98e1-9152c32b9421"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0d4ebd1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
