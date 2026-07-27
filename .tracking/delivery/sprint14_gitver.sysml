// =====================================================================
// YardDog — Sprint 14 delivery: git-backed config versioning.
// gitver module (init/snapshot/history/restore via shell-out git), `yd version`
// CLI, safe_deploy migrated to git, copy-based history retired.
// =====================================================================
package Sprint14GitVer {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyGitVer : Story {
        :>> id = "45a95764-93c5-4472-8a0a-44cea5a89ec5";
        :>> title = "Git-backed versioning (gitver + `yd version`), safe_deploy migrated, copy-history retired";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 8;
    }

    #CharteredBy dependency from storyGitVer to needVersionedCompose;

        action gitInit;
        verification gitInitDoD : Test { :>> id = "f215e915-3921-494f-9816-015fbde98ea9"; :>> method = VerificationMethod::test; :>> procedureText = "gitver::init(dir) creates a git repo and writes an opinionated .gitignore (excludes .yd-backups, common data dirs, .env/secret files) + .gitattributes (eol=lf); unit-tested against a temp dir (git present)."; }
        part gitInitDoDR1 : TestResult { :>> id = "e8f1a1ec-d96f-44d9-9d4d-15dd2009693f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1e87ce8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action gitSnapshotHistory;
        verification gitSnapshotHistoryDoD : Test { :>> id = "031cca45-1013-494b-9816-015fbea2bce9"; :>> method = VerificationMethod::test; :>> procedureText = "gitver::snapshot(dir,msg) commits as the bot committer and returns a sha; history(dir) lists commits newest-first; a .env and a data dir are NOT committed (respected by .gitignore); unit-tested."; }
        part gitSnapshotHistoryDoDR1 : TestResult { :>> id = "15715209-649a-4725-9d4d-15dd211176e7"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1e87ce8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action gitRestore;
        verification gitRestoreDoD : Test { :>> id = "08cf86c9-534e-4ab3-9816-015fbf67123d"; :>> method = VerificationMethod::test; :>> procedureText = "gitver::restore(dir,sha) restores a prior version's file content by creating a NEW commit (working tree matches the old version, HEAD advances, not detached); unit-tested."; }
        part gitRestoreDoDR1 : TestResult { :>> id = "97b78dea-b27b-45a1-9d4d-15dd22877067"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1e87ce8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action migrateSafeDeploy;
        verification migrateSafeDeployDoD : Test { :>> id = "32b9e676-ade1-4c7b-9816-015fc01f85c5"; :>> method = VerificationMethod::test; :>> procedureText = "safe_deploy uses gitver for snapshot + rollback (restore-as-new-commit); the copy-based stacks history (snapshot_config/list_history/rollback_config) is removed; deploy unit tests updated to a git repo and the failure case still restores last-good."; }
        part migrateSafeDeployDoDR1 : TestResult { :>> id = "2803eae6-df95-4379-9d4d-15dd23f98ae3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1e87ce8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliVersion;
        verification cliVersionDoD : Test { :>> id = "c6290a71-4b37-4f0b-9816-015fc0e61569"; :>> method = VerificationMethod::test; :>> procedureText = "yd version snapshot|history --repo DIR works end-to-end; integration test snapshots a change then asserts history lists it."; }
        part cliVersionDoDR1 : TestResult { :>> id = "a7fe3f15-4b7f-4d75-9d4d-15dd255cb1a3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1e87ce8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint14Backlog { }

    verification refineGate14 : Test { :>> id = "c718f7c3-a619-4d2c-b883-cb0c9b55070b"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (8 — larger: new module + migration + retirement); charter edge set; scope clear; DoD tasks authored; realizes accepted decGitVersioning."; }
    part refineGate14R1 : TestResult { :>> id = "d0ce5374-93bd-49b3-9816-015fc39aa649"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1e87ce8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate14 : Test { :>> id = "cefc954e-a9b0-47e1-857b-c03e71032d02"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 5/5 DoD green (53 lib + 12 integration, 0 warnings); gitver (init/snapshot/history/restore, secrets+data excluded, restore-as-new-commit); safe_deploy migrated to git; copy-based history retired; `yd version` shipped."; }
    part reviewGate14R1 : TestResult { :>> id = "f390ee36-5764-4771-81ee-bd93ffc4163b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1e87ce8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate14 : Test { :>> id = "1fcfdc8a-87ef-41fa-98ac-16f0639a1ef8"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 5/5 DoD pass; srGitVersioning verified; decGitVersioning realized; needVersionedCompose re-covered by git (srConfigHistory superseded)."; }
    part closeOutGate14R1 : TestResult { :>> id = "76d56b36-09a9-4e11-81ee-bd9400d7bc3f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1e87ce8"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
