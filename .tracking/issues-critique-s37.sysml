// =====================================================================
// YardDog — security critique finding on the new web control plane (S36).
// =====================================================================
package YardDogCritiqueIssuesS37 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    // -- SECURITY (High): cross-site POST can trigger actions on the local UI --
    part issWebCsrf : Issue {
        :>> id = "0cd46832-11e8-4184-999a-fe2413cdfcc8";
        :>> title = "Web control plane accepts cross-site POSTs (CSRF): a visited page could deploy/down a stack";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "The Host-header allowlist defeats DNS-rebinding but NOT a classic cross-site request: a malicious page the operator visits can send a 'simple' cross-origin POST (Content-Type text/plain) to http://127.0.0.1:8770/api/deploy etc. The browser delivers the request (CORS only blocks reading the response, not the side effect), and handle_action parses the body regardless of Content-Type, so the action runs. For a no-auth control plane over Docker this is a real drive-by risk. Fix: require Content-Type application/json for mutations (a non-simple type forces a CORS preflight that the server does not honor, blocking cross-origin) AND reject any request whose Origin header is present and not loopback. Defense-in-depth on top of loopback bind + Host allowlist.";
        :>> discoveredInField = false;
        :>> severity = Severity::High;
    }

    #Resolves dependency from hardenWebCsrf to issWebCsrf;
}
