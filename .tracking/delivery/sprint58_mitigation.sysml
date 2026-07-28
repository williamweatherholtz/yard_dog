// =====================================================================
// YardDog — Sprint 58 delivery: surface the directory mitigation + labeling
// (the mount-path-intelligence pillar) prominently and make it actionable.
// =====================================================================
package Sprint58Mitigation {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part issMitigationHidden : Issue {
        :>> id = "33aa6900-baaa-488a-aabe-05d1cbbc33c9";
        :>> title = "Directory mitigation + labeling is under-displayed (headline pillar hidden)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Operator: 'I'm also not seeing any directory mitigation or labeling. this is a major feature that has yet to be displayed.' The backend computed per-path issues (MissingPath/TypeMismatch/Ownership) + ranked remediations + an apply path (`yd fix`), but /api/mounts sent only an issue COUNT and the UI showed just type + exists + a copy-command button. Fix: emit labeled issues (kind/label/message/fixable), show each mount's specific problem as a labeled chip, add a summary with a one-click 'Apply fixes' that runs `yd fix --yes` (creates missing dirs owned by the container user + fixes ownership; type mismatches stay operator-decided), and an inline details panel labeling the problem then the suggested fix.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    action fixMitigationHidden;
    #Resolves dependency from fixMitigationHidden to issMitigationHidden;

    part storyMitigation : Story {
        :>> id = "27b1ebb1-6b05-4966-9b40-2da3794e6ed7";
        :>> title = "Surface labeled path issues + one-click directory mitigation";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }
    #CharteredBy dependency from storyMitigation to needPathIntelligence;

    verification fixMitigationHiddenDoD : Test { :>> id = "72f3d25b-f641-42a4-934d-122c7fce29de"; :>> method = VerificationMethod::demo; :>> procedureText = "The Mounts tab now displays the path-intelligence pillar: /api/mounts emits each detected issue as {kind,label,message,fixable}; the tab shows a summary ('N connections', 'M path issues', and an 'Apply fixes (K)' button labeled 'creates missing dirs + fixes ownership' when auto-fixable), a labeled problem chip per mount (Missing directory / Type mismatch / Ownership, with an 'auto-fix' marker), and an inline details panel stating WHAT is wrong then the suggested fix + copy-command. 'Apply fixes' POSTs /api/fix -> `yd fix --yes`. Verified: /api/mounts returns a labeled 'Missing directory' fixable issue for a missing bind; Playwright asserts the label chip, the auto-fix marker, the Apply-fixes button, and the inline details panel; a screenshot shows the surfaced mitigation. 28 UI + 151 Rust tests green."; }
    part fixMitigationHiddenDoDR1 : TestResult { :>> id = "38035ac8-811f-49ef-b489-1e836b7619dd"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "acf6b55"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    #Verify dependency from fixMitigationHiddenDoD to ucBrowserControlPlane;

    verification refineGate58 : Test { :>> id = "bd994ddd-f61b-4750-a9c2-5a371f4449c5"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (3); charter to needPathIntelligence. Operator reported the directory mitigation/labeling pillar was not displayed. The backend already had the data (report::build_report issues + remediations + apply::actions_for + `yd fix`); scope = surface it (labeled issues in /api/mounts) + make it actionable (/api/fix + Apply-fixes UI)."; }
    part refineGate58R1 : TestResult { :>> id = "c1d92ffa-9504-49a5-8993-be8807203bf4"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "acf6b55"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate58 : Test { :>> id = "6921ce8e-4533-43a6-953f-6f71ca407185"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery. (correctness) verified the backend emits a labeled fixable issue and the UI renders label + apply + details; Playwright covers all three. (safety) mitigation stays explicit-consent — Apply fixes runs `yd fix --yes` only after an in-page confirm; the tool still refuses to create dirs with the wrong owner (CreateDir uses the container's PUID/PGID) and does NOT auto-resolve type mismatches (operator decides), consistent with the propose-then-apply-on-confirmation ethos. (human-factors) the operator now sees WHAT is wrong (labeled) and can fix it in one click. (docs) the pillar is self-describing in the tab intro + summary. (concision) reused existing report/remediation/apply logic; the change is a JSON shape + a UI surface + one endpoint. Known scope (not silent): type-mismatch and typo cases show a copy-command, not an auto-apply, by design."; }
    part reviewGate58R1 : TestResult { :>> id = "02692eda-4f91-449a-933e-79c712c36d80"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "acf6b55"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate58 : Test { :>> id = "842377f3-5901-4617-a3c3-43e8066a9704"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issMitigationHidden resolved. The mount-path-intelligence pillar (typing + existence + labeled problems + one-click mitigation) is now front-and-centre in the Mounts tab. 28 Playwright + 151 Rust tests green; keel validate + guard green. Remaining open: issRemoveKindBackend (backend workload-kind removal)."; }
    part closeOutGate58R1 : TestResult { :>> id = "62cfccfb-7e4e-44c6-bd51-33ebde667e5f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "acf6b55"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
