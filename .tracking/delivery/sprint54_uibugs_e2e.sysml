// =====================================================================
// YardDog — Sprint 54 delivery: fix the operator-reported UI state-loss bugs
// (compose lost on tab switch; console wiped on tab switch) and stand up a
// Playwright end-to-end matrix over the browser control plane. TDD: the reported
// bug was reproduced as a failing Playwright test, then fixed to green.
// =====================================================================
package Sprint54UiBugsE2E {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyUiBugsE2E : Story {
        :>> id = "b52d9992-1d9d-4741-8e06-0f5e66178aea";
        :>> title = "Fix compose/console tab-switch data loss; add Playwright UI matrix";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyUiBugsE2E to needOperationalVisibility;

    // resolver DoD: fixComposeLostOnTab (issComposeLostOnTab)
    verification fixComposeLostOnTabDoD : Test { :>> id = "79ea70f8-e066-4cd6-9ff6-728d0b784875"; :>> method = VerificationMethod::demo; :>> procedureText = "The compose editor now keeps content in a client-side draft buffer (drafts{}, keyed by stack path) in ui.html: seeded from the server or the new-stack template, updated on input, so a tab switch (which rebuilds #tabbody) never loses it; per-stack so drafts don't bleed; cleared on restore. Proven by ui-e2e/tests/compose-persistence.spec.ts: 3 tests — new-stack typed compose survives a tab round-trip (the exact reported bug, reproduced failing then fixed), existing-stack unsaved edits survive, drafts are per-stack. All green against the real yd serve binary."; }
    part fixComposeLostOnTabDoDR1 : TestResult { :>> id = "e0608c25-3d0e-4a33-a1e9-d8ec1e0dbc0d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ad4b0b1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    #Verify dependency from fixComposeLostOnTabDoD to ucBrowserControlPlane;

    // resolver DoD: fixConsoleLostOnTab (issConsoleLostOnTab)
    verification fixConsoleLostOnTabDoD : Test { :>> id = "119778c0-93be-4d9c-93b6-95e95f614feb"; :>> method = VerificationMethod::demo; :>> procedureText = "The output console is now a persistent consoleBuf replayed wherever a #console is mounted (detail/fleet/git), so deploy/save/backup output survives tab switches; the debounced validateEditor is hardened against firing after navigation (null editor/panel guard). Proven by the console-persistence assertion in ui-e2e/tests/compose-editor.spec.ts (save output still present after leaving and returning to a tab)."; }
    part fixConsoleLostOnTabDoDR1 : TestResult { :>> id = "068e2d16-8834-4a48-aa0c-dd26d10870ac"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ad4b0b1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    #Verify dependency from fixConsoleLostOnTabDoD to ucBrowserControlPlane;

    // resolver DoD: fixNoUiRegressionNet (noUiRegressionNet)
    verification fixNoUiRegressionNetDoD : Test { :>> id = "c368a4ce-7ab1-43a2-a3a8-ae6a93fa9bdd"; :>> method = VerificationMethod::demo; :>> procedureText = "ui-e2e/ is a Playwright harness that launches real `yd serve` over an isolated fixture root (web=warn+existing/missing binds, cache=clean+named volume, risky=block privileged+socket) and asserts every tab and interactive element: rail list/filter/badges/notification/active, per-tab rendering, compose draft persistence, live validate panel (block->NOT READY->READY), new-stack template, save->history snapshot, Mounts typing+existence, Permissions compliance, Fleet aggregation, Git not-connected, Backups/Logs empty states, persistent console, theme toggle. 25 tests, all green. Docker-dependent actions asserted at the affordance level so the suite runs without a daemon."; }
    part fixNoUiRegressionNetDoDR1 : TestResult { :>> id = "a5b121eb-4966-4e31-a972-178ad5faef4d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ad4b0b1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    #Verify dependency from fixNoUiRegressionNetDoD to ucBrowserControlPlane;

    verification refineGate54 : Test { :>> id = "d3420d74-6c68-47ca-a307-f2992e5d713f"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edge to needOperationalVisibility set. Operator reported UI bugs while trying the control plane ('compose lost on tab switch after starting a new stack', 'many others') and directed a huge Playwright matrix per tab/element. Filed issComposeLostOnTab (High), issConsoleLostOnTab (Medium), noUiRegressionNet (High). TDD: reproduce the reported bug as a failing Playwright test first."; }
    part refineGate54R1 : TestResult { :>> id = "33ee2236-5f91-4480-a3e7-ffcb0f7e92a4"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ad4b0b1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate54 : Test { :>> id = "4ba839d0-21ef-4807-9cff-9124924d8195"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery. (correctness) TDD honored — the reported bug was reproduced as a failing test (empty editor after a tab round-trip) BEFORE the fix, then driven green; a test-only false-failure (toContainText reads a textarea's empty textContent, not .value) was corrected to toHaveValue, not masked. Root cause fixed at the state layer (draft buffer), not patched per-tab. (design/FSM) editor + console content moved out of ephemeral DOM into explicit client state keyed by stack — invalid 'content only in DOM' state made unrepresentable. (human-factors) operators no longer lose typed compose or action output on navigation; per-stack drafts prevent cross-stack bleed. (docs) ui-e2e/README documents run + fixtures + coverage. (concision) one small draft map + one console buffer; no framework added. Follow-ups logged (not silent): issContainerCiPublish still open (unrelated); theme not persisted across reloads and drafts not persisted across full reload are minor UX, not filed as bugs this sprint. Note: Playwright chosen per the operator's explicit directive; harness is a separate JS project so it never touches the Rust build."; }
    part reviewGate54R1 : TestResult { :>> id = "5f4f9377-7f3d-47b1-8777-cb6f5d9f47db"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ad4b0b1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate54 : Test { :>> id = "f480509e-d3fc-4ecc-a5db-858d4c870dd8"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issComposeLostOnTab, issConsoleLostOnTab, and noUiRegressionNet resolved. The browser control plane no longer loses compose or console content on tab switches, and a 25-test Playwright matrix now guards every tab/element against regressions. cargo build + 149 Rust tests green; keel validate + guard green."; }
    part closeOutGate54R1 : TestResult { :>> id = "44934ef2-3b6d-472d-b2c0-c81e94951c23"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "ad4b0b1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
