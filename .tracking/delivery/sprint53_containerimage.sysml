// =====================================================================
// YardDog — Sprint 53 delivery: SHIP the container on-ramp. Reverses the
// Sprint 52 decline (decShipContainerImage supersedes decNoContainerImage) and
// delivers a supported image + compose with a configurable port and guaranteed
// auto-run. Proven live against the local Docker daemon.
// =====================================================================
package Sprint53ContainerImage {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyContainerImage : Story {
        :>> id = "61baca39-9966-4622-81e0-fa219e299c14";
        :>> title = "Container image + compose on-ramp: configurable port, guaranteed auto-run";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyContainerImage to needSimplicity;

    verification containerImageDoD : Test { :>> id = "bb204a4a-1b1a-4bea-89ec-002d6ab98b00"; :>> method = VerificationMethod::inspect; :>> procedureText = "packaging/docker/{Dockerfile,docker-compose.yml,Dockerfile.dockerignore} ship a supported Yard Dog control-plane image: multi-stage (static musl `yd` built from source) landed on docker:cli + git; compose with restart: unless-stopped (auto-run), a real HTTP HEALTHCHECK, a configurable YD_PORT published to host loopback, the Docker socket, and a same-path host stacks mount with CONCISE inline reasoning. `yd serve --host` added (default 127.0.0.1) so the container binds 0.0.0.0 internally while the host publishes loopback. Proven live: image builds; container reaches `healthy`; UI answers HTTP 200 on a CUSTOM port (9099); /api/stacks discovers the mounted stack; yd reaches the host Docker daemon through the mounted socket; a spoofed non-loopback Host header is refused (403). `cargo build --release` green."; }
    part containerImageDoDR1 : TestResult { :>> id = "268144f2-cd15-4c9a-8838-25aa3754fc28"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bf5bcf1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate53 : Test { :>> id = "cbf56e27-efe7-415c-a0a5-f7a715b26a00"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge to needSimplicity set. New competitive evidence (whole category on-ramps via `docker compose up`) and the operator's direction reopen the Sprint 52 decline; decShipContainerImage (accepted, human-attested 2026-07-27) supersedes decNoContainerImage (status -> superseded). Scope: image + compose + serve --host + concise docs, host binary remains the recommended full-feature path."; }
    part refineGate53R1 : TestResult { :>> id = "4322780f-3dbf-4b84-9eff-bb8c3bfc6c35"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bf5bcf1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate53 : Test { :>> id = "8b4bf801-113b-4476-bbfb-b5e2e209d176"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery. (correctness) The on-ramp was proven end-to-end against a real daemon, not just built: healthy container, UI 200 on a custom port, stack discovery, host-Docker reach via socket, and the DNS-rebind Host allowlist still returning 403 under a 0.0.0.0 bind — the security property survives containerization. (human-factors) The compose states CONCISELY why it needs the socket + host mount, how to change the port, and that the host binary is the lower-exposure full-feature option — the operator is not left guessing about the trade-off. (docs) README install section leads with the compose on-ramp + concise why. (design) serve gains an explicit --host seam rather than a hardcoded bind; the Host allowlist is the invariant that keeps 0.0.0.0 safe. (concision) reuses the existing serve/web stack; the image is a thin multi-stage wrapper. Known follow-ups logged (not silent): CI must publish the multi-arch GHCR image per release (issContainerCiPublish); same-path bind resolution is a Linux-host property (Docker Desktop path translation differs) — documented, not a product bug."; }
    part reviewGate53R1 : TestResult { :>> id = "8cc9b262-ee1b-48b7-a6a3-96d566164b5e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bf5bcf1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate53 : Test { :>> id = "e0661679-de44-42ec-a031-9ed3ff31d57b"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: Yard Dog now offers the category-standard `docker compose up -d` on-ramp (configurable port, auto-run, healthchecked) alongside the host binary, .deb/.rpm, Homebrew, Scoop, install script, and self-update. The decision reversal is recorded honestly (decShipContainerImage supersedes decNoContainerImage). One follow-up issue filed for CI image publishing; validate + guard green."; }
    part closeOutGate53R1 : TestResult { :>> id = "4b6ff5bc-a69b-4778-ab62-1a2f641e6890"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "bf5bcf1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
