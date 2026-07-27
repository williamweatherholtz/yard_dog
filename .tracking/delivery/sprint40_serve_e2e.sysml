// =====================================================================
// YardDog — Sprint 40 delivery: E2E regression guard for the web control plane.
// Boots `yd serve` and drives a real deploy over HTTP against Docker.
// =====================================================================
package Sprint40ServeE2E {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyServeE2E : Story {
        :>> id = "86dad26e-3e41-4179-880f-c6bd9080a0a9";
        :>> title = "E2E: boot yd serve and deploy a stack over HTTP";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 2;
    }

    #CharteredBy dependency from storyServeE2E to needOperationalVisibility;
    #CharteredBy dependency from storyServeE2E to needSecureByDefault;

    action serveE2E;
    verification serveE2EDoD : Test { :>> id = "2a840e83-fc88-4f4c-a7d7-68eadb8ea365"; :>> method = VerificationMethod::demo; :>> procedureText = "e2e_docker::e2e_serve_deploy_over_http: spawns the real `yd serve` binary on 127.0.0.1, polls readiness, POSTs /api/deploy with the anti-CSRF headers (application/json + loopback Origin), asserts the JSON reports ok/Deployed, and confirms the container reaches health=healthy — then tears down the server + container on drop. Runs opt-in in the e2e_docker suite (`cargo test --test e2e_docker -- --ignored --test-threads=1`)."; }
    part serveE2EDoDR1 : TestResult { :>> id = "648563c0-0c76-41c9-a7f8-57b2dad35514"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "68b2134"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    #Verify dependency from serveE2EDoD to ucBrowserControlPlane;

    verification refineGate40 : Test { :>> id = "20c330ff-66f3-47cc-8610-c162e7406a2a"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (2); charter edges set; scope = an opt-in E2E that boots yd serve and drives a real deploy over HTTP, regression-guarding the UI action path end to end."; }
    part refineGate40R1 : TestResult { :>> id = "ca89a024-9af5-4b72-9fed-369f1a69de82"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "68b2134"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate40 : Test { :>> id = "ff655008-97c8-4f95-8c6c-925f9ea4f0ac"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: DoD green. The test uses CARGO_BIN_EXE_yd to spawn the built binary, ureq (with a generous read timeout) to poll + POST, and a Drop guard to kill the server and remove the container even on failure. Full e2e_docker suite (9 tests) passes against Docker 29.5 / Compose v5 in ~62s with clean teardown; default `cargo test` stays hermetic (9 ignored)."; }
    part reviewGate40R1 : TestResult { :>> id = "342959d0-a839-48e0-b66d-5506d6a59c93"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "68b2134"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate40 : Test { :>> id = "69dfe883-0ca5-4a65-a8b5-62e8c2ae5b7c"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: serveE2E DoD pass. The browser control plane's action path is now regression-guarded end to end — a future change that breaks `yd serve` deploy will fail CI on a Docker-enabled runner. All three follow-ups (security lens, UI chips, serve E2E) delivered."; }
    part closeOutGate40R1 : TestResult { :>> id = "053b3c72-093d-4689-b983-8ba42e5a9eec"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "68b2134"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
