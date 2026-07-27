// =====================================================================
// YardDog — Sprint 43 delivery: complete the UI tabs (Mounts, Permissions,
// Backups, Logs) + fix the backup relative-path bug found while building them.
// =====================================================================
package Sprint43UiTabs2 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyUiTabs2 : Story {
        :>> id = "c6f10c95-d622-4a85-b011-858c79e634bf";
        :>> title = "UI tabs: Mounts, Permissions/compliance, Backups, Logs + backup relative-path fix";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyUiTabs2 to needOperationalVisibility;
    #CharteredBy dependency from storyUiTabs2 to needSecureByDefault;

    action tabsComplete;
    verification tabsCompleteDoD : Test { :>> id = "2eb3c0be-a055-4b25-94f3-1b7b3c4e580c"; :>> method = VerificationMethod::demo; :>> procedureText = "Live against yd serve: Mounts tab (/api/mounts) shows per-mount type (host-bind/named/anon/network), existence, and remediation — a relative ./html bind resolves to exists=true; Permissions tab (/api/permissions) shows a COMPLIANT/NOT-COMPLIANT badge from the security lens + ownership (a privileged + docker-socket stack => NOT COMPLIANT with block findings); Backups tab (/api/backups) lists the recovery point with a verified/issues status; Logs tab (/api/logs) tails docker compose logs. Bind sources are resolved against the stack dir."; }
    part tabsCompleteDoDR1 : TestResult { :>> id = "bfc8d1ae-3dcc-4e34-9bcd-55bc3263b8f9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "58153e1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action fixBackupRelPath;
    verification fixBackupRelPathDoD : Test { :>> id = "68e3f80d-1365-482a-ae50-0de5c34a2ab8"; :>> method = VerificationMethod::test; :>> procedureText = "run_backup resolves the compose's relative bind sources and a relative --dest against the stack directory (canonicalize compose, set cwd to its parent) so backup works from any working directory. Integration test backup_resolves_relative_paths_from_any_cwd runs `yd backup` from a foreign cwd and asserts the manifest + copied bind land under the stack dir, not the cwd."; }
    part fixBackupRelPathDoDR1 : TestResult { :>> id = "82a6ea8a-0578-4aad-82dc-6fd62902e597"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "58153e1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    #Verify dependency from tabsCompleteDoD to ucMountAnalysis;
    #Verify dependency from tabsCompleteDoD to ucPermissionCompliance;
    #Verify dependency from tabsCompleteDoD to ucSmoothBackupRestore;
    #Verify dependency from tabsCompleteDoD to ucLiveLogs;

    verification refineGate43 : Test { :>> id = "e1f544fc-d3dc-4652-858a-3fe701133d74"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edges set; scope = build the remaining four UI tabs (Mounts/Permissions/Backups/Logs) with their endpoints, and fix the backup relative-path bug (issBackupRelPath) surfaced during the build."; }
    part refineGate43R1 : TestResult { :>> id = "71f1da3a-b597-436c-8b76-faf51bfeac5d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "58153e1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate43 : Test { :>> id = "21e3b348-b7c7-41d2-af3a-bb0eeab08c44"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 2/2 DoD green (120 lib + 23 integration, 0 warnings). Endpoints /api/mounts (build_report with no-daemon probes + RealFs; relative binds resolved against the stack dir), /api/permissions (security lens + ownership => compliance), /api/backups (dest-as-recovery-point + verify), /api/logs (docker compose logs tail). All four UI tabs implemented (no more soon-tabs). The build surfaced a real High bug — backup resolved relative paths against CWD — now fixed and regression-tested. All verified live."; }
    part reviewGate43R1 : TestResult { :>> id = "b970d3fd-ade9-429d-87d8-ec5e52a06040"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "58153e1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate43 : Test { :>> id = "723c903a-dbec-40af-81c3-b81c9f565429"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass; issBackupRelPath resolved; ucMountAnalysis, ucPermissionCompliance, ucSmoothBackupRestore, ucLiveLogs validated. The full tabbed UI IA is now live. Remaining recorded UI use cases (resource stats, import wizard, notifications, bulk ops, git remote) are next."; }
    part closeOutGate43R1 : TestResult { :>> id = "4a4327bb-5b0d-477c-ae64-be55956bebe2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "58153e1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
