// =====================================================================
// YardDog — Sprint 7 delivery: base compose management.
// Files-on-disk stack discovery + versioned config history (snapshot/list/
// rollback). `yd stacks` and `yd config`.
// =====================================================================
package Sprint7Compose {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyCompose : Story {
        :>> id = "3218b68c-ac17-4943-927a-1b5f6ad9b85d";
        :>> title = "Stack discovery (files-on-disk) + versioned config history";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyCompose to needComposeManagement;
    #CharteredBy dependency from storyCompose to needFilesOnDisk;
    #CharteredBy dependency from storyCompose to needVersionedCompose;

        action discoverStacks;
        verification discoverStacksDoD : Test { :>> id = "94295746-7b1b-428b-897f-f0a1cb4c2245"; :>> method = VerificationMethod::test; :>> procedureText = "discover_stacks(root) returns each subdirectory containing a compose file (docker-compose.yml/.yaml or compose.yml/.yaml) as a Stack {name, compose_path}; unit-tested over a fixture tree incl. a non-stack dir."; }
        part discoverStacksDoDR1 : TestResult { :>> id = "2f807031-ed4c-4384-9099-45ec94f5c004"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0312065"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action snapshotConfig;
        verification snapshotConfigDoD : Test { :>> id = "b478a882-86ad-4237-897f-f0a1cc1fac2d"; :>> method = VerificationMethod::test; :>> procedureText = "snapshot_config copies a stack's compose (+ .env if present) into a numbered history dir and list_history returns versions newest-first; unit-tested over a tempdir."; }
        part snapshotConfigDoDR1 : TestResult { :>> id = "8def20ec-c2cc-45b4-9099-45ec95edc68c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0312065"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action rollbackConfig;
        verification rollbackConfigDoD : Test { :>> id = "14a5ca60-fe7f-44b3-897f-f0a1ccf712c1"; :>> method = VerificationMethod::test; :>> procedureText = "rollback_config restores a chosen history version back to the stack's compose on confirmation and does nothing without it; unit-tested."; }
        part rollbackConfigDoDR1 : TestResult { :>> id = "80bfdf1d-71db-4690-9099-45ec9744495c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0312065"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliCompose;
        verification cliComposeDoD : Test { :>> id = "3a25b935-35d2-4d9b-897f-f0a1cdc0e781"; :>> method = VerificationMethod::test; :>> procedureText = "yd stacks --root DIR lists discovered stacks; integration test asserts a fixture stack is listed and a non-stack dir is not."; }
        part cliComposeDoDR1 : TestResult { :>> id = "50688fa0-60af-436c-9099-45ec988a47a8"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0312065"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint7Backlog { }

    verification refineGate7 : Test { :>> id = "4a82e319-b459-4f46-915b-7c74c0144c8c"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edges set; scope clear; DoD tasks authored."; }
    part refineGate7R1 : TestResult { :>> id = "0180600a-e644-4057-897f-f0a1cfd611bd"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0312065"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate7 : Test { :>> id = "6ac6e5e8-c0d3-4f8f-84b8-7ddbac250a25"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 4/4 DoD green (37 lib + 7 integration, 0 warnings); stack discovery + config snapshot/list/rollback, `yd stacks` lists only compose dirs."; }
    part reviewGate7R1 : TestResult { :>> id = "13858259-2199-4927-ae5d-5d74b9cd4f15"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0312065"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate7 : Test { :>> id = "b5899b9b-0a07-4038-b2f2-506969178f14"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 4/4 DoD pass; srStackDiscovery + srConfigHistory verified; needComposeManagement/needFilesOnDisk/needVersionedCompose covered."; }
    part closeOutGate7R1 : TestResult { :>> id = "72925c2f-bc86-4f67-ae5d-5d74bad873c1"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0312065"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
