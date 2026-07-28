// =====================================================================
// YardDog — Sprint 60 delivery: remediate the HIGH/security findings from the
// antagonistic critique battery (parallel hostile reviews of the session's new
// code). Lower-severity findings are filed open for the next refinement.
// =====================================================================
package Sprint60CritiqueBattery {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyCritiqueBattery : Story {
        :>> id = "e30ea415-800e-4c6b-901a-909365a26209";
        :>> title = "Remediate critique-battery HIGH findings (terminal lifecycle, server DoS, UX traps, container framing, argv injection)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyCritiqueBattery to needSecureByDefault;

    verification fixTerminalHardeningDoD : Test { :>> id = "41a1dfe2-0861-4d89-ad20-7534bd42a3ca"; :>> method = VerificationMethod::demo; :>> procedureText = "term.rs now bounds lifecycle: the output buffer is capped (MAX_BUFFER, drop-oldest) so an un-polled logs-follow can't OOM; MAX_SESSIONS caps concurrency and a background sweeper closes sessions idle past IDLE_TIMEOUT, killing AND reaping (child.wait()) the docker child; locks are poison-resilient. web.rs handles each request on its OWN thread, so a 500ms blocking /api/term/read no longer stalls the control plane and a handler panic kills only its thread. PROVEN LIVE against a real container: interactive shell still works; while a terminal read was parked ~500ms, /api/stacks returned in 32ms (was serialized before). 147 Rust tests green (incl. a new test that a closed session leaves the registry)."; }
    part fixTerminalHardeningDoDR1 : TestResult { :>> id = "ccd7b5c6-e8a5-466b-a66e-da687772be38"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "6fb6727"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixTerminalUxTrapsDoD : Test { :>> id = "09d27759-638d-4d6c-a212-e677ba5ed908"; :>> method = VerificationMethod::demo; :>> procedureText = "ui.html: a dropped/errored terminal read now shows an honest 'disconnected' (red signal) + reconnect hint and stops the ResizeObserver, instead of a green light on a dead terminal; ensureXterm nulls a rejected promise and start() catches load failure and offers retry (no page-reload brick); the compose draft cache is cleared on git pull so Save & deploy can't clobber pulled changes; b64enc is chunked so a large shell paste can't RangeError-drop. 28 Playwright UI tests green (incl. the terminal-mounts + shell/logs toggle)."; }
    part fixTerminalUxTrapsDoDR1 : TestResult { :>> id = "296d2f6f-705a-4694-9954-e6476a7dd8b2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "6fb6727"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixContainerSecFramingDoD : Test { :>> id = "7a1f80b3-cff0-4e4f-b840-c0bd44bb6fb6"; :>> method = VerificationMethod::inspect; :>> procedureText = "packaging/docker/Dockerfile + docker-compose.yml + README no longer claim the Host allowlist prevents LAN exposure. They now state plainly that the allowlist is a browser DNS-rebinding defense (not access control), that the 127.0.0.1: publish is the SOLE boundary for this no-auth, socket-wired control plane, and explicitly warn NOT to widen the publish (which would expose unauthenticated host root). The misleading 'never opens LAN access on its own' text is gone."; }
    part fixContainerSecFramingDoDR1 : TestResult { :>> id = "2e745fca-7d9c-43c9-9e25-2259defb4cf6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "6fb6727"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixTermArgvInjectionDoD : Test { :>> id = "48427bfd-9f58-439c-bc82-95ba6ab69d94"; :>> method = VerificationMethod::demo; :>> procedureText = "web.rs /api/term/open now inserts an end-of-options `--` before the service positional (`exec -- <svc> sh`, `logs … -- <svc>`) and validates the service name (valid_service_name: alnum start, then [A-Za-z0-9._-]). A flag-like service can no longer be parsed as a docker option. Proven live: `service:\"--privileged\"` is rejected with {\"error\":\"invalid service name\"}; a normal `exec -- web sh` still opens an interactive shell."; }
    part fixTermArgvInjectionDoDR1 : TestResult { :>> id = "4ac187b3-f14a-4ff3-a776-8f7964e00a4e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "6fb6727"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixE2eKindLeftoverDoD : Test { :>> id = "77506b1d-49dc-424d-9db9-54e70edb013a"; :>> method = VerificationMethod::inspect; :>> procedureText = "tests/e2e_docker.rs e2e_uc_lifecycle no longer passes the removed `--kind datastore` to `yd new`; it invokes `new --into … --name immich` (matching the current CLI). The ignored e2e test no longer false-fails on a local run. A stale 'instantiate-from-kind' comment in lifecycle.rs was also corrected."; }
    part fixE2eKindLeftoverDoDR1 : TestResult { :>> id = "cb6297b3-6c26-4fb9-96b0-5f37e4d5d6e2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "6fb6727"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate60 : Test { :>> id = "2ee4620a-fa15-4d30-8f25-ca85eb504bbe"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (5); charter to needSecureByDefault. Four parallel hostile reviewers critiqued the session's new code (terminal correctness/lifecycle, endpoint security, UI concision/UX, kind-removal/docs). Findings triaged: 5 High/security fixed this sprint; 4 lower-severity filed open (issFixPathConfinement, issTermReadCsrf, issUpdatePolicyNarrowing, issUiConcisionNits) for the next refinement, correctness-first."; }
    part refineGate60R1 : TestResult { :>> id = "cfc6194e-0bee-43d2-abf2-e55e1d853891"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "6fb6727"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate60 : Test { :>> id = "ccd318cb-3630-41d9-bdf1-be28d442ce06"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery (meta: reviewing the remediation). (correctness) each fix was verified, not just written — the concurrency fix is proven by a measured 32ms /api/stacks under a parked read; the argv guard by a live rejection; the lifecycle bounds by the full suite + a registry-cleanup test. (honesty) the reviewers also CONFIRMED the safety property that mattered most — a bind-mounted database still gets notify-only updates (has_persistent_mount true for any volume) — so no safety regression from the kind removal; and confirmed no CORS means predictable session ids are not a disclosure break. (scope) lower-severity/design-call findings (absolute-path confinement, term/read CSRF, policy narrowing, console O(n²)) are filed OPEN rather than rushed, so the next refinement prioritizes them. (docs) the container security framing is corrected across Dockerfile/compose/README. No finding was silently dropped."; }
    part reviewGate60R1 : TestResult { :>> id = "edf2e31d-edee-458d-b6a7-584570fc568a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "6fb6727"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate60 : Test { :>> id = "d6c9d5cd-8b55-466c-9ff2-d87495eea1c2"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issTerminalHardening, issTerminalUxTraps, issContainerSecFraming, issTermArgvInjection, issE2eKindLeftover resolved. cargo build + 147 Rust tests + 28 Playwright UI tests green; live terminal + concurrency + argv-validation re-verified; keel validate + guard green. Four lower-severity findings remain open for the next refinement (correctness-first)."; }
    part closeOutGate60R1 : TestResult { :>> id = "c63b6a30-a66b-44b3-912f-c091c525031c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "6fb6727"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
