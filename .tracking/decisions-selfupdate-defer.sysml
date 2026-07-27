// =====================================================================
// YardDog — Decision to defer program self-update apply until a release exists.
// =====================================================================
package YardDogSelfUpdateDeferDecision {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;

    part decDeferSelfUpdate : Decision {
        :>> id = "8f090a54-3987-4827-a17e-0339ec17b0d4";
        :>> title = "Defer program self-update (download/verify/apply) until a release pipeline exists";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::accepted;
        :>> context = "needSelfUpdate is satisfied at the DETECTION level (yd self-update reports whether a newer version is available), but the apply half — download a release binary, verify its checksum, atomically replace the running binary — has no artifact to act on: there is no release pipeline or hosted release yet, so the apply cannot be built or E2E-validated end to end.";
        :>> decision = "Defer the self-update APPLY implementation until releases are actually hosted. Keep the detection behavior as-is. When a release pipeline exists, build download + checksum-verify + atomic-replace against it (GitHub Releases is the presumed source) with a real published artifact to test against.";
        :>> rationale = "Building an unverifiable apply path against a mocked release would ship untested code on the most safety-sensitive operation (replacing the running binary), against the project's correctness-first policy. The honest move is to defer to when it can be proven end to end. Chosen by the human operator on 2026-07-27.";
        :>> consequences = "yd self-update remains detection-only; no new networking/replace code lands now. Revisit when a release/CI pipeline publishes signed artifacts.";
    }

    verification decDeferSelfUpdateAccept : Test { :>> id = "352cd363-6db6-4b38-91af-0a63a255606e"; :>> method = VerificationMethod::confirmation; :>> procedureText = "Human operator selected 'Defer until a release exists' for program self-update on 2026-07-27, choosing not to build the download/verify/atomic-replace apply path until a release pipeline exists to validate it against."; }
    part decDeferSelfUpdateAcceptR1 : TestResult { :>> id = "02fbf12d-4895-4561-bfcf-a25289a9dccf"; :>> outcome = VerdictKind::pass; :>> judgedAt = "2026-07-27"; :>> judgedBy = "wweatherholtz"; }
}
