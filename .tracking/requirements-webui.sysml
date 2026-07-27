// =====================================================================
// YardDog — System Requirement for the loopback browser control plane.
// =====================================================================
package YardDogWebUiReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srBrowserControlPlane : SystemRequirement {
        :>> id = "43a02748-01ca-4633-94ee-b4a5a1765643";
        :>> title = "A loopback-only browser control plane over the CLI";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall provide `yd serve`, a browser control plane that thinly wraps the same library/CLI: read views (stack list, per-stack services + workload kind + guardrail findings + preflight verdict + lifecycle state, plus drift and updates) are computed from the library; actions (deploy, upgrade, lifecycle transitions, backup, docker-compose down) invoke the `yd` binary via an argument vector. It shall be secure by default: bind 127.0.0.1 only, reject any non-loopback Host header, confine every path parameter under the served root (no absolute paths or `..`), serve mutations over POST only, and never expose secret values.";
        :>> rationale = "The operator asked for a real browser UI that is a thin, well-built wrapper over the CLI. Reusing the library for reads and the binary for actions avoids logic duplication, so the UI inherits the tested guardrails/health-gate/rollback. Loopback + Host-allowlist + path confinement give a no-auth single-operator homelab tool a safe-by-construction perimeter (needSecureByDefault), consistent with the v1 'no full RBAC/SSO' exclusion.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::demo;
        :>> priority = Priority::should;
    }

    satisfy needOperationalVisibility by srBrowserControlPlane;
    satisfy needSecureByDefault by srBrowserControlPlane;

    #Verify dependency from webSecurityDoD to srBrowserControlPlane;
    #Verify dependency from uiServeDoD to srBrowserControlPlane;
}
