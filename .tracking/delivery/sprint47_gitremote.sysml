// =====================================================================
// YardDog — Sprint 47 delivery: git-remote sync of the config monorepo.
// =====================================================================
package Sprint47GitRemote {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyGitRemote : Story {
        :>> id = "16c9aff6-a67e-440a-9176-a596dd6153e2";
        :>> title = "Connect a git remote and push/pull the config monorepo (UI + CLI)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyGitRemote to needRemoteConfigSync;

    action gitverRemote;
    verification gitverRemoteDoD : Test { :>> id = "369f4377-19fa-4290-bcb8-637ae558b698"; :>> method = VerificationMethod::test; :>> procedureText = "gitver gains set_remote/remote_url/push/pull/ahead_behind; unit-tested against a LOCAL BARE repo (deterministic, no auth): set a remote, push, a fresh clone has the pushed config, ahead_behind reports (0,0) after push and (1,_) after a new local snapshot."; }
    part gitverRemoteDoDR1 : TestResult { :>> id = "4c9b4f0e-d10a-4518-8d5d-7e65b55b0c00"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "887987e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action gitRemoteLive;
    verification gitRemoteLiveDoD : Test { :>> id = "53269737-1690-449e-a414-ec41407029f5"; :>> method = VerificationMethod::demo; :>> procedureText = "Live against yd serve: serve() gives the monorepo an initial commit; POST /api/git/connect (validated URL — https/ssh/git@/file/absolute), /api/git/push, GET /api/git (remote + ahead/behind); the UI header 'Git' panel shows status and Connect/Push/Pull. Verified: connect + push sent the whole monorepo to a bare remote (a clone shows app/docker-compose.yml), status = 0 ahead 0 behind; `yd git status` matches. Auth is delegated to system git; no tokens stored."; }
    part gitRemoteLiveDoDR1 : TestResult { :>> id = "9987db6c-28c6-4bbf-b3af-cea5ee93b10e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "887987e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    #Verify dependency from gitRemoteLiveDoD to ucGitRemote;

    verification refineGate47 : Test { :>> id = "3efe8a5c-0e8c-4107-a96b-994602cda1fc"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edge set; SR srGitRemoteSync satisfies needRemoteConfigSync; scope = connect/push/pull the monorepo from UI + CLI, auth via system git (no token storage), enabled by the Sprint 46 monorepo."; }
    part refineGate47R1 : TestResult { :>> id = "d9752dbd-83e9-4a9d-89a7-65c7b00a65f2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "887987e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate47 : Test { :>> id = "573e86bb-cf1a-4ec0-a19f-312d21634008"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 2/2 DoD green (123 lib + 23 integration, 0 warnings). Secure by design: auth delegated to the operator's git (no token handling/storage); connect validates the URL scheme; all POSTs behind the loopback + anti-CSRF gate. UI adds a global Git panel (status + connect/push/pull); CLI adds `yd git remote/push/pull/status`. Verified live against a bare remote. Completes needRemoteConfigSync on the Sprint 46 monorepo."; }
    part reviewGate47R1 : TestResult { :>> id = "7a82cd4d-d9e5-47be-9624-d6b214429851"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "887987e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate47 : Test { :>> id = "523f1e60-ec40-4b8b-b6c7-f6d0392f59cb"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass; srGitRemoteSync verified; needRemoteConfigSync covered; ucGitRemote validated. The homelab's config can now be synced offsite to any git remote with one push, reusing the operator's own git auth. Remaining recorded UI use cases: import wizard, notifications, bulk ops."; }
    part closeOutGate47R1 : TestResult { :>> id = "234c7371-d752-4180-ba0d-cf05a6d13eef"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "887987e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
