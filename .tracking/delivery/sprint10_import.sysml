// =====================================================================
// YardDog — Sprint 10 delivery: import / adopt existing compose stacks.
// import_stack copies an existing compose (+ .env) into the managed stacks
// directory, name-derived or explicit, no-clobber. `yd import`.
// =====================================================================
package Sprint10Import {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyImport : Story {
        :>> id = "830cf603-9d09-4cdf-9001-9f7f8a4bd0ae";
        :>> title = "Import/adopt an existing compose stack (`yd import`)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyImport to needImportAdopt;

        action importCompose;
        verification importComposeDoD : Test { :>> id = "a59ba81c-1930-4530-a3bb-4baaca5aec00"; :>> method = VerificationMethod::test; :>> procedureText = "import_stack copies a compose (+ sibling .env) into stacks_root/<name>/ without touching the original; unit-tested that the copied files exist and discover_stacks then finds the stack."; }
        part importComposeDoDR1 : TestResult { :>> id = "a7fe3f15-4b7f-421b-93e2-2563a95515d1"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3556ed7"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action importSafety;
        verification importSafetyDoD : Test { :>> id = "1ed9a704-b551-4998-a3bb-4baacb1dc860"; :>> method = VerificationMethod::test; :>> procedureText = "import_stack derives the stack name from the compose's parent directory when none is given, and returns AlreadyExists (no overwrite) if the target stack exists; unit-tested."; }
        part importSafetyDoDR1 : TestResult { :>> id = "0e498d1d-cdae-461b-93e2-2563aa682f99"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3556ed7"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliImport;
        verification cliImportDoD : Test { :>> id = "34a5b626-f0e1-42b4-a3bb-4baacbdfdd88"; :>> method = VerificationMethod::test; :>> procedureText = "yd import <compose> --into DIR [--name N] imports the stack; integration test asserts the stack directory + compose appear under DIR."; }
        part cliImportDoDR1 : TestResult { :>> id = "42efe514-c11d-4a9b-93e2-2563abbae945"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3556ed7"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint10Backlog { }

    verification refineGate10 : Test { :>> id = "4f6b24cf-41a9-44ef-b458-12098e0a32eb"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope clear; DoD tasks authored; reuses stacks discovery."; }
    part refineGate10R1 : TestResult { :>> id = "acda1c4e-0073-42f0-a3bb-4baace9bacb4"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3556ed7"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate10 : Test { :>> id = "46ae34be-c6ad-420f-a856-b7743421ae40"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (45 lib + 10 integration, 0 warnings); import_stack copies compose+.env, name-derives, no-clobber; `yd import` places the stack under the target."; }
    part reviewGate10R1 : TestResult { :>> id = "da58af59-5cf7-423a-b1a6-3cebaf28ce0e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3556ed7"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate10 : Test { :>> id = "7318fc60-d8ba-45b4-a68a-a70820cf81db"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srImportAdopt verified; needImportAdopt covered. All 18 Needs now have satisfying, verified requirements."; }
    part closeOutGate10R1 : TestResult { :>> id = "da6961e5-e2bd-4216-b1a6-3cebb03976d6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "3556ed7"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
