// =====================================================================
// YardDog — Sprint 6 delivery: backup integrity manifest + verification.
// Capture a SHA-256 manifest at backup time and verify a backup still matches
// it; `yd verify --dest DIR` reports integrity.
// =====================================================================
package Sprint6Verify {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyVerify : Story {
        :>> id = "0bed8930-3ba8-451b-a420-9fda808c1436";
        :>> title = "Backup integrity manifest + `yd verify`";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyVerify to needRestoreVerification;

        action buildManifest;
        verification buildManifestDoD : Test { :>> id = "0fb93a9b-c3c5-42e9-849c-89b2420e14cb"; :>> method = VerificationMethod::test; :>> procedureText = "build_manifest(dir) records SHA-256 + size for every file (skipping manifest.json), round-trips through JSON; unit-tested over a nested tempdir."; }
        part buildManifestDoDR1 : TestResult { :>> id = "a34fc069-3739-4dc0-b4c3-636afd94f7e8"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2d32887"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action verifyManifest;
        verification verifyManifestDoD : Test { :>> id = "da96c072-836c-4e71-849c-89b242d2e8af"; :>> method = VerificationMethod::test; :>> procedureText = "verify(dir, manifest) returns empty when intact and reports Missing/Changed entries when a file is deleted or altered; unit-tested."; }
        part verifyManifestDoDR1 : TestResult { :>> id = "83227616-a429-422c-b4c3-636afea7d1a0"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2d32887"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliVerify;
        verification cliVerifyDoD : Test { :>> id = "7cf39760-1406-4071-849c-89b24393dd2b"; :>> method = VerificationMethod::test; :>> procedureText = "backup --run writes manifest.json into the destination; yd verify --dest DIR reports integrity; integration test asserts a fresh backup verifies clean and a corrupted file is reported."; }
        part cliVerifyDoDR1 : TestResult { :>> id = "41c9a053-19a7-42e0-b4c3-636b001bf4d0"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2d32887"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint6Backlog { }

    verification refineGate6 : Test { :>> id = "59559a3b-586d-4ca9-be19-42be5a997cfd"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope clear; DoD tasks authored; builds on Sprint 4 execution (writes a manifest into the destination)."; }
    part refineGate6R1 : TestResult { :>> id = "926ae622-d8c9-4181-849c-89b2459746df"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2d32887"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate6 : Test { :>> id = "e7bdbd1b-b05b-45f3-9f04-0ae3c97e3873"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (34 lib + 6 integration, 0 warnings); backup writes a SHA-256 manifest and `yd verify` reports clean then flags tampering (non-zero exit)."; }
    part reviewGate6R1 : TestResult { :>> id = "bdd5a5da-af3a-4415-bbac-e7d285226653"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2d32887"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate6 : Test { :>> id = "593771e5-d327-4cdc-adf3-1ee0284d9f66"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srBackupVerify verified; needRestoreVerification now covered."; }
    part closeOutGate6R1 : TestResult { :>> id = "1fb08650-4397-4701-bbac-e7d2862f89ef"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2d32887"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
