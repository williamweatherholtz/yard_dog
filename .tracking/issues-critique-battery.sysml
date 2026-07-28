// =====================================================================
// YardDog — findings from the antagonistic critique battery run 2026-07-27 over
// this session's new code (PTY terminal, new endpoints, container assets, kind
// removal), by parallel hostile reviewers. High-severity correctness/DoS/safety
// findings were fixed in Sprint 60; the rest are filed for the next refinement.
// =====================================================================
package YardDogCritiqueBatteryIssues {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    // ---- FIXED in Sprint 60 -------------------------------------------------
    part issTerminalHardening : Issue {
        :>> id = "2d3f6bfa-6af0-49c7-a90d-b7d10daa2ef8";
        :>> title = "PTY terminal + server had no lifecycle bounds (OOM / leak / self-DoS / panic-kills-server)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Critique found the terminal layer had NO lifecycle management on a single-threaded server: (T1) the per-session output buffer was uncapped -> an un-polled `logs -f` grows RAM until OOM; (T2) no session cap / idle GC -> an abandoned tab leaks the PTY, the docker child, and a thread forever, and open-in-a-loop exhausts fds; (T3) the request loop handled ONE request at a time, so a 500ms blocking `/api/term/read` long-poll stalled the whole control plane (keystroke latency, /api/stacks, etc.) — a self-DoS with a few idle terminals; (T4) a panic in any handler (or a poisoned lock) killed the entire server; (T5) killed children were never reaped -> Linux zombies. Fixed: cap out buffer (drop-oldest), MAX_SESSIONS + last-touch idle sweeper that kills+reaps, thread-per-request (a blocking read no longer stalls others; a handler panic kills only its thread), poison-resilient locks, child.wait() reap.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }

    part issTerminalUxTraps : Issue {
        :>> id = "1c242f61-c742-4419-b9cf-53e6e08dd2da";
        :>> title = "Terminal/compose UI had 'broken but looks healthy' traps";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Front-end critique: (U1) a single transient read error killed the terminal poll loop permanently while the status light stayed GREEN 'following logs' — a frozen terminal that looks fine; (U2) ensureXterm cached a REJECTED promise with no try/catch, so one failed asset load bricked the terminal for the whole page until reload; (U3) the compose draft buffer was never invalidated on git pull, so Save & deploy could clobber pulled changes with a stale draft; (U4) b64enc spread bytes as function args, so a large shell paste threw RangeError and was silently dropped. Fixed: honest disconnected/ended status + stop observing on end/drop; ensureXterm nulls a rejected promise + start() shows an error/retry; drafts cleared on pull; chunked b64enc.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }

    part issContainerSecFraming : Issue {
        :>> id = "93566a94-929e-4a97-ad00-3035b8dc9396";
        :>> title = "Container Dockerfile/compose comments claimed the Host allowlist prevents LAN exposure (it does not)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Security critique: the container binds 0.0.0.0 internally and the comments claimed 'the Host allowlist still refuses every non-loopback Host header, so this never opens LAN access' — MISLEADING. host_is_loopback inspects the client-supplied Host header; any direct client can send Host: 127.0.0.1. The allowlist is a browser DNS-rebinding defense, NOT access control. The ONLY boundary is the 127.0.0.1: publish, and the comments even invited port changes — an operator widening it to 8770:8770 exposes unauthenticated host root via the socket. Fixed: corrected the Dockerfile + compose + README to state the loopback publish is the sole boundary and to NOT widen it.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }

    part issTermArgvInjection : Issue {
        :>> id = "674433cb-936e-41bc-a569-9eccaa9fe187";
        :>> title = "Argument injection: unvalidated terminal `service` could become a docker flag";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Security critique: /api/term/open passed `service` as a bare argv element to `docker compose exec <service> sh`. A value starting with `-` (e.g. `--privileged`, `--user=root`) is parsed by docker as a FLAG, not a service name (argument injection) — reachable via a crafted compose service name. Gated behind the CSRF/loopback boundary (not a new trust break) but a real missing-validation defect. Fixed: `exec -- <svc> sh` / `logs … -- <svc>` end-of-options guard + charset validation (valid_service_name).";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }

    part issE2eKindLeftover : Issue {
        :>> id = "c5a72bce-8dc2-4fee-bead-53ecd441eaf6";
        :>> title = "e2e_docker test still passed the removed `yd new --kind` flag";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Kind-removal critique: tests/e2e_docker.rs e2e_uc_lifecycle still invoked `new … --kind datastore`, which now errors (unknown arg) — the ignored e2e test would fail on any local e2e run. An incomplete-removal leftover. Fixed: dropped the --kind arg.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }

    action fixTerminalHardening;
    action fixTerminalUxTraps;
    action fixContainerSecFraming;
    action fixTermArgvInjection;
    action fixE2eKindLeftover;
    #Resolves dependency from fixTerminalHardening to issTerminalHardening;
    #Resolves dependency from fixTerminalUxTraps to issTerminalUxTraps;
    #Resolves dependency from fixContainerSecFraming to issContainerSecFraming;
    #Resolves dependency from fixTermArgvInjection to issTermArgvInjection;
    #Resolves dependency from fixE2eKindLeftover to issE2eKindLeftover;

    // ---- DEFERRED (open; for the next refinement) ---------------------------
    part issFixPathConfinement : Issue {
        :>> id = "8398c39d-57ef-4578-947a-df640b716fc6";
        :>> title = "`yd fix` / mount readers act on unconfined ABSOLUTE mount-source paths";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Security critique: safe_join confines the compose FILE under root, but the paths /api/fix (and /api/mounts, /api/permissions) act on are the compose's bind-mount SOURCES. resolve_bind_sources only rejoins RELATIVE sources; ABSOLUTE sources (/etc, /) pass through verbatim, so `yd fix --yes` will mkdir/chown attacker-chosen absolute host paths named in a root-resident compose (compose is writable via /api/save), with a compose-chosen uid/gid. Gated behind the CSRF/loopback boundary and within `yd fix`'s inherent CLI power (it exists to fix host bind dirs, incl. absolute), so not a new trust break — but safe_join creates a false 'confined to root' impression. Decide: confine resolved sources under root for the web /api/fix, or document that fix mutates host paths named by the compose. Note this is also true of the `yd fix` CLI by design.";
        :>> discoveredInField = false;
        :>> severity = Severity::Low;
    }

    part issTermReadCsrf : Issue {
        :>> id = "0cc80905-7f9f-48a8-a94b-47800bd9c662";
        :>> title = "GET /api/term/read is CSRF-exempt and side-effecting (drains the buffer)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Security critique: unlike idempotent GETs, /api/term/read MUTATES state (drains the PTY output buffer) and is NOT behind the POST anti-CSRF gate; session ids are predictable (t1,t2,…). A malicious page the operator visits can fetch it cross-origin for guessed ids and DRAIN the operator's terminal output before their own UI reads it (blind griefing; no disclosure since there are no CORS headers so the response body can't be read cross-origin). Fix: make term/read a POST behind the anti-CSRF gate, or make the drain per-reader/idempotent.";
        :>> discoveredInField = false;
        :>> severity = Severity::Low;
    }

    part issUpdatePolicyNarrowing : Issue {
        :>> id = "e0564145-8091-4d19-9f8e-5ef58f8e8832";
        :>> title = "Update-policy behavior narrowing after keying off has_persistent_mount";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Kind-removal critique (accepted trade-off, recording it): update caution now keys off ANY declared volume. Two edge shifts: (a) a stateless service that mounts a read-only config file or socket is now notify-only (over-cautious — fails safe, a velocity nit); (b) a datastore that declares NO volumes at all is now auto-apply (was notify via image heuristic). Both are defensible; recorded so the behavior change is explicit. Reconsider only if operators hit (a) as friction.";
        :>> discoveredInField = false;
        :>> severity = Severity::Low;
    }

    part issUiConcisionNits : Issue {
        :>> id = "c243528f-121c-419a-ab56-b182137b623c";
        :>> title = "UI concision nits: console dock O(n²) rebuild; confirm-cancel still re-renders";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Front-end critique (low): (U8) renderConsole clears and re-appends ALL buffered lines on every logLine even when the dock is collapsed — O(n²) DOM churn during a bursty fleet op; an append-only write suffices. (U7) confirmAct resolves undefined on cancel, so a chained .then(renderShell) (Apply fixes, Backups) still triggers a full re-render on cancel — harmless but wasteful. Fix both when convenient.";
        :>> discoveredInField = false;
        :>> severity = Severity::Low;
    }

    action fixFixPathConfinement;
    action fixTermReadCsrf;
    action fixUpdatePolicyNarrowing;
    action fixUiConcisionNits;
    #Resolves dependency from fixFixPathConfinement to issFixPathConfinement;
    #Resolves dependency from fixTermReadCsrf to issTermReadCsrf;
    #Resolves dependency from fixUpdatePolicyNarrowing to issUpdatePolicyNarrowing;
    #Resolves dependency from fixUiConcisionNits to issUiConcisionNits;
}
