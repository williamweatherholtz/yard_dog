// =====================================================================
// YardDog — terminal parity gap raised by the operator 2026-07-27: no live stack
// output and no way to open an interactive terminal in a container.
// =====================================================================
package YardDogTerminalIssues {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    part issNoTerminal : Issue {
        :>> id = "78633dad-55d9-4b3d-af00-549919dbc9fb";
        :>> title = "No live stack output / no interactive terminal (feature-parity gap)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Operator: 'I don't see a terminal reading output from the stack, or a means of launching an interactive terminal. we should have feature parity in most situations with other programs.' The Logs tab was only a static `--tail` snapshot and there was no exec. Operator chose a FULL interactive PTY (like Portainer's web console). Fix: a term.rs PTY session layer (portable-pty), a Terminal tab with live logs-follow AND an interactive per-service shell (top/vi/prompts work), transported over the existing request/response server (long-poll output + POST input, base64), with xterm.js bundled and served from the binary.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }

    action fixNoTerminal;
    #Resolves dependency from fixNoTerminal to issNoTerminal;
}
