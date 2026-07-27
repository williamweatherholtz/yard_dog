// =====================================================================
// YardDog — holistic "intelligent stack management" Needs (surfaced 2026-07-27).
// A strongly-versioned system with workload-aware defaults, lifecycle states,
// instantiate-from-kind, and preventative deploy guardrails. Config versioning
// is delegated to git (see decGitVersioning); these are the capabilities on top.
// =====================================================================
package YardDogVision {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    requirement needWorkloadClassification : Need {
        :>> id = "71a7b3b2-88d5-4ad5-afff-b2520f3bf4a2";
        :>> title = "Classify what kind of workload each service is";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "For each service, the operator can see (and the tool can act on) its workload kind — stateful datastore, stateless web/API, worker, cron/batch, or reverse-proxy — inferred from image, ports, mounts, and healthcheck, and overridable by an explicit label; classification drives smart, kind-specific defaults.";
        :>> marketJustification = "'What kind of container is this?' lets the tool apply the right behavior automatically (a datastore gets app-consistent backup + version pinning; a stateless web app is safe to recreate) instead of one-size-fits-all. Two-tier: authored label wins, heuristic proposes + flags disagreement.";
        :>> priority = Priority::should;
    }

    requirement needLifecycleStates : Need {
        :>> id = "aa81c726-a4db-4a77-be71-2fb6d316720f";
        :>> title = "Stacks carry a lifecycle state with reversible, recorded transitions";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "Each stack carries a lifecycle state — draft, active, deprecated, archived — with reversible transitions recorded as append-only events (who/when/why), so a setup can be archived (read-only, restorable), deprecated (still runnable, warns on reuse), restored, or retired.";
        :>> marketJustification = "Mirrors the soft/reversible/metadata-driven model of Backstage lifecycle + npm deprecate; gives the operator a holistic 'manage the whole life of a setup', not just deploy.";
        :>> priority = Priority::should;
    }

    requirement needInstantiateFromKind : Need {
        :>> id = "da797ab2-fe44-4b3d-b181-00ebf85af783";
        :>> title = "Instantiate a new stack from a known kind/template with provenance";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "The operator can instantiate a new stack from a known 'kind'/template (parameterized), and the new stack records its provenance — which template and version and parameter values produced it — so the tool can later relate it to newer template versions.";
        :>> marketJustification = "Scaffolder-model instantiation (Backstage/Cookiecutter/Helm) bakes good defaults into every new stack and keeps a link back to the template for future upgrades/audits.";
        :>> priority = Priority::could;
    }

    requirement needDeployGuardrails : Need {
        :>> id = "18107ee1-c9f6-4cd8-899e-3fe5f9f6fcf1";
        :>> title = "Preventative policy guardrails before deploy";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::safety;
        :>> statement = "Before a stack is deployed, it passes a preventative guardrail check — image tags pinned (no floating :latest), healthcheck present, restart policy set, resource limits present, no plaintext secrets, and persistent data on a named volume with a backup profile — modulated by workload kind, and configurable to warn or block.";
        :>> marketJustification = "Policy-as-code (compose config + a small Conftest/Rego ruleset) catches the most common self-hosted outages cheaply; kind-modulation avoids alert fatigue (no healthcheck required on batch, backup profile required on datastores). Extends the preventative posture ([[needGuidedRemediation]]) to deploy time.";
        :>> priority = Priority::should;
    }

    requirement needSecretDataSafety : Need {
        :>> id = "857f9de1-ff9f-4be7-90a9-ae0ecea92e78";
        :>> title = "Secrets and data never enter the config repo in plaintext";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::safety;
        :>> statement = "When stack config is versioned in git, secrets and volume data are never committed in plaintext — an opinionated .gitignore excludes volume/data dirs and secret files by default, and the tool refuses to stage them; encrypted-in-git (SOPS/age) is offered as a later option.";
        :>> marketJustification = "Committing a plaintext .env or a database into git is the headline git footgun — permanent in history, only removable by a destructive rewrite. This guardrail is what makes git-backed versioning safe. See [[decGitVersioning]].";
        :>> priority = Priority::must;
    }
}
