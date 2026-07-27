// =====================================================================
// YardDog — Sprint 11 delivery: remote backup transport.
// A Transport trait + sync_dir mirror, a LocalTransport (mounted/dir target),
// and `yd push`. Cloud/SFTP transports (rclone) drop in behind the seam later.
// =====================================================================
package Sprint11Transport {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyTransport : Story {
        :>> id = "bbda83e9-5ca5-46e8-9aad-5ffb037fdb0e";
        :>> title = "Remote backup transport (Transport trait + LocalTransport + `yd push`)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyTransport to needRemoteBackup;

        action transportSync;
        verification transportSyncDoD : Test { :>> id = "691eaf91-43a2-4e73-a92a-0d58c0aae34d"; :>> method = VerificationMethod::test; :>> procedureText = "sync_dir(local_dir, transport) sends every file (recursively, relative paths preserved) via a Transport; a recording-transport unit test asserts each file is pushed once with its relative path."; }
        part transportSyncDoDR1 : TestResult { :>> id = "e6344dda-65c4-441b-84c4-2abe31ab5699"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e8573a1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action localTransport;
        verification localTransportDoD : Test { :>> id = "cbae6868-edc3-4d7f-a92a-0d58c174c299"; :>> method = VerificationMethod::test; :>> procedureText = "LocalTransport writes each pushed file under a target directory (a stand-in remote); unit test round-trips a nested file and asserts it appears at the mirrored relative path."; }
        part localTransportDoDR1 : TestResult { :>> id = "67498f27-50f9-467f-84c4-2abe32a82621"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e8573a1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliPush;
        verification cliPushDoD : Test { :>> id = "d4c1fd04-c7af-439b-a92a-0d58c2315a49"; :>> method = VerificationMethod::test; :>> procedureText = "yd push --from DIR --to DIR2 mirrors the backup to the target; integration test asserts a nested file appears under DIR2 at the same relative path."; }
        part cliPushDoDR1 : TestResult { :>> id = "00c58aef-05f0-4657-84c4-2abe33ffda05"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e8573a1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint11Backlog { }

    verification refineGate11 : Test { :>> id = "284bb225-b383-40a9-9986-5b9077912573"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope clear; DoD tasks authored; builds on the local backup/retention store."; }
    part refineGate11R1 : TestResult { :>> id = "b1e8b2fc-b3b1-4f73-a92a-0d58c4a2a805"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e8573a1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate11 : Test { :>> id = "018a3605-d201-4c64-a1a4-b90fe169c8af"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (47 lib + 11 integration, 0 warnings); sync_dir mirrors recursively via a Transport, LocalTransport writes to a target, `yd push` mirrors end-to-end."; }
    part reviewGate11R1 : TestResult { :>> id = "3ff47fe9-26fe-455d-8040-65959b21ff2f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e8573a1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate11 : Test { :>> id = "615a4a5e-0fa6-4b4f-836d-d9b444e242af"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srRemoteTransport verified; needRemoteBackup now covered by a first-class transport seam (cloud/SFTP transports drop in later)."; }
    part closeOutGate11R1 : TestResult { :>> id = "69ac2620-8348-4331-8040-65959c2a796f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "e8573a1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
