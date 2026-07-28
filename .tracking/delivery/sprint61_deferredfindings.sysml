// =====================================================================
// YardDog — Sprint 61 delivery: clear the four deferred critique-battery findings
// (term/read CSRF, fix-path confinement, update-policy narrowing, UI concision).
// =====================================================================
package Sprint61DeferredFindings {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyDeferredFindings : Story {
        :>> id = "f31d37a4-afaf-46b4-907c-03523c366b90";
        :>> title = "Clear the deferred critique-battery findings (CSRF read, fix-path guard, RO-mount policy, UI nits)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyDeferredFindings to needSecureByDefault;

    verification fixTermReadCsrfDoD : Test { :>> id = "49a807eb-0b60-4703-9518-b7d5ea70dfae"; :>> method = VerificationMethod::demo; :>> procedureText = "The draining terminal read moved from a CSRF-exempt GET to a POST behind the anti-CSRF gate. web.rs drops the GET /api/term/read route and handles it in handle_action (POST); ui.html polls it with post(). Proven live against a real container: the shell still streams output via POST read (`POST-READ-OK`); the old GET /api/term/read now returns HTTP 405; a POST read with Content-Type text/plain is rejected 415 (anti-CSRF). A visited page can no longer blindly drain the operator's terminal via a guessed-id GET."; }
    part fixTermReadCsrfDoDR1 : TestResult { :>> id = "eac3c39b-a820-445d-9ade-fc00c4b56a08"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "84ad616"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixFixPathConfinementDoD : Test { :>> id = "7a5a034b-0c4d-4c67-998c-4ad5439772d2"; :>> method = VerificationMethod::demo; :>> procedureText = "apply.rs now refuses to CreateDir/Chown/Chmod a critical system root (exact-match denylist: /, /etc, /usr, /bin, /sbin, /boot, /lib, /lib64, /sys, /proc, /dev, /run, /var/run, /root, /usr/{bin,sbin,lib}) even on explicit confirmation — so a typo or hostile compose naming `/etc` as a bind source can't chown it. Legitimate absolute data binds under a subpath (/etc/myapp, /srv/data, /var/lib/x) are unaffected — that is `yd fix`'s intended purpose (fixing the host bind dirs the operator's own compose declares, gated behind --yes / the web confirm + loopback + CSRF). New unit test asserts the refusals and the allowed subpaths."; }
    part fixFixPathConfinementDoDR1 : TestResult { :>> id = "25e80eb4-ed25-4215-98e5-513691f24968"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "84ad616"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixUpdatePolicyNarrowingDoD : Test { :>> id = "90300c68-bf0d-44f3-82f2-7e0ed1d5a2ba"; :>> method = VerificationMethod::demo; :>> procedureText = "workload.rs has_persistent_mount now ignores READ-ONLY mounts (short-syntax `:ro` mode and long-syntax `read_only: true`), so a stateless service that mounts a read-only config file is no longer forced to notify-only — resolving the over-cautious edge from the kind removal. A writable data bind/volume still keys notify-only (the safety property held). New unit test covers a `:ro` config mount (not data) vs a writable bind (data)."; }
    part fixUpdatePolicyNarrowingDoDR1 : TestResult { :>> id = "81463480-98c5-4d74-8a3d-3bb4df16ff47"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "84ad616"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixUiConcisionNitsDoD : Test { :>> id = "4588c753-c750-489b-9192-8741d1a72cf5"; :>> method = VerificationMethod::demo; :>> procedureText = "ui.html: the console dock now appends a single line in the common case (full rebuild only on the first line or a 300-line trim) instead of re-rendering the whole buffer on every logLine (was O(n^2)); confirmAct resolves true/false and its callers (upgrade, apply-fixes, restore, backup, fleet backup-all) skip their follow-up render on cancel — and fleet 'Back up all' now passes the real response to fleetResults (it was silently getting undefined before). 28 Playwright UI tests green."; }
    part fixUiConcisionNitsDoDR1 : TestResult { :>> id = "17fe3ea7-882e-407c-b156-f0dded933f58"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "84ad616"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate61 : Test { :>> id = "43a470d1-38c9-470e-97d4-90b24f88318b"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (3); charter to needSecureByDefault. The four lower-severity findings filed open by the critique battery (issTermReadCsrf, issFixPathConfinement, issUpdatePolicyNarrowing, issUiConcisionNits) are pulled and sequenced, correctness/security first."; }
    part refineGate61R1 : TestResult { :>> id = "0ccf5b1b-b0cd-4811-ad4b-1c8b84df8aea"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "84ad616"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate61 : Test { :>> id = "36571f7a-6882-4402-84c9-d67fd0d2febc"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery. (correctness) each fix verified: the POST read + GET-405 + text/plain-415 proven live; the protected-path guard + the :ro-exclusion by new unit tests; the UI nits by the green matrix. (security) the draining read is now CSRF-gated and the fix guard blocks catastrophic system-root mutation while preserving legitimate absolute data binds (proportionate — not over-confining a core feature). (correctness of the policy refinement) the :ro exclusion tightens toward accuracy without weakening the data-mount safety property. (surprise found + fixed) fleet 'Back up all' was passing undefined to fleetResults — now fixed. No finding regressed; 149 Rust + 28 Playwright green."; }
    part reviewGate61R1 : TestResult { :>> id = "c300b966-3069-4310-862f-432091c3d290"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "84ad616"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate61 : Test { :>> id = "b7d55235-d3ed-4a84-9985-0ac4f128da6c"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issTermReadCsrf, issFixPathConfinement, issUpdatePolicyNarrowing, issUiConcisionNits all resolved. The entire critique-battery backlog is now clear. cargo build + 149 Rust tests + 28 Playwright UI tests green; live terminal/CSRF/guard re-verified; keel validate + guard green; 0 open issues."; }
    part closeOutGate61R1 : TestResult { :>> id = "7e8ac88f-66ec-48fe-91e3-fcd863e2099e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "84ad616"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
