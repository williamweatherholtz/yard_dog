// =====================================================================
// YardDog — Sprint 38 delivery: container-hardening (security) guardrail lens.
// New guardrail rules propagate through doctor, the deploy gate, and the UI.
// =====================================================================
package Sprint38SecurityLens {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storySecurityLens : Story {
        :>> id = "ae0c3b3a-c9b6-4d85-835c-24a88bb45cc6";
        :>> title = "Guardrail security lens: privileged, docker-socket, dangerous caps, host net/pid";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storySecurityLens to needSecureByDefault;
    #CharteredBy dependency from storySecurityLens to needDeployGuardrails;

    action securityLens;
    verification securityLensDoD : Test { :>> id = "3b952bfd-121d-440e-b43e-55ec1f75631f"; :>> method = VerificationMethod::test; :>> procedureText = "run_guardrails flags container-hardening risks: privileged: true => Block; a /var/run/docker.sock mount => Block; cap_add SYS_ADMIN/ALL => Block and SYS_PTRACE/SYS_MODULE/NET_ADMIN => Warn; network_mode: host => Warn (host-network); pid: host => Warn (host-pid). A benign service (e.g. cap_add NET_BIND_SERVICE) trips none. Unit-tested; verified live that `yd doctor` on a privileged + docker-socket stack is NOT READY (2 blocks, exit 3)."; }
    part securityLensDoDR1 : TestResult { :>> id = "1acc5a5a-d636-4006-b751-1b5556f3804a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9de3cdd"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate38 : Test { :>> id = "a8f4cd0d-11fd-4dc3-8236-de217f84e491"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edges set; scope = add a container-hardening lens to run_guardrails so risky stacks are blocked/warned everywhere the guardrails feed (doctor, deploy gate, UI); serves needSecureByDefault + needDeployGuardrails."; }
    part refineGate38R1 : TestResult { :>> id = "59064ef2-e498-4900-a000-44c9ea7fd5d4"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9de3cdd"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate38 : Test { :>> id = "440c0875-754b-44a6-9815-dbcb21489de0"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: DoD green (116 lib + 22 integration, 0 warnings). Five hardening rules added to run_guardrails, handling both string and mapping volume forms and CAP_-prefixed capability names; severities calibrated (privileged/docker-socket/SYS_ADMIN/ALL block; other dangerous caps + host net/pid warn). Because the lens lives in run_guardrails, it flows to doctor, the flow deploy gate, and the web UI with no extra wiring. Live-confirmed against a watchtower-style stack."; }
    part reviewGate38R1 : TestResult { :>> id = "7cf9970c-9941-402f-8dbb-cd2b62c12019"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9de3cdd"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate38 : Test { :>> id = "15da6508-a869-46c4-b196-2b080e629119"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: securityLens DoD pass. The guardrails now catch the most common container-escape footguns (privileged, docker socket, dangerous caps, host net/pid) and refuse to deploy them, strengthening needSecureByDefault across every surface."; }
    part closeOutGate38R1 : TestResult { :>> id = "3c77a59b-664c-42b2-b779-e5946e84d199"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "9de3cdd"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
