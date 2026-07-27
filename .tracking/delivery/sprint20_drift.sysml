// =====================================================================
// YardDog — Sprint 20 delivery: drift detection.
// detect_drift (pure diff) + RunningState seam + drift_report; `yd drift`.
// =====================================================================
package Sprint20Drift {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyDrift : Story {
        :>> id = "01907186-2753-419b-b6e2-7eaeaa32e494";
        :>> title = "Config-vs-running drift detection (`yd drift`)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyDrift to needDriftDetection;

        action detectDrift;
        verification detectDriftDoD : Test { :>> id = "5cf3ab9a-21a5-4e56-8ad5-dc120337596e"; :>> method = VerificationMethod::test; :>> procedureText = "detect_drift(declared, running) reports Missing (declared not running), Unexpected (running not declared), and ImageChanged (differing image), and nothing when they match; unit-tested."; }
        part detectDriftDoDR1 : TestResult { :>> id = "c0f311ef-c1dc-4e44-a1e0-4015d31f610c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "066c417"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action driftReport;
        verification driftReportDoD : Test { :>> id = "8c7a1885-6f1b-4976-8ad5-dc1203feab36"; :>> method = VerificationMethod::test; :>> procedureText = "drift_report(yaml, running_state) builds declared images from the compose and compares against the running state, returning None when the running state is unavailable; unit-tested with a fixture running state."; }
        part driftReportDoDR1 : TestResult { :>> id = "03f3a990-9e59-45cc-a1e0-4015d42f4238"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "066c417"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliDrift;
        verification cliDriftDoD : Test { :>> id = "7609e38d-a38f-4416-8ad5-dc1204bbbcc6"; :>> method = VerificationMethod::test; :>> procedureText = "yd drift <compose> reports drift or notes that the running state is unavailable, exiting 0; integration test asserts it runs and mentions the service or the unavailable note."; }
        part cliDriftDoDR1 : TestResult { :>> id = "8c7a1885-6f1b-49e4-a1e0-4015d5a1b9ac"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "066c417"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint20Backlog { }

    verification refineGate20 : Test { :>> id = "e1bd2e95-a90d-403e-9cbe-ce4cf42222cf"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope clear; DoD tasks authored; reuses compose image parsing; running-state fetch behind a seam."; }
    part refineGate20R1 : TestResult { :>> id = "7f34276f-cdd2-4242-8ad5-dc1206f0c6c6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "066c417"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate20 : Test { :>> id = "3a70b9fa-bfc3-4d47-89fa-b9b274f1b2c7"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (68 lib + 18 integration, 0 warnings); detect_drift (missing/unexpected/image-changed), drift_report over a RunningState seam, `yd drift` degrades gracefully. Running-state fetch (docker) is the next increment."; }
    part reviewGate20R1 : TestResult { :>> id = "2b320988-77fe-4f20-b437-0e0dcd50bd10"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "066c417"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate20 : Test { :>> id = "255f73b2-997a-422f-9adc-d440f7638f85"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srDriftDetection verified; needDriftDetection covered. Batch S16-S20 complete; all 25 Needs now addressed."; }
    part closeOutGate20R1 : TestResult { :>> id = "1160fc79-15c0-450c-b437-0e0dce5a8808"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "066c417"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
