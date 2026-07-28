// =====================================================================
// YardDog — Decision: SHIP a container image + compose for the on-ramp.
// Supersedes decNoContainerImage (status -> superseded) on new competitive
// evidence: the entire category installs via `docker compose up`.
// =====================================================================
package YardDogShipContainerDecision {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;

    part decShipContainerImage : Decision {
        :>> id = "813903e3-902a-46ca-959b-8c38a39b1e57";
        :>> title = "Ship a supported container image + compose for the install on-ramp (host binary stays the full-feature path)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::accepted;
        :>> context = "Competitive research (Portainer, Komodo, Dockge, Arcane) showed the ENTIRE Docker-management category on-ramps via `docker compose up` mounting the Docker socket. decNoContainerImage declined an image on the principle that yd's own guardrails flag a mounted socket as host-root-equivalent. New evidence: that principled decline leaves yd as the only tool in the category with no `docker compose up` on-ramp — a real adoption-friction gap the operator surfaced. This is exactly the 're-evaluate when new information arrives' case (CLAUDE.md invariant #4).";
        :>> decision = "Publish a supported container image (ghcr.io/williamweatherholtz/yard-dog) plus an example docker-compose.yml, so operators get the category-standard `docker compose up -d` on-ramp. The install story states the reasoning CONCISELY (needs the socket AND a same-path host stacks mount because yd's path-intelligence and backup/restore read the host FS), exposes a configurable port (YD_PORT, changeable and re-applied with `docker compose up -d`), and auto-runs reliably (restart: unless-stopped + a real HTTP healthcheck). The host binary REMAINS the recommended, lower-exposure, full-feature path; the container is the frictionless try-it/opt-in path. The container binds 0.0.0.0 internally but publishes to host loopback only, and the Host allowlist still refuses non-loopback Host headers — so containerizing does not weaken the security posture.";
        :>> rationale = "Adoption parity without abandoning the differentiators. The decline was honest but competitively isolating; offering the image WITH documented caveats (socket + host mounts, host binary recommended) gives operators the on-ramp they expect while keeping the security trade-off explicit rather than hidden. The socket exposure is the operator's informed choice for their own deployment, not the tool silently blessing it as a default — the guardrail lens still warns on socket mounts in stacks yd manages. Chosen by the human operator on 2026-07-27, directing a 'more compelling install story' with concise reasoning, a user-specifiable/modifiable port, and guaranteed auto-run.";
        :>> consequences = "packaging/docker/{Dockerfile,docker-compose.yml} ship; CI publishes a multi-arch image (arm64 first) to GHCR per release; `yd serve` gains --host (default 127.0.0.1) so a container can bind 0.0.0.0 while the host publishes loopback. README's install section leads with the compose on-ramp and states the concise why + the host-binary recommendation. decNoContainerImage is superseded (status field), not deleted — its reasoning remains the recorded history of why we first declined.";
    }

    verification decShipContainerImageAccept : Test { :>> id = "37b1d23b-af99-4887-8b2c-081175eec745"; :>> method = VerificationMethod::confirmation; :>> procedureText = "Human operator wweatherholtz, on 2026-07-27, directed reversing the earlier decline and shipping a container on-ramp: 'we can make a more compelling install story that gives (CONCISE) reasoning, and lets the user specify a port for the serve interface that they can modify later. it must auto run guaranteed and intelligently run services, allow modification of ports, etc.' This attests acceptance of shipping a supported container image + compose with the stated properties, superseding decNoContainerImage."; }
    part decShipContainerImageAcceptR1 : TestResult { :>> id = "5649955d-1c64-4f7d-8944-e077b3c3479b"; :>> outcome = VerdictKind::pass; :>> judgedAt = "2026-07-27"; :>> judgedBy = "wweatherholtz"; }
}
