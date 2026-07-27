// =====================================================================
// YardDog — cybersecurity Need. The tool manages a host's containers and, with
// the browser UI, exposes a control surface; it must be secure by default.
// Complements needSecretDataSafety (secrets out of git) + needDeployGuardrails.
// =====================================================================
package YardDogSecurityNeeds {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRelationships::*;

    requirement needSecureByDefault : Need {
        :>> id = "9d453f3d-49de-4af8-963c-2698e7390cff";
        :>> title = "The tool and its interfaces are secure by default";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::safety;
        :>> statement = "Yard Dog does not expand the host's attack surface. Every control interface (CLI and the browser UI) is secure by default: the UI binds to loopback only unless the operator explicitly opts into wider exposure; user-supplied input can never be turned into arbitrary command or path injection; destructive actions (deploy, upgrade, delete, lifecycle transitions) require explicit confirmation and are refused on states that forbid them; secrets are never exposed in the UI, logs, or over the wire; outbound calls (registries, backups) are the minimum needed and use TLS; and the tool runs with least privilege, adding no persistent listening service the operator did not start.";
        :>> marketJustification = "A homelab control plane that can deploy and delete containers is a high-value target; a self-hosted tool that is careless here is worse than none. Secure-by-default (loopback UI, no injection, confirmed mutations, no secret leakage) is table stakes for trust and a differentiator versus dashboards that ship wide-open.";
        :>> priority = Priority::must;
    }
}
