// =====================================================================
// YardDog — Sprint 48 delivery: the Fleet layer (bulk ops, notifications,
// import/adopt) — fleet-scale operations across all stacks in one view.
// =====================================================================
package Sprint48Fleet {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyFleet : Story {
        :>> id = "b3ade8e6-fc69-42e9-a955-8eb92b7789ef";
        :>> title = "Fleet overview: notifications badge, bulk check/backup, and import/adopt";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyFleet to needOperationalVisibility;
    #CharteredBy dependency from storyFleet to needImportAdopt;

    action fleetModel;
    verification fleetModelDoD : Test { :>> id = "f2d6f1b6-cbe1-4966-9b29-e0107a57cd4b"; :>> method = VerificationMethod::test; :>> procedureText = "lifecycle::is_managed(dir) reports whether a stack is adopted (its .yd-lifecycle state file exists) — the 'adopted?' signal for the fleet scan and import/adopt; unit-tested (unadopted -> managed after write_state)."; }
    part fleetModelDoDR1 : TestResult { :>> id = "3230e0b7-6213-4c05-8d23-a7bd984de885"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "88918e6"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action fleetLive;
    verification fleetLiveDoD : Test { :>> id = "19daf326-204d-4f8f-97ce-de6f1aa0d759"; :>> method = VerificationMethod::demo; :>> procedureText = "Live against yd serve: /api/stacks carries an adopted flag + block/warn counts (cheap tier); the header notification badge shows the count of stacks with block-severity issues; POST /api/fleet/check and /api/fleet/backup fan out, running EACH stack through the per-stack guarded CLI (yd doctor / yd backup) and reporting per-stack results; POST /api/adopt sets Draft lifecycle + an initial monorepo snapshot (a stack flips unadopted->managed). A global Fleet UI view hosts the table (cheap status + lazy drift/update chips), bulk actions, and Adopt/Adopt-all. CLI `yd fleet status|check|backup` verified."; }
    part fleetLiveDoDR1 : TestResult { :>> id = "f3686b2e-fd50-4a8e-894f-6a60948754ef"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "88918e6"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    #Verify dependency from fleetLiveDoD to ucBulkOps;
    #Verify dependency from fleetLiveDoD to ucNotifications;
    #Verify dependency from fleetLiveDoD to ucImportWizard;

    verification refineGate48 : Test { :>> id = "3978fbde-2a29-4a07-90fd-16f35632421d"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edges set; architected as one Fleet layer (two-tier cheap/lazy status; pull-derived notifications; bulk = fan-out over the per-stack guarded path; adopt = lifecycle+snapshot) serving ucBulkOps + ucNotifications + ucImportWizard together."; }
    part refineGate48R1 : TestResult { :>> id = "62d0945c-c36e-4de2-a81c-ebffcfe1c58c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "88918e6"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate48 : Test { :>> id = "57fca801-e305-4d6f-ada7-3d45d869f1a7"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 2/2 DoD green (124 lib + 23 integration, 0 warnings). Deliberate architecture: cheap synchronous scan (/api/stacks + adopted) drives the badge + table instantly, expensive drift/update chips load lazily per row; notifications are pull-derived (no stateful event system); bulk backup/check fan out over the SAME per-stack guarded CLI (no bypass of guardrails/health-gate/rollback); adopt is the thin gap (Draft + snapshot). Global Fleet view + CLI `yd fleet`. All verified live."; }
    part reviewGate48R1 : TestResult { :>> id = "cf7520f8-1c2d-4d18-bc20-e200bc31657b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "88918e6"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate48 : Test { :>> id = "a4e6e666-88ca-42c3-8970-3ae50ba87a0b"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass; ucBulkOps, ucNotifications, ucImportWizard validated. All recorded UI use cases are now built. The Fleet layer gives the operator a single pane across stacks with attention badges, fleet-wide backup/check, and one-click adoption. Remaining roadmap: native install packages (deb/rpm, brew, scoop/winget, container decision)."; }
    part closeOutGate48R1 : TestResult { :>> id = "c47238b4-1a0c-414d-94e3-d4399bccbfa3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "88918e6"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
