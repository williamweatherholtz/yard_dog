// =====================================================================
// YardDog — UI redesign issues raised by the operator 2026-07-27 after trying
// the control plane. Addressed by the container-terminal redesign (Sprint 56);
// the backend kind removal is a tracked follow-up (Sprint 57).
// =====================================================================
package YardDogUiRedesignIssues {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    part issThemingCollision : Issue {
        :>> id = "f525fe9b-d001-47c5-98e5-8856aa6fb8d1";
        :>> title = "Palette is off: the brand accent is the SAME color as the 'warn' status";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "The brand accent (#c9871f amber) was identical to the warn semantic color, so warnings never stood out and every brand-colored element read as 'caution'. Operator: 'palette/theming is off... polished, clean, concise, clear.' Fix: a container-terminal identity (Yard Dog = the yard truck that couples/moves your containers) with a petrol/steel BRAND accent used only for brand, and a separate status system (green/amber/red/blue). Both light + dark themes reworked; theme persists.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }

    part issPopupDataEntry : Issue {
        :>> id = "ca8dd184-6833-4f55-a214-5ca9ae0f59ea";
        :>> title = "Data entry uses browser popups (prompt/alert/confirm)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "New stack (name/kind), image upgrade, git remote URL, mount fix, and every destructive confirm used native browser dialogs. Operator: 'move completely away from popup windows for data entry.' Fix: inline panels/forms replace them all — a New-stack panel with live template preview, an inline per-row upgrade form, an inline mount-fix with copy-command, a proper Git connect form, and an in-page confirm banner. Zero window.prompt/alert/confirm remain.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }

    part issNoVisibleConsole : Issue {
        :>> id = "bbdeccc8-da32-43ae-9f23-a78e560595c4";
        :>> title = "No visible console/terminal for debug output; Git login and Fleet unclear";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Operator: 'I don't see a console/terminal for debug output', 'I don't see git login properly', 'what is fleet?'. Fixes: a persistent, always-present Console dock at the bottom (collapsible, replays a buffer, auto-opens on activity); a proper Git panel that states sign-in uses system Git credentials (helper/SSH, no tokens stored) with an inline connect form + push/pull; and Fleet relabeled 'All stacks' with a plain intro explaining it aggregates every stack for bulk check/backup/adopt.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }

    part issRemoveKindBackend : Issue {
        :>> id = "0017f9c2-27e1-4eb9-a800-a51ade5bb826";
        :>> title = "Remove workload 'kind' from the Rust backend (classify, yd new --kind, update-gating)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Per decRemoveWorkloadKind (accepted: 'Remove entirely'), the UI Kind column is gone, but the backend still classifies: classify.rs + `yd classify`, `yd new --kind` with per-kind templates, kind in the /api/stack services JSON, and kind-gated update actions. Remove all of it: one starter template for `yd new`, drop `yd classify`, stop sending kind in the JSON, and make update actions no longer branch on kind. Update/remove the Rust tests that assert kind. Follow-up to the Sprint 56 UI redesign.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    action fixThemingCollision;
    action fixPopupDataEntry;
    action fixNoVisibleConsole;
    action fixRemoveKindBackend;
    #Resolves dependency from fixThemingCollision to issThemingCollision;
    #Resolves dependency from fixPopupDataEntry to issPopupDataEntry;
    #Resolves dependency from fixNoVisibleConsole to issNoVisibleConsole;
    #Resolves dependency from fixRemoveKindBackend to issRemoveKindBackend;
}
