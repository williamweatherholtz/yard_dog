// =====================================================================
// YardDog — Sprint 57 delivery: a full interactive PTY terminal + live logs
// follow in the browser control plane. Proven end-to-end against a real
// container (API and browser).
// =====================================================================
package Sprint57Terminal {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyTerminal : Story {
        :>> id = "cf77a9fa-266c-4905-98ff-b2c56fd6596b";
        :>> title = "Interactive PTY terminal + live logs follow (feature parity)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 8;
    }

    #CharteredBy dependency from storyTerminal to needOperationalVisibility;

    verification fixNoTerminalDoD : Test { :>> id = "3b2ea9ca-285f-4ef5-9fc2-dc503b405f11"; :>> method = VerificationMethod::demo; :>> procedureText = "A full interactive PTY terminal ships. Backend: term.rs opens a PTY-backed session (portable-pty) running `docker compose exec <svc> sh` (interactive) or `docker compose logs -f` (follow); output is long-polled (drain-on-read, base64) and input/resize are POSTs — all over the existing request/response server, no websockets. web.rs adds /api/term/{open,read,input,resize,close} and serves the bundled xterm.js/addon-fit/xterm.css from the binary. Frontend: a Terminal tab with a Logs/Shell toggle + per-service picker, xterm.js with the fit addon, a poll loop rendering output and onData sending input. PROVEN end-to-end against a real running nginx container: (API) opening a shell, sending `echo TERMWORKS-$(uname -s); nginx -v` returned `TERMWORKS-Linux` + `nginx version: nginx/1.27.5`; (browser) the Terminal tab shows a live `/ #` prompt and renders `nginx -v`, `cat /etc/os-release`, and a colorized `ls /etc/nginx`. 2 Rust PTY unit tests + 27 Playwright UI tests (incl. xterm mount + Logs/Shell toggle) green."; }
    part fixNoTerminalDoDR1 : TestResult { :>> id = "c09af466-a578-47e8-aa6e-c3bf53d98fdd"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1a3f18d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    #Verify dependency from fixNoTerminalDoD to ucBrowserControlPlane;

    verification refineGate57 : Test { :>> id = "9f2f1cdb-1559-42e7-b168-83357a9355be"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (8); charter to needOperationalVisibility. Operator reported no live output + no interactive terminal and chose a FULL interactive PTY (over an exec-console). Scope: PTY session layer + Terminal tab (logs-follow + shell), bundled xterm, transported over the current server."; }
    part refineGate57R1 : TestResult { :>> id = "fbaec91a-a311-4b92-821a-59ffbedfaa04"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1a3f18d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate57 : Test { :>> id = "cf1f14f7-5b68-4de8-99ea-6e7129eb6bf0"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery. (correctness) proven against a REAL container at both the API and browser layers, not just built. Two real bugs were found in field testing and fixed: (a) portable-pty did not resolve `docker`->`docker.exe` on Windows (error 193) — added PATH+PATHEXT resolution preferring executable extensions, so the terminal works on the Windows install too; (b) a start()-race + handlers-assigned-after-await meant a Shell click during the one-time xterm load was lost and logs won — fixed by wiring handlers synchronously and guarding start() with a generation counter. (security) terminal endpoints ride the same loopback + Host-allowlist + application/json anti-CSRF path; no new bind. (human-factors) live logs AND an interactive shell with a service picker and status signal; the console dock still shows what yd runs. (design) one session mechanism serves both logs-follow and shell. (concision) long-poll transport reuses the request/response server — no websocket layer. Known scope (not silent): full-screen apps depend on the container having a TTY-capable shell; xterm.js (~290KB) is vendored into the binary (accepted for a self-contained same-host UI)."; }
    part reviewGate57R1 : TestResult { :>> id = "61a9d242-ab11-4d34-85a6-3c8734c61022"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1a3f18d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate57 : Test { :>> id = "99189b89-2dd1-4103-88f4-2f322dc97d64"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issNoTerminal resolved. The control plane now has live logs-follow and a full interactive PTY shell into any service, at parity with other Docker UIs. cargo build + 151 Rust tests green; 27 Playwright UI tests green; keel validate + guard green. Remaining open: issRemoveKindBackend (backend kind removal) and the directory-mitigation/labeling surfacing raised alongside the terminal."; }
    part closeOutGate57R1 : TestResult { :>> id = "88248b71-fe6f-4626-a8df-223e52a38a02"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1a3f18d"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
