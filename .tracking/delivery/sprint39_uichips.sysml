// =====================================================================
// YardDog — Sprint 39 delivery: structured drift/updates + UI status chips.
// Lifts the docker running-state + local-digest adapters into the library so
// the web layer returns typed JSON; the UI renders per-service chips.
// =====================================================================
package Sprint39UiChips {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyUiChips : Story {
        :>> id = "d939a52c-8175-4f46-87c5-709942c91123";
        :>> title = "Structured drift/updates endpoints + per-service UI status chips";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyUiChips to needOperationalVisibility;

    action driftUpdatesChips;
    verification driftUpdatesChipsDoD : Test { :>> id = "5dd271b6-cfa1-41ad-8ad1-1f87abd426fc"; :>> method = VerificationMethod::demo; :>> procedureText = "The docker running-state + local-digest adapters are lifted into the library (drift::running_images_via_docker, updates::local_image_digest), removing the duplication in main. GET /api/drift and /api/updates now return typed JSON; verified live: updates => {web, UpToDate, none}; drift in-sync => empty; after an out-of-band image edit => {web, changed, declared, running}. The UI detail view auto-loads these into per-service Status chips (in sync / drift / not running; up-to-date / update / unknown)."; }
    part driftUpdatesChipsDoDR1 : TestResult { :>> id = "c7b1382e-46fc-42a4-8f50-4b47a3088275"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "792fef4"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    #Verify dependency from driftUpdatesChipsDoD to ucBrowserControlPlane;

    verification refineGate39 : Test { :>> id = "02ef3302-510c-4a4d-864d-95b919100aaa"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope = replace the raw-stdout drift/updates web reads with typed JSON (lifting the docker adapters to lib) and render per-service status chips in the UI; serves needOperationalVisibility."; }
    part refineGate39R1 : TestResult { :>> id = "5ffcb0ba-05d5-4310-a135-f7bc3b8db8a5"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "792fef4"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate39 : Test { :>> id = "c55368ea-c4b8-40f3-95b2-64df05b97d54"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: DoD green (116 lib + 22 integration, 0 warnings). drift/updates docker adapters now live in the library and are shared by the CLI and web; /api/drift and /api/updates return structured items; the SPA renders drift + update chips per service, auto-loaded (non-blocking) on stack open with a manual refresh. Behavior-preserving refactor: existing CLI drift/updates and all tests unchanged/green."; }
    part reviewGate39R1 : TestResult { :>> id = "f931bfaf-b25e-4023-a097-b745bb8cbcf9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "792fef4"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate39 : Test { :>> id = "1e7f9a76-bd63-43bc-b8a9-633daed72c55"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: driftUpdatesChips DoD pass. The browser control plane now surfaces drift and update status at a glance (chips), not just console text — the operator sees what is out-of-sync or outdated per service without leaving the dashboard."; }
    part closeOutGate39R1 : TestResult { :>> id = "2217eecc-b42b-4afd-912a-8d93c64e0768"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "792fef4"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
