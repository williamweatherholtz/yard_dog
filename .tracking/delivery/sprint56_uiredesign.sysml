// =====================================================================
// YardDog — Sprint 56 delivery: redesign the browser control plane around the
// container-terminal identity (Yard Dog = the yard truck that couples/moves your
// containers). Fixes the palette collision, removes all data-entry popups, adds a
// persistent console dock, and clarifies Git + Fleet. Verified by the Playwright
// matrix + design screenshots.
// =====================================================================
package Sprint56UiRedesign {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyUiRedesign : Story {
        :>> id = "191cff0c-dafc-4453-a7f2-20f7fa96b0b4";
        :>> title = "Container-terminal UI redesign: palette, inline forms, console dock, Git/Fleet clarity";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 8;
    }

    #CharteredBy dependency from storyUiRedesign to needOperationalVisibility;

    verification fixThemingCollisionDoD : Test { :>> id = "323504be-8edc-4df7-848f-daa1edc3729a"; :>> method = VerificationMethod::inspect; :>> procedureText = "ui.html is rebuilt on a container-terminal identity: a petrol/steel brand accent used ONLY for brand, and a SEPARATE status system (green healthy / amber warn / red block / blue info) so the old accent==warn collision is gone. Wordmark + container/truck mark; industrial cool-neutral ground; uppercase micro-labels; monospace tabular data. Both light and dark themes reworked and theme persists (localStorage). Verified by screenshots (light overview, dark risky-stack with clearly distinct red BLOCK vs amber WARN) and a smoke pass with ZERO console/page JS errors across all views."; }
    part fixThemingCollisionDoDR1 : TestResult { :>> id = "5b6b361e-82a2-4874-9b25-324b3492c3a4"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0224544"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    #Verify dependency from fixThemingCollisionDoD to ucBrowserControlPlane;

    verification fixPopupDataEntryDoD : Test { :>> id = "5516ca8a-991e-4d48-87b4-d0260102e169"; :>> method = VerificationMethod::demo; :>> procedureText = "Every browser popup for data entry is replaced by an in-page affordance: a New-stack panel (name + live template preview, no kind), an inline per-row image-upgrade form, an inline mount-fix with a copy-command button, a proper Git connect form, and an in-page confirm banner + toasts for all destructive actions. No window.prompt/alert/confirm remain. Playwright proves the inline flows: new-stack via the form, inline upgrade row appears/cancels, inline mount-fix appears/closes, git connect form present, and the reported compose-draft persistence still holds — 27 tests green."; }
    part fixPopupDataEntryDoDR1 : TestResult { :>> id = "8ff994d0-aa5f-40ef-b5c4-79a509cf8006"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0224544"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    #Verify dependency from fixPopupDataEntryDoD to ucBrowserControlPlane;

    verification fixNoVisibleConsoleDoD : Test { :>> id = "988d9024-5c71-4364-be44-81d6b055103e"; :>> method = VerificationMethod::demo; :>> procedureText = "A persistent Console dock sits at the bottom of every view (collapsible, replays a buffer that survives tab switches, auto-opens on command activity) — the operator can always see what yd runs. Git gets a proper panel: a Not-connected/Connected pill, an inline remote-URL form, push/pull, and a clear note that sign-in uses the system Git credential helper / SSH and stores no tokens; a header signal dot reflects connection. Fleet is relabeled 'All stacks' with a plain intro (aggregate every stack; bulk check/backup; adopt). Playwright asserts the dock, the git panel + credentials note, and the All-stacks intro."; }
    part fixNoVisibleConsoleDoDR1 : TestResult { :>> id = "d3cfa63e-cec7-4429-8ed7-0a084c890fa2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0224544"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    #Verify dependency from fixNoVisibleConsoleDoD to ucBrowserControlPlane;

    verification refineGate56 : Test { :>> id = "13ac41b0-5475-4aa1-bdac-f899e93a10c9"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (8); charter to needOperationalVisibility. Operator directed a redesign via the frontend-design skill: fix the palette, remove all popups, add a visible console, fix git login, clarify Fleet, remove the workload kind (decRemoveWorkloadKind — 'remove entirely'). Brand clarified: Yard Dog = terminal tractor / yard truck (managing container connections), not dogs. Scope this sprint = the UI; the backend kind removal is filed as issRemoveKindBackend for Sprint 57."; }
    part refineGate56R1 : TestResult { :>> id = "361cd122-41b8-4316-a5b4-cd62ab92c5dc"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0224544"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate56 : Test { :>> id = "ff8e4ea3-220e-4cdf-a5b7-80f2c610a25d"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery. (correctness) redesign proven by the 27-test Playwright matrix (all green) AND a screenshot smoke with zero JS errors; a real layout bug found mid-review (the fixed console dock overlapped the New-stack button) was fixed by moving the dock into flex flow. (design) the palette collision (accent==warn) that made theming feel 'off' is root-caused and removed; status is now a coherent signal system reused across rail/services/mounts; identity grounded in the true subject (yard truck / container terminal). (human-factors) no more browser popups; a console is always visible; Git states its credential model; Fleet is self-explanatory. (docs) README control-plane section updated to the new tabs/console/git. (concision) one embedded SPA, no framework; inline forms reuse shared styles. Known follow-up (not silent): the Kind column is gone from the UI but the Rust backend still classifies — tracked as issRemoveKindBackend (Sprint 57) per the accepted decRemoveWorkloadKind."; }
    part reviewGate56R1 : TestResult { :>> id = "76a54678-588f-4526-9c7d-1bb57d0a7b18"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0224544"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate56 : Test { :>> id = "1113c683-f52b-4372-b21d-ccc31878c4ad"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issThemingCollision, issPopupDataEntry, issNoVisibleConsole resolved. The control plane is redesigned around the container-terminal identity, popup-free, with a persistent console and clear Git/Fleet; the Kind column is removed from the UI. cargo build + 149 Rust tests green; 27 Playwright UI tests green; keel validate + guard green. Remaining: issRemoveKindBackend (Sprint 57)."; }
    part closeOutGate56R1 : TestResult { :>> id = "13bc6746-a9d5-41f1-8542-5300bd63a128"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "0224544"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
