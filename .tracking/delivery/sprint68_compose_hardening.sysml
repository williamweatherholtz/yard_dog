// =====================================================================
// YardDog — Sprint 68: compose install-artifact hardening. Researched current
// Docker Compose best practices and applied the ones that don't break yard-dog's
// core function (reading arbitrary host paths as root + driving the host socket).
// Resolves the open issContainerNonRoot (iteration-4 follow-on).
// =====================================================================
package Sprint68ComposeHardening {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyComposeHardening : Story {
        :>> id = "270870f4-88c5-4d14-a0e3-fb66aabdd13e";
        :>> title = "Harden packaging/docker/docker-compose.yml per current best practices";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyComposeHardening to needSecureByDefault;

    verification fixContainerNonRootDoD : Test { :>> id = "8cc1a64b-c747-497d-8c44-efeac9eb9a4a"; :>> method = VerificationMethod::inspect; :>> procedureText = "Researched Docker Compose hardening best practices (no-new-privileges, cap_drop, read_only+tmpfs, log rotation, resource limits, socket-proxy) and applied those SAFE for yard-dog: added security_opt no-new-privileges:true, json-file log rotation (10m x3), stop_grace_period 30s, and a stable project name. Deliberately DECLINED cap_drop:[ALL] / non-root user / read_only rootfs — yd must read arbitrary host paths as root (dropping DAC_OVERRIDE breaks other-owned bind reads) and the bundled docker/git CLIs write to $HOME — and instead documented that rationale + provided them as commented, tested-opt-in templates (plus a docker-socket-proxy pointer). `docker compose config` parses clean; loopback publish + socket/stacks mounts unchanged. This is the defense-in-depth pass issContainerNonRoot asked for."; }
    part fixContainerNonRootDoDR1 : TestResult { :>> id = "e0cc1a67-e2f3-421e-beb5-ff517c97e6c6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "f57f2e5"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification refineGate68 : Test { :>> id = "4fa93898-ad73-48a5-bcdd-ec5d7f59213e"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (3); charter to needSecureByDefault. Operator asked to critique the compose YAML against best practices and implement improvements; scope = packaging/docker/docker-compose.yml, resolving the open issContainerNonRoot."; }
    part refineGate68R1 : TestResult { :>> id = "6d847b4d-4039-403d-bcae-714945e5ddee"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "f57f2e5"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification reviewGate68 : Test { :>> id = "b7ef148f-19c0-42c2-af60-bf47e15f38fc"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review. (correctness) the hardening applied is function-preserving — verified against yd's actual needs (host-path reads as root, socket rw, CLI $HOME writes); the riskier controls are declined with recorded rationale rather than copied from a generic template that would break the tool (a correctness-over-checklist call). (security) no-new-privileges closes setuid escalation; log rotation removes a disk-fill vector; the loopback-only publish + its SECURITY comment are preserved intact. (docs/human-factors) every non-obvious choice (why :latest, why not cap_drop, how to opt into read_only/socket-proxy) is commented for the operator. `docker compose config` validates."; }
    part reviewGate68R1 : TestResult { :>> id = "d2bb16ca-dacb-4490-8e4f-4999a6f4298f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "f57f2e5"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification closeOutGate68 : Test { :>> id = "017d1060-3645-4329-bd51-e07287b6f8ee"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issContainerNonRoot resolved (defense-in-depth applied + rationale recorded). `docker compose config` parses clean; no obsolete-key warnings. keel validate + guard green."; }
    part closeOutGate68R1 : TestResult { :>> id = "60108a4f-89f1-4333-b51e-334ac43a7ba0"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "f57f2e5"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }
}
