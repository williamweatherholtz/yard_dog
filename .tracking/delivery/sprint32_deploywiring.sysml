// =====================================================================
// YardDog — Sprint 32 delivery: fix the live deploy versioning-repo wiring.
// Resolves issDeployRepoWiring (High), found by real-Docker testing. Includes a
// live demo: a real compose stack deploys, runs healthy, and rolls back.
// =====================================================================
package Sprint32DeployWiring {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyDeployWiring : Story {
        :>> id = "f28708c9-5b28-4786-a825-92f1355a74b0";
        :>> title = "Version the stack dir itself and ensure the repo exists so live deploy/rollback work";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p0;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyDeployWiring to needSafeDeploy;

    action ensureRepo;
    verification ensureRepoDoD : Test { :>> id = "1de61624-d44d-45ba-9bfc-784bc360cfa2"; :>> method = VerificationMethod::test; :>> procedureText = "gitver::ensure_repo(dir) initializes a git repo (with the opinionated ignore/attributes) when dir has no .git, and is a no-op when dir is already a repo; unit-tested (fresh dir gets a .git + snapshot works; second call does not clobber)."; }
    part ensureRepoDoDR1 : TestResult { :>> id = "a0ba6ffa-06a1-433c-92a5-f188d0e2fb44"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2658a78"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action deployVersionsStackDir;
    verification deployVersionsStackDirDoD : Test { :>> id = "9320ca5c-4c49-4468-bf7a-f715726d2d5a"; :>> method = VerificationMethod::demo; :>> procedureText = "Against a real Docker daemon: `yd deploy <compose> --yes` on a fresh stack initializes the stack dir as the versioning repo, snapshots the actual compose, brings the container up HEALTHY (up -d --wait), and reports Deployed; a follow-up deploy of a broken image regresses (RegressFailed/RolledBack) and restores the last-good compose. Demonstrated and the container observed running via `docker ps`." ; }
    part deployVersionsStackDirDoDR1 : TestResult { :>> id = "9f4ac27c-108a-42c8-92a5-f188d2290ea8"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2658a78"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate32 : Test { :>> id = "f0c687e4-fd79-487a-b06b-82627759eb10"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; triaged High field Issue issDeployRepoWiring with a #Resolves resolver; fix = version the stack dir + ensure_repo; validated by a live demo against Docker."; }
    part refineGate32R1 : TestResult { :>> id = "52f73bd6-1b4d-4d3c-9145-4ed4487630dd"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2658a78"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate32 : Test { :>> id = "159199f7-5cbf-4c47-8183-abf3cf70094b"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: DoD green (104 lib + 22 integration, 0 warnings) + a live Docker demo. run_deploy now versions the stack dir itself via gitver::ensure_repo (init if no .git, no-op otherwise), so snapshots capture the real compose; run_upgrade ensure_repos its --repo likewise. LIVE against Docker 29.5/Compose v5: a fresh `yd deploy` pulled nginx, came up HEALTHY via up -d --wait, reported Deployed, HTTP 200; a subsequent broken-healthcheck deploy failed the gate, regressed, redeployed the restored good compose (RolledBack), and the live container ended healthy on the good config with a git audit trail (snapshot/snapshot/restore)."; }
    part reviewGate32R1 : TestResult { :>> id = "5209492f-4042-4f2d-bc26-0577d7f3e0ee"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2658a78"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate32 : Test { :>> id = "93d77919-e3ee-4068-8e0b-a8c414da46a4"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass (incl. live demo); issDeployRepoWiring resolved via #Resolves. The deploy safety model is now proven end-to-end against a real daemon: health-gated deploy and complete rollback both work on live containers. Deferred live seams remaining: real registry-digest resolution, running-state introspection, self-update apply."; }
    part closeOutGate32R1 : TestResult { :>> id = "4ca6b6dd-7638-4015-a073-24e9648dcf71"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2658a78"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
