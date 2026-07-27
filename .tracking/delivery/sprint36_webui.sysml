// =====================================================================
// YardDog — Sprint 36 delivery: loopback browser control plane (yd serve).
// A thin, well-built UI over the CLI; secure by default. Validates
// srBrowserControlPlane + ucBrowserControlPlane live.
// =====================================================================
package Sprint36WebUi {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyWebUi : Story {
        :>> id = "5325bf9f-9365-4e3c-8ec7-12e9311d1411";
        :>> title = "yd serve: loopback browser control plane over the CLI";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 8;
    }

    #CharteredBy dependency from storyWebUi to needOperationalVisibility;
    #CharteredBy dependency from storyWebUi to needSecureByDefault;

    action webSecurity;
    verification webSecurityDoD : Test { :>> id = "39cccb9f-905c-41e0-9c75-272a9ebcd243"; :>> method = VerificationMethod::test; :>> procedureText = "Unit tests for the security primitives: host_is_loopback accepts 127.0.0.0/8, ::1, localhost (with/without port) and rejects domains (incl. 127.evil.com) and LAN IPs; safe_join allows plain relative paths and rejects `..`, RootDir (/etc), and Windows drive prefixes on every platform; only the four lifecycle events are accepted; handle_action rejects out-of-root paths and invalid events with 400."; }
    part webSecurityDoDR1 : TestResult { :>> id = "f3996631-e121-4556-aad4-30768f344d37"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ff7c5d9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action uiServe;
    verification uiServeDoD : Test { :>> id = "4ee18b7a-0d38-412c-9517-291d7b9ac678"; :>> method = VerificationMethod::demo; :>> procedureText = "Live: `yd serve --root <dir>` binds 127.0.0.1:8770 and serves the SPA + JSON API. GET /api/stacks and /api/stack return structured data (services, kind, guardrails, preflight, lifecycle); POST /api/deploy actually deploys (webapp-web up healthy), POST /api/lifecycle transitions to active. Security verified live: forged Host => 403, `..` traversal => refused, GET on /api/deploy => 405."; }
    part uiServeDoDR1 : TestResult { :>> id = "634f5c34-9dfa-4c1a-9fd2-7352ff8c8824"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ff7c5d9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    #Verify dependency from uiServeDoD to ucBrowserControlPlane;

    verification refineGate36 : Test { :>> id = "1609e546-4481-4168-b819-01fa70510f92"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (8); charter edges set; SR srBrowserControlPlane satisfies needOperationalVisibility + needSecureByDefault; scope per human decisions = full control plane, loopback-only + no auth; thin wrapper (lib for reads, yd binary for actions); tiny_http; secure-by-default primitives unit-tested."; }
    part refineGate36R1 : TestResult { :>> id = "e97b288b-65dc-4ba8-a8c6-d3d9103331dc"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ff7c5d9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate36 : Test { :>> id = "21c91efc-c938-4fec-88cd-5beb4b14deac"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 2/2 DoD green (113 lib + 22 integration + opt-in, 0 warnings). web.rs is a thin wrapper: read views computed from the library (stacks/services/kind/guardrails/preflight/lifecycle), actions exec the yd binary via an arg vector (no shell => no injection). Secure by default: binds 127.0.0.1 only, Host-allowlist rejects non-loopback (DNS-rebinding defense), safe_join confines paths under the root (Normal/CurDir only), POST-only mutations, event allow-list, no secret values rendered. Well-built theme-aware SPA (ui.html) with a stack rail, detail pane, and action console. All verified live against Docker."; }
    part reviewGate36R1 : TestResult { :>> id = "bb81a363-fdb0-48c3-a561-02e70d541ab6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ff7c5d9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate36 : Test { :>> id = "b871e46c-7f74-4e69-a9b5-db811828f0d5"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass; srBrowserControlPlane verified; needOperationalVisibility + needSecureByDefault covered. The browser control plane is live and secure-by-default; the safe_join test caught a real Windows path-traversal gap (is_absolute misses '/etc') fixed in-sprint."; }
    part closeOutGate36R1 : TestResult { :>> id = "9afdcf50-ef6e-4226-813d-d6029eb91a5a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ff7c5d9"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
