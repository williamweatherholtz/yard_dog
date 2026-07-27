// =====================================================================
// YardDog — Sprint 42 delivery: tabbed UI redesign (core loop).
// Overview (issues), Compose editor (live guardrails + save/snapshot),
// History (git log + diff + restore). New backend endpoints + gitver::diff.
// =====================================================================
package Sprint42UiTabs {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyUiTabs : Story {
        :>> id = "735a2f0f-48db-491f-b127-27ce019cf5fb";
        :>> title = "Tabbed UI: Overview issues, Compose editor with live guardrails, History+diff+restore";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 8;
    }

    #CharteredBy dependency from storyUiTabs to needOperationalVisibility;
    #CharteredBy dependency from storyUiTabs to needComposeManagement;
    #CharteredBy dependency from storyUiTabs to needVersionedCompose;

    action gitverDiff;
    verification gitverDiffDoD : Test { :>> id = "40411a33-40fc-40ca-97a8-d273b7c4ee25"; :>> method = VerificationMethod::test; :>> procedureText = "gitver::diff(dir, from, to) returns the unified diff between two snapshots (to=None diffs from vs the working tree); unit-tested: a changed image line shows -/+ and a snapshot vs its matching tree is empty."; }
    part gitverDiffDoDR1 : TestResult { :>> id = "f7990e9b-4929-4c0f-b54e-44164d994544"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "604096d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action uiTabs;
    verification uiTabsDoD : Test { :>> id = "c628a079-9c26-415b-afa1-240667bb3005"; :>> method = VerificationMethod::demo; :>> procedureText = "Live against yd serve: the UI is a tabbed stack detail (Overview/Compose/History + soon-tabs) with a rail issue badge from /api/stacks blocks/warns. Verified endpoints: GET /api/compose returns the yaml; POST /api/validate returns guardrails+preflight on posted yaml (floating tag => 1 block); POST /api/save writes + snapshots (returns sha); GET /api/history lists snapshots; GET /api/diff returns the unified diff; POST /api/restore snapshots current then restores a chosen sha (compose reverted). All mutations still pass the loopback + anti-CSRF gate."; }
    part uiTabsDoDR1 : TestResult { :>> id = "159c7611-84ec-41c0-9152-dbb1027f9bbd"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "604096d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    #Verify dependency from uiTabsDoD to ucStackIssues;
    #Verify dependency from uiTabsDoD to ucComposeEditor;
    #Verify dependency from uiTabsDoD to ucUpdateHistory;
    #Verify dependency from uiTabsDoD to ucConfigDiff;
    #Verify dependency from uiTabsDoD to ucRollbackFromHistory;

    verification refineGate42 : Test { :>> id = "af006105-74cb-44b5-9a7b-f366674828ae"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (8); charter edges set; scope per human = build the tabbed UI core loop first (Overview issues, Compose editor with live guardrails, History+diff+restore); Mounts/Permissions/Backups/Logs are recorded use cases shown as soon-tabs."; }
    part refineGate42R1 : TestResult { :>> id = "6a8b4877-20f1-444f-80ed-2a03e331ce84"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "604096d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate42 : Test { :>> id = "4442b67c-20d9-4b40-bc4c-0a8e8c794244"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 2/2 DoD green (120 lib + 22 integration, 0 warnings). New: gitver::diff (unit-tested); web endpoints /api/compose, /api/validate, /api/save, /api/history, /api/diff, /api/restore (save/restore snapshot via gitver; validate reuses guardrails+preflight); /api/stacks now carries issue counts. UI rewritten as a tabbed SPA: rail with issue badges + New stack; Overview (issues + status chips + actions), Compose (editor with debounced live validation + save/save&deploy), History (snapshots + diff viewer + restore). All verified live; mutations remain behind the loopback + application/json + loopback-Origin gate. Mounts/Permissions/Backups/Logs are honest soon-tabs (recorded use cases)."; }
    part reviewGate42R1 : TestResult { :>> id = "556254fb-92ce-4af2-abe3-48dcff6ff684"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "604096d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate42 : Test { :>> id = "d1a969c6-d952-4d2d-bb3e-8afe505f6b2b"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass; ucStackIssues, ucComposeEditor, ucUpdateHistory, ucConfigDiff, ucRollbackFromHistory validated live. The browser control plane's core loop (see issues -> edit compose with live guardrails -> save/deploy -> review history/diff -> restore) is usable end to end. Remaining UI tabs (Mounts, Permissions, Backups, Logs) + resource stats / import / notifications / bulk ops are recorded and next."; }
    part closeOutGate42R1 : TestResult { :>> id = "b89de78a-52c3-4e1b-b3b4-88c4ed28a6ed"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "604096d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
