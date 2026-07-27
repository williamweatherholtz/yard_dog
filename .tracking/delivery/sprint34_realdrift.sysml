// =====================================================================
// YardDog — Sprint 34 delivery: real running-state introspection for drift.
// Replaces the NoRunning stub with `docker compose ps --format json`; validates
// ucDriftDetection live against Docker.
// =====================================================================
package Sprint34RealDrift {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyRealDrift : Story {
        :>> id = "d830e396-17be-42ef-89a5-2cf7f46fac17";
        :>> title = "yd drift queries the real running stack (docker compose ps)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyRealDrift to needDriftDetection;

    action parseComposePs;
    verification parseComposePsDoD : Test { :>> id = "c36210aa-10fb-4eae-ad3b-c31f252e99a9"; :>> method = VerificationMethod::test; :>> procedureText = "drift::parse_compose_ps parses `docker compose ps --format json` (newline-delimited objects and a JSON array) into a running service->image map, and returns an empty map for empty output; unit-tested against the real output shape (Service + Image fields)."; }
    part parseComposePsDoDR1 : TestResult { :>> id = "3147a1c7-8d44-4006-95cb-cc23f2c938e8"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "32aab9e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action realDriftDemo;
    verification driftDemoDoD : Test { :>> id = "495b9ddf-9d8a-4b06-a442-9a524fc46423"; :>> method = VerificationMethod::demo; :>> procedureText = "Against real Docker (e2e_docker::e2e_uc_drift_detection + manual): after deploy `yd drift` reports 'no drift'; editing the declared image without redeploying reports ImageChanged (declared vs running); a stopped service reports Missing. run_drift shells out to `docker compose ps --format json` and returns None only when docker is unreachable."; }
    part driftDemoDoDR1 : TestResult { :>> id = "50d402fc-d8c3-4bc2-9167-501811b94942"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "32aab9e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    #Verify dependency from driftDemoDoD to ucDriftDetection;

    verification refineGate34 : Test { :>> id = "4539a0d7-a675-4e9f-a69f-8fd93a7d23a5"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope = replace the drift NoRunning stub with a real `docker compose ps` running-state (pure parser + thin adapter), add ucDriftDetection + an e2e test."; }
    part refineGate34R1 : TestResult { :>> id = "bbc242c7-c500-4142-9236-3693591ec747"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "32aab9e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate34 : Test { :>> id = "6140f485-0159-48cb-8ee5-c89285ea458c"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: DoD green (105 lib + 22 integration + 7 e2e, 0 warnings). parse_compose_ps is pure and unit-tested; run_drift's DockerRunning adapter shells out to `docker compose ps --format json`, None only on docker failure, empty map = nothing running. Live: no-drift after deploy, ImageChanged after an out-of-band edit, Missing when stopped; e2e_uc_drift_detection passes against Docker."; }
    part reviewGate34R1 : TestResult { :>> id = "da8e8b1d-4251-4104-862f-0e9c0f366e3f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "32aab9e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate34 : Test { :>> id = "f00e920f-1310-4b46-a51d-876562e5e62f"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass; ucDriftDetection validated live. The first deferred live-Docker seam (running-state introspection) is now real and E2E-proven. Remaining seams: registry-digest resolution for `yd updates`, and self-update download/apply."; }
    part closeOutGate34R1 : TestResult { :>> id = "85238c4d-ac0b-4c01-a74b-d4b9da2d9d54"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "32aab9e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
