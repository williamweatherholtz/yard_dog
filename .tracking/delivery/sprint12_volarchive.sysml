// =====================================================================
// YardDog — Sprint 12 delivery: named-volume archiving.
// A pure volume-archive argv builder + archive_volume over a DockerRunner seam +
// a DockerVolumeArchiver Archiver impl; main wires the real docker runner.
// =====================================================================
package Sprint12VolArchive {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyVolArchive : Story {
        :>> id = "7583f0bb-fbab-4ac5-a7fe-eb96a2631270";
        :>> title = "Named-volume archiving via a throwaway tar container";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyVolArchive to needBackupCoverage;

        action volumeArchiveArgv;
        verification volumeArchiveArgvDoD : Test { :>> id = "49b19543-ee81-4bea-8741-d26eccea23f2"; :>> method = VerificationMethod::test; :>> procedureText = "volume_archive_argv(volume, dest) builds the docker run argv (--rm, -v <vol>:/src:ro, -v <dest>:/backup, alpine, tar of /src to /backup/<vol>.tar.gz); unit-tested for the key args and output filename."; }
        part volumeArchiveArgvDoDR1 : TestResult { :>> id = "5d6a72e3-10f3-4d47-b2f0-db37cc5cf1a1"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "169ac92"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action archiveVolume;
        verification archiveVolumeDoD : Test { :>> id = "558dd595-6444-4ade-8741-d26ecdac7b1e"; :>> method = VerificationMethod::test; :>> procedureText = "archive_volume(volume, dest, &DockerRunner) runs the built argv via the runner; a recording-runner unit test asserts the runner is called once with the expected argv."; }
        part archiveVolumeDoDR1 : TestResult { :>> id = "50ce028c-5d42-462b-b2f0-db37cd5a9095"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "169ac92"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action volumeArchiver;
        verification volumeArchiverDoD : Test { :>> id = "abe732d2-c43b-4f16-8741-d26ece645c2a"; :>> method = VerificationMethod::test; :>> procedureText = "DockerVolumeArchiver implements Archiver: a Volume target routes to archive_volume via the runner; unit-tested with a recording runner that the volume is archived (bind/network are left to the fs archiver)."; }
        part volumeArchiverDoDR1 : TestResult { :>> id = "25a153ed-ad46-440f-b2f0-db37ceb37529"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "169ac92"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint12Backlog { }

    verification refineGate12 : Test { :>> id = "e2f9da37-6838-4d58-833c-ee924ac1dc55"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope clear; DoD tasks authored; builds on the backup Archiver seam."; }
    part refineGate12R1 : TestResult { :>> id = "9a859489-abed-4eda-8741-d26ed09e531a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "169ac92"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate12 : Test { :>> id = "6acb422e-5b22-4650-b595-6fc5b8c95f4c"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (50 lib + 11 integration, 0 warnings); volume_archive_argv + archive_volume + DockerVolumeArchiver; RealArchiver now archives named volumes via docker instead of skipping."; }
    part reviewGate12R1 : TestResult { :>> id = "d92712f4-8d55-4a46-a2ff-cc7eb7324d3e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "169ac92"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate12 : Test { :>> id = "a064f351-9d27-40b9-aef5-15a1a29f9a42"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srVolumeArchive verified; backup coverage now spans DB dumps + binds + named volumes + remote."; }
    part closeOutGate12R1 : TestResult { :>> id = "cc0e806b-8cba-4332-a2ff-cc7eb843e6a6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "169ac92"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
