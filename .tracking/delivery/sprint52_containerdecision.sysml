// =====================================================================
// YardDog — Sprint 52 delivery: resolve the container-image backlog item by
// recording the accepted decision to decline (decNoContainerImage).
// =====================================================================
package Sprint52ContainerDecision {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyContainerDecision : Story {
        :>> id = "17483240-85d8-425b-838f-6d01d65d933b";
        :>> title = "Decide the container-image question (decline, documented)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::decision;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 1;
    }

    #CharteredBy dependency from storyContainerDecision to needSecureByDefault;

    // resolver DoD (action decideContainerImage in issues-installation.sysml)
    verification decideContainerImageDoD : Test { :>> id = "2fa87190-bc4b-4c4c-b668-addbe35b2487"; :>> method = VerificationMethod::inspect; :>> procedureText = "The container-image question is decided and documented: decNoContainerImage (accepted, human-attested 2026-07-27) declines a supported container image because a containerized yd would mount the Docker socket — host-root-equivalent, which the tool's own guardrails block — contradicting needSecureByDefault. README already states the host-binary rationale. Not a silent gap: a first-class 'we won't do X' Decision with its why."; }
    part decideContainerImageDoDR1 : TestResult { :>> id = "9a600bc9-a5f2-42ad-8d5d-96b15ba98ea1"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "8c1d347"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate52 : Test { :>> id = "ce7ec858-1947-484a-aad7-207a5032791e"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (1); charter edge set; the last backlog install issue (issContainerImage) is a direction Decision routed to the human, who chose to decline; record it as an accepted first-class Decision and close the issue."; }
    part refineGate52R1 : TestResult { :>> id = "4f2ebc2c-f88e-4f62-b429-7869ca65c5cc"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "8c1d347"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate52 : Test { :>> id = "acdbe868-e8dc-430e-bec7-8dd9b1404c97"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: the decision is captured as a first-class accepted Decision with a genuine human attestation (confirmation, judgedBy=wweatherholtz), context/rationale/consequences recorded, and consistent with needSecureByDefault + the guardrail security lens. No code change (correctly — 'capture decisions even when they cause no action')."; }
    part reviewGate52R1 : TestResult { :>> id = "e6797a9a-9477-40cd-b08a-62efbff80c59"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "8c1d347"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate52 : Test { :>> id = "c4a6d911-5b9c-464c-89ce-317b577683eb"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issContainerImage resolved via the accepted decNoContainerImage. The entire installation backlog is now cleared (install script, Linux .deb/.rpm + systemd, Homebrew, Scoop, self-update, and the documented no-container-image decision). 0 open issues."; }
    part closeOutGate52R1 : TestResult { :>> id = "01bf53f0-b54a-4630-8ccd-9d98ec9623b2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "8c1d347"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
