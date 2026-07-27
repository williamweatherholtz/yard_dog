// =====================================================================
// YardDog — foundational architecture Decision: implementation stack.
// Accepted by wweatherholtz on 2026-07-26 (stack decision); acceptance is the
// discrete confirmation TestResult below, never prose (decision-authoring).
// =====================================================================
package YardDogArch {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;

    part decStack : Decision {
        :>> id = "d4e1cafe-782b-4907-9280-1613aeb0070b";
        :>> title = "Adopt Rust (with the Bollard Docker client) as the implementation stack";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::accepted;
        :>> context = "Yard Dog is greenfield and needs a foundational implementation stack before any build sprint. The tool is a self-hosted, single-host daemon+CLI whose whole value proposition is safety — correct path classification, refusing destructive/implicit actions, and integrity-respecting backup. Candidate stacks were Go (infra-tool norm, official Docker SDK), Rust (strongest correctness/safety, Bollard client), TypeScript/Node (fastest UI iteration), and Python (fastest prototyping).";
        :>> decision = "Build Yard Dog in Rust, using the Bollard crate for Docker Engine API access, shipped as a single static binary (CLI-first, with an embedded web UI to follow). Kubernetes/Swarm remain out of scope per decScope.";
        :>> rationale = "The product's core promise is not doing dumb/destructive things with the operator's data and paths; Rust's correctness and safety guarantees fit a data-safety tool better than the alternatives, and a single static binary suits self-hosted distribution (no runtime to install). Go was the strong runner-up (infra-tool norm, official SDK) and TypeScript would iterate the UI fastest, but the safety ethos and single-binary distribution tipped the choice to Rust; Bollard is a mature async Docker client. The chief cost — slower iteration and a smaller talent pool — is accepted and folded into sprint sizing (new-language overhead).";
        :>> consequences = "All build sprints are in Rust/Cargo; estimates account for new-language overhead. Docker access goes through Bollard (async). A web UI is a later increment atop the CLI core. Revisitable if velocity proves untenable, but the stack is deliberately hard to reverse once code accretes.";
    }

    verification decStackAccept : Test { :>> id = "de9507c5-2a9e-4ad4-a985-00d917432e73"; :>> method = VerificationMethod::confirmation; :>> procedureText = "wweatherholtz selected Rust (with Bollard) as Yard Dog's implementation stack via the 2026-07-26 stack decision."; }
    part decStackAcceptR1 : TestResult { :>> id = "27a18fee-c002-494e-a8f1-f98386145c85"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "wweatherholtz"; }
}
