// =====================================================================
// YardDog — Sprint 5 delivery: backup retention + destination abstraction.
// A SnapshotStore abstraction (local now, remote-ready) and a keep-N retention
// policy, wired to `yd prune --dest DIR --keep N`.
// =====================================================================
package Sprint5Retention {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyRetention : Story {
        :>> id = "958d77a1-2988-4b79-bc7b-f07b55319a32";
        :>> title = "Backup retention (keep-N) over a pluggable SnapshotStore; yd prune";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyRetention to needRemoteBackup;

        action retentionPolicy;
        verification retentionPolicyDoD : Test { :>> id = "a792cf6f-845c-453f-97b0-24ff466661dd"; :>> method = VerificationMethod::test; :>> procedureText = "snapshots_to_prune(existing, keep) returns the oldest snapshots beyond keep-N (chronologically-sortable names); unit-tested incl. keep>=len (prune none) and keep=0."; }
        part retentionPolicyDoDR1 : TestResult { :>> id = "aa60d60e-7dcd-4265-a59b-164027911c23"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2c3a7ab"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action snapshotStore;
        verification snapshotStoreDoD : Test { :>> id = "4bbf6bdd-aa04-4bc7-97b0-24ff47237fed"; :>> method = VerificationMethod::test; :>> procedureText = "A SnapshotStore abstraction (list/remove) with a local-directory impl; apply_retention lists, computes prunes, removes them, and returns the removed set — recording-store unit test."; }
        part snapshotStoreDoDR1 : TestResult { :>> id = "42b72ee4-f843-422d-a59b-1640289f91a3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2c3a7ab"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliPrune;
        verification cliPruneDoD : Test { :>> id = "97d994d4-2afe-419f-97b0-24ff47e18f01"; :>> method = VerificationMethod::test; :>> procedureText = "yd prune --dest DIR --keep N removes oldest snapshot subdirs beyond N; integration test creates 3 named subdirs, keeps 2, asserts the oldest is gone and the newest two remain."; }
        part cliPruneDoDR1 : TestResult { :>> id = "d19f3606-5771-4b99-a59b-164029f0a1eb"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2c3a7ab"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint5Backlog { }

    verification refineGate5 : Test { :>> id = "7303b5c1-0259-4eca-81c1-87f4826c35ed"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope clear; DoD tasks authored; builds on Sprint 4 execution."; }
    part refineGate5R1 : TestResult { :>> id = "d13f1e03-b87a-470b-97b0-24ff4a0b174d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2c3a7ab"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate5 : Test { :>> id = "af24a8af-a193-479d-9914-0c02b35715e0"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (31 lib + 5 integration, 0 warnings); keep-N retention over a pluggable SnapshotStore, `yd prune --dest --keep` prunes oldest snapshots."; }
    part reviewGate5R1 : TestResult { :>> id = "b363b81d-d1f3-48c5-b7f1-e437e3f1b57b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2c3a7ab"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate5 : Test { :>> id = "c3811899-587b-4034-bba9-9337ebc52d0f"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srRetentionStore verified."; }
    part closeOutGate5R1 : TestResult { :>> id = "877c3463-41a3-4255-b7f1-e437e502415b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "2c3a7ab"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
