// =====================================================================
// YardDog — Sprint 69: configurable backup destination (BACKUP_ROOT). Operator-
// requested. Closes the "automatic backups live on the same disk as the data" gap
// surfaced during the compose-install review; complements (does NOT close) the
// still-open issBackupSnapshotLayer (timestamped multi-snapshot layer).
// =====================================================================
package Sprint69BackupRoot {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyBackupRoot : Story {
        :>> id = "4551d8b6-ce6f-4f61-8bca-d5e0635cb7b7";
        :>> title = "Configurable backup destination (BACKUP_ROOT / --backup-root)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyBackupRoot to needSecureByDefault;

    verification refineGate69 : Test { :>> id = "cc97cc75-7ffb-49d3-ac19-96747bf3c2a1"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (5); charter to needSecureByDefault (recoverability — get recovery points off the data's own disk). Operator asked (\"yes build please\") for a configurable backup root, and directed the name be unprefixed (BACKUP_ROOT, not YD_BACKUP_ROOT) since the container/service scopes it. Scope: a backup-root honored by the automatic pre-change backups and the UI \"Back up now\", defaulting to the stack-local .yd-backups when unset."; }
    part refineGate69R1 : TestResult { :>> id = "2998d83a-dcbd-45a7-ad49-c1720276881e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ff3dfb7"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification reviewGate69 : Test { :>> id = "68bfb77d-e5f8-4991-81c3-1e4b6b76f862"; :>> method = VerificationMethod::demo; :>> procedureText = "AI review. (design) backup::resolve_backup_dest(stack_dir, backup_root) returns <backup-root>/<stack-name> when set (off the data disk), else the git-excluded stack-local .yd-backups — unit-tested. Wired through: RealBackupHook (pre-change deploy/upgrade), `yd fleet backup`, and `yd serve` (which passes --backup-root to the deploy/upgrade it shells, and computes the /api/backup dest from it). Config surface per the operator's naming direction — UNPREFIXED BACKUP_ROOT: a clap `env = \"BACKUP_ROOT\"` fallback on `yd serve` (so the container/systemd just set the env — no fragile empty-arg flag bridging), plus `--backup-root` flags on deploy/upgrade/fleet. (security) the operator-configured root is trusted and may sit OUTSIDE the served stacks root (a mounted NAS); the client-supplied /api/backup dest is still safe_join-confined when no operator root is set. (human-factors) the Backups tab shows where recovery points go and nudges to set BACKUP_ROOT for off-disk storage; compose ships a commented NAS volume example; README + yd.env document it. (verified) end-to-end smoke: `fleet backup --backup-root <nas>` wrote <nas>/<stack>/manifest.json, NOT the stack-local default. 151 lib + 24 cli + 28 Playwright green; clean release build; `docker compose config` valid."; }
    part reviewGate69R1 : TestResult { :>> id = "9cfbd6b6-abf9-4a0d-a178-2dff88f4074b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ff3dfb7"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification closeOutGate69 : Test { :>> id = "35fd2de6-547f-421d-9cd4-e92c1343b1b8"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: BACKUP_ROOT shipped (resolver + all call sites + env/flag config + UI indicator + docs). cargo build clean (no warnings); 151 lib + 24 cli + 28 Playwright green; keel validate + guard green. This closes the same-disk-as-data gap for automatic backups; issBackupSnapshotLayer (timestamped multi-snapshot history under that root) stays OPEN for a Docker-daemon sprint."; }
    part closeOutGate69R1 : TestResult { :>> id = "39a8d41a-affc-4329-9653-b071ea5e03bd"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ff3dfb7"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }
}
