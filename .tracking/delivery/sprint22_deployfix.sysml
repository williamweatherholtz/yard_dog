// =====================================================================
// YardDog — Sprint 22 delivery: deploy/upgrade hardening (correctness-first).
// Resolves the inaugural critique battery's P0/P1 flow findings: an explicit
// FSM (flow.rs) with a real health-gate (docker compose up -d --wait) and
// guardrails-on-deploy, unifying safe_deploy + safe_upgrade. Work items are the
// critique resolver tasks (fixHealthGateWait, deployRunsGuardrails,
// deployUpgradeFsm, dedupeDeployUpgrade), closing issues issHealthGateWait /
// issNoGuardrailWarn / issDeployFsm / issDeployDup.
// =====================================================================
package Sprint22DeployFix {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyDeployFix : Story {
        :>> id = "16e6901a-fc37-4a2d-9ee2-da95bde052d4";
        :>> title = "Deploy/upgrade FSM + real health-gate + guardrails-on-deploy (critique P0/P1 fixes)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p0;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyDeployFix to needSafeDeploy;
    #CharteredBy dependency from storyDeployFix to needDeployGuardrails;

    verification refineGate22 : Test { :>> id = "740062f3-09e9-4307-8291-0bed742614b7"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edges set; scope = resolve the critique P0/P1 flow issues (health-gate --wait, guardrails-on-deploy, explicit FSM, dedup); work items are the ProductBacklog resolver tasks; correctness-first."; }
    part refineGate22R1 : TestResult { :>> id = "794359d2-6423-4d06-a24f-9a7713539a7a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "323d525"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate22 : Test { :>> id = "157fb7a2-b9de-4d25-b8f7-6cff4bffb804"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 4/4 resolvers green (78 lib + 19 integration, 0 build warnings). New flow.rs is an explicit Phase FSM (Guardrails->Backup->Apply->Snapshot->Health->Decide->Regress) shared by safe_deploy + safe_upgrade, which are now thin adapters (dedup, issDeployDup). Health-gate is real: RealDeployer runs `docker compose up -d --wait`; a failed/timed-out wait => Err => regress (issHealthGateWait). Guardrails run on the deploy/upgrade path: block-severity halts before Apply, warnings are surfaced to the operator via announce_guardrails (issNoGuardrailWarn). gitver snapshot/restore made idempotent so a no-change deploy does not error."; }
    part reviewGate22R1 : TestResult { :>> id = "f5e28caf-6477-4fad-8e3a-17aec7d9e74f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "323d525"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate22 : Test { :>> id = "b409456b-9394-4d9e-b2ae-dc8167c9114a"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 4/4 resolver DoD pass; issues issHealthGateWait, issNoGuardrailWarn, issDeployFsm, issDeployDup resolved via #Resolves. needSafeDeploy + needDeployGuardrails re-satisfied with the correctness fixes. Remaining critique issues (issYamlReformat, issRestoreStray, issReadme) carry forward to Sprint 23/24."; }
    part closeOutGate22R1 : TestResult { :>> id = "97f195eb-a1ef-463c-8526-1bb2f5cbfc66"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "323d525"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
