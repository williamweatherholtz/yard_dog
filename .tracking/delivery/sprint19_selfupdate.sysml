// =====================================================================
// YardDog — Sprint 19 delivery: program self-update (detection).
// version_is_newer + ReleaseSource seam + check; `yd self-update`.
// =====================================================================
package Sprint19SelfUpdate {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storySelfUpdate : Story {
        :>> id = "970983ce-a91b-48c4-a3b7-1f6e32fbcfdf";
        :>> title = "Self-update detection (version compare + release check) + `yd self-update`";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storySelfUpdate to needSelfUpdate;

        action versionCompare;
        verification versionCompareDoD : Test { :>> id = "59216722-f93f-4081-9f0e-ead78561b4bb"; :>> method = VerificationMethod::test; :>> procedureText = "version_is_newer(current, latest) does a semantic (major.minor.patch) comparison, tolerant of a leading 'v'; unit-tested (newer, equal, older, v-prefixed)."; }
        part versionCompareDoDR1 : TestResult { :>> id = "233ebcf4-7af8-4443-bf38-c19e6558accd"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "cbb298c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action selfUpdateCheck;
        verification selfUpdateCheckDoD : Test { :>> id = "552265ef-9d21-47bd-9f0e-ead78630c107"; :>> method = VerificationMethod::test; :>> procedureText = "check(current, source) returns UpdateAvailable(version) when the release source reports a newer version, UpToDate when same/older, Unknown when the source has no answer; unit-tested with a stub source."; }
        part selfUpdateCheckDoDR1 : TestResult { :>> id = "ea2df424-6447-46e3-bf38-c19e6662f71d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "cbb298c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliSelfUpdate;
        verification cliSelfUpdateDoD : Test { :>> id = "1a8b405b-4003-41d9-9f0e-ead7870bd567"; :>> method = VerificationMethod::test; :>> procedureText = "yd self-update prints the current version and update status, degrading gracefully (exit 0) when no release info is available; integration test asserts it runs and prints the version."; }
        part cliSelfUpdateDoDR1 : TestResult { :>> id = "da58af59-5cf7-475f-bf38-c19e67af2c6d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "cbb298c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint19Backlog { }

    verification refineGate19 : Test { :>> id = "c5ae6f10-4952-4df1-addd-373d8275abce"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope clear; DoD tasks authored; apply-via-seam deferred to a later increment."; }
    part refineGate19R1 : TestResult { :>> id = "c9abe972-5a6c-42e1-9f0e-ead789a5f8a7"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "cbb298c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate19 : Test { :>> id = "86262e23-66dc-4177-a9a6-96a3b2b2fdd4"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (66 lib + 17 integration, 0 warnings); version_is_newer (semantic, v-tolerant), check over a ReleaseSource seam, `yd self-update`. Download/verify/atomic-replace apply is the next increment."; }
    part reviewGate19R1 : TestResult { :>> id = "e17a778b-2952-44fe-af47-b2e5747738d6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "cbb298c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate19 : Test { :>> id = "c1b3c17b-0101-4712-9822-1afbc1d03e17"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srSelfUpdateCheck verified; needSelfUpdate covered for detection (apply behind the seam)."; }
    part closeOutGate19R1 : TestResult { :>> id = "dd7b7657-cd34-4c3a-af47-b2e575881b6e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "cbb298c"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
