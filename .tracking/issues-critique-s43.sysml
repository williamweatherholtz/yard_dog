// =====================================================================
// YardDog — bug found while building the UI tabs (2026-07-27).
// =====================================================================
package YardDogCritiqueIssuesS43 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    part issBackupRelPath : Issue {
        :>> id = "186a5dcf-8714-41bf-946d-c3cac7ae67c9";
        :>> title = "yd backup resolves relative binds and --dest against the process CWD, not the stack dir";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "A compose with a relative bind (e.g. ./html) or a relative --dest backed up correctly only when `yd` ran from the stack directory. Deploy/upgrade are unaffected (docker compose -f resolves relative to the compose file), but our own host-FS backup copied ./html and wrote .yd-backups relative to the process CWD — so backup FAILED when invoked from elsewhere, exactly how the browser UI (running from the served root) calls it. Fix: resolve the compose's relative paths against the stack directory, like docker compose does.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }

    action fixBackupRelPath;
    #Resolves dependency from fixBackupRelPath to issBackupRelPath;
}
