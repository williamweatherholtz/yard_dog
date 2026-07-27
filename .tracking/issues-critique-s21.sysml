// =====================================================================
// YardDog — inaugural critique-battery findings (post-Sprint 21, 2026-07-27).
// Lenses: correctness, human-factors, design/FSM, concision, docs. Each Issue
// carries a severity and a #Resolves edge to a product-backlog resolver.
// =====================================================================
package YardDogCritiqueIssues {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    // -- CORRECTNESS (High): the health-gate does not actually wait for health --
    part issHealthGateWait : Issue {
        :>> id = "17712f03-7b1a-455d-b715-45cedad8eb31";
        :>> title = "Health-gate does not wait for healthchecks (up -d returns on start, not healthy)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "RealDeployer runs `docker compose up -d`, which returns once containers START, not once they are HEALTHY. safe_deploy/safe_upgrade treat that success as 'healthy', so a broken deploy/upgrade can be auto-accepted and NOT rolled back — defeating the core safety guarantee. Fix: `docker compose up -d --wait` (with timeout), treating a failed/timed-out wait as unhealthy => regress.";
        :>> discoveredInField = false;
        :>> severity = Severity::High;
    }

    // -- HUMAN-FACTORS + CORRECTNESS (High): no guardrail warning before deploy --
    part issNoGuardrailWarn : Issue {
        :>> id = "621509d0-5831-447a-b8b6-8585d068f7de";
        :>> title = "Deploy/upgrade do not run guardrails; operator not warned about missing healthcheck";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "safe_deploy/safe_upgrade never call run_guardrails, so the operator gets no indication that a service has NO healthcheck (which also makes the health-gate meaningless), a floating :latest tag, or a plaintext secret. The user's own example: an operator should be told when a healthcheck is desired but absent. Fix: run guardrails on the deploy/upgrade path and surface findings (warn/block per policy).";
        :>> discoveredInField = false;
        :>> severity = Severity::High;
    }

    // -- CORRECTNESS (Medium): image edit destroys compose formatting/comments --
    part issYamlReformat : Issue {
        :>> id = "6db48c14-337a-43c2-8b7e-4a758ed14cac";
        :>> title = "set_service_image round-trips YAML, discarding comments and reformatting";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "set_service_image parses + re-serializes the compose via serde_yaml, which drops comments and reformats the file. For a files-on-disk, git-versioned tool this produces noisy diffs and loses operator comments — undermining the files-on-disk promise. Fix: a surgical in-place edit of the image line preserving surrounding formatting/comments.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- DESIGN / STATE-MACHINE (Medium): deploy/upgrade should be an explicit FSM --
    part issDeployFsm : Issue {
        :>> id = "6daf8a21-f4a9-4360-b734-6aaa944b6ea0";
        :>> title = "Deploy/upgrade lifecycle is ad-hoc imperative; model as an explicit FSM";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "The deploy/upgrade flow (backup -> snapshot -> deploy -> health -> accept/regress) is imperative with flat outcome enums; there is no explicit state machine, so invalid transitions are representable and the flow is hard to inspect/extend. Prefer an explicit FSM (states + guarded transitions) shared across deploy/upgrade. (needLifecycleStates draft/active/deprecated/archived is likewise an unbuilt FSM.)";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- CONCISION (Medium): safe_upgrade duplicates safe_deploy --
    part issDeployDup : Issue {
        :>> id = "004300e7-e112-496c-8148-e00fe7763f23";
        :>> title = "safe_upgrade duplicates ~80% of safe_deploy's orchestration";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "safe_upgrade re-implements safe_deploy's backup -> prior -> snapshot -> deploy -> rollback structure. Extract a shared orchestration primitive so the two stay consistent. Also: safe_upgrade's parameters are underscore-prefixed (`_confirmed`, `_repo`) yet used — a readability smell left from the stub.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- CORRECTNESS (Medium): git restore leaves stray files --
    part issRestoreStray : Issue {
        :>> id = "02ad2331-f134-40c2-88b4-797eb45b1a73";
        :>> title = "gitver::restore does not remove files added after the target commit";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "gitver::restore uses `git checkout <sha> -- .`, which restores the content of tracked files but does NOT delete files that were added after <sha>. A faithful restore/regress must also remove files not present in the target commit, else a regressed stack retains stray config a later deploy might pick up.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- DOCS (Medium): no user documentation --
    part issReadme : Issue {
        :>> id = "1ecf9586-27ed-4b46-b145-a2e097220ef4";
        :>> title = "No README / user docs for the 17-command CLI or the safety model";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "The tool has grown to 17 commands with no user-facing documentation of what they do or the safety model (backup/verify/git-versioning/safe-deploy/upgrade/guardrails). Add a README and keep it current on commit (doc-sync).";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- Triage: each finding resolved-by its product-backlog task --
    #Resolves dependency from fixHealthGateWait to issHealthGateWait;
    #Resolves dependency from deployRunsGuardrails to issNoGuardrailWarn;
    #Resolves dependency from preserveComposeFormat to issYamlReformat;
    #Resolves dependency from deployUpgradeFsm to issDeployFsm;
    #Resolves dependency from dedupeDeployUpgrade to issDeployDup;
    #Resolves dependency from gitRestoreRemovesStray to issRestoreStray;
    #Resolves dependency from addReadme to issReadme;
}
