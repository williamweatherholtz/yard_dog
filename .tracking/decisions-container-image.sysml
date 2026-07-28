// =====================================================================
// YardDog — Decision: do NOT ship a supported container image (host binary only).
// =====================================================================
package YardDogContainerImageDecision {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;

    part decNoContainerImage : Decision {
        :>> id = "f0962a8e-44ab-4a25-8a11-0548b4633f55";
        :>> title = "Do not ship a supported container image; the host binary is the install path";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::superseded;
        :>> context = "issContainerImage asked whether to publish a container image / compose for running yd itself. yd manages the HOST's Docker, so a containerized yd must mount /var/run/docker.sock — which Yard Dog's own guardrail security lens flags as BLOCK-severity (host-root-equivalent). Shipping a socket-mounting compose would have the tool bless exactly what it warns against, contradicting needSecureByDefault.";
        :>> decision = "Decline to ship a supported container image or a socket-mounting compose. The install path is the host binary (Linux .deb/.rpm, macOS Homebrew, Windows Scoop, the checksum-verifying install script, and self-update). Document the reason so operators understand it is a deliberate security choice, not an oversight.";
        :>> rationale = "Consistency and honesty: the tool must not distribute the very host-root exposure its guardrails block. The host binary needs Docker access anyway (via the daemon), and running as a host binary keeps the trust boundary clear. Chosen by the human operator on 2026-07-27 ('Decline, document why').";
        :>> consequences = "No container image is published. An operator who insists on a containerized deployment can build their own image + socket mount at their own risk (unsupported). Revisit only if a genuinely safer pattern (e.g. a read-scoped socket proxy) is warranted — reopen as a new decision then.";
    }

    verification decNoContainerImageAccept : Test { :>> id = "f5c98905-0732-4943-861f-a3540f89c58b"; :>> method = VerificationMethod::confirmation; :>> procedureText = "Human operator chose 'Decline, document why' for the container-image question on 2026-07-27, accepting that yd ships as a host binary and does not distribute a socket-mounting container image."; }
    part decNoContainerImageAcceptR1 : TestResult { :>> id = "57c4905b-1a55-4c57-a3f0-0f4231fd2d6c"; :>> outcome = VerdictKind::pass; :>> judgedAt = "2026-07-27"; :>> judgedBy = "wweatherholtz"; }
}
