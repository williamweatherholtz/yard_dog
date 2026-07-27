// =====================================================================
// YardDog — tracked Issues (gaps/bugs). Resolution is COMPUTED from a
// #Resolves edge to a completed resolver (backlog action done, or an accepted
// Decision) — never an authored status (D0077).
// =====================================================================
package YardDogIssues {
    private import EngineElement::*;
    private import EngineWork::*;

    part issueComposeInterpolation : Issue {
        :>> id = "7a9d96bd-8bb3-441b-a850-0480dd65def6";
        :>> title = "Compose ${VAR:-default} / ${VAR:?err} interpolation forms not handled";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> description = "The compose interpolator handles plain ${VAR} and $VAR, but not the shell-style default/error forms ${VAR:-default}, ${VAR-default}, ${VAR:?msg}. A source like ${CONFIG:-/opt/immich}/config resolves the whole braces span as a variable name (not found -> empty), yielding a wrong path. Found in the Sprint 1 live demo; outside the Sprint 1 DoD (which specified plain ${VAR}). Classification/existence/remediation are unaffected for plain forms.";
        :>> discoveredInField = false;
        :>> severity = Severity::Low;
    }
}
