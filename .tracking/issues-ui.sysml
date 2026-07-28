// =====================================================================
// YardDog — browser control-plane (ui.html) defects reported by the operator
// 2026-07-27 while trying the UI. Client-side state-loss bugs the Rust unit
// tests can't see; now covered by the Playwright UI matrix (ui-e2e/).
// =====================================================================
package YardDogUiIssues {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    part issComposeLostOnTab : Issue {
        :>> id = "1fb45adf-24a7-4913-b93d-bb4035fe469a";
        :>> title = "Compose editor content is lost when switching tabs (worst after starting a new stack)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Operator report: 'when switching tabs after starting a new stack, all the compose is lost'. Root cause: the compose editor's text lived ONLY in the DOM textarea. Every tab switch calls renderShell() which destroys #tabbody, and renderCompose() re-fetched the compose from the server. For a brand-new (unsaved) stack the server has no file -> empty editor -> all typed compose lost; the same class also silently discarded unsaved edits on any existing stack. Fix: a client-side draft buffer keyed by stack path (drafts{}), seeded from the server or the new-stack template, updated on input, so tab switches never lose content; per-stack so drafts don't bleed across stacks; cleared on restore. Covered by ui-e2e/tests/compose-persistence.spec.ts.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }

    part issConsoleLostOnTab : Issue {
        :>> id = "73fb88bb-58c9-4abc-928c-15537543b3d0";
        :>> title = "Output console is wiped on every tab switch, losing action results";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Same state-loss family as issComposeLostOnTab: renderShell() rebuilt the #console pre from scratch on each tab switch, so deploy/save/backup output vanished the moment the operator changed tabs — losing the very feedback they act on. Fix: a persistent consoleBuf replayed wherever a #console is mounted (detail, fleet, git). Also hardened the debounced validateEditor against firing after navigation (null editor). Covered by the console-persistence assertion in ui-e2e/tests/compose-editor.spec.ts.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }

    part noUiRegressionNet : Issue {
        :>> id = "0782de8d-7f65-43ac-a9db-f21d535d2064";
        :>> title = "No end-to-end regression net for the browser UI — client-state bugs shipped unseen";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "The UI is a single embedded SPA (app/src/ui.html) exercised only by hand; Rust unit/integration tests cover the server + library but never the browser behavior, so the tab-switch state-loss bugs shipped undetected. Operator directive: build a comprehensive Playwright matrix driving each tab and UI element. Fix: ui-e2e/ Playwright harness that launches real `yd serve` over isolated fixtures and asserts rail/tabs/compose-drafts/validate/mounts/permissions/history/fleet/git/backups/logs/theme.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }

    action fixComposeLostOnTab;
    action fixConsoleLostOnTab;
    action fixNoUiRegressionNet;
    #Resolves dependency from fixComposeLostOnTab to issComposeLostOnTab;
    #Resolves dependency from fixConsoleLostOnTab to issConsoleLostOnTab;
    #Resolves dependency from fixNoUiRegressionNet to noUiRegressionNet;
}
