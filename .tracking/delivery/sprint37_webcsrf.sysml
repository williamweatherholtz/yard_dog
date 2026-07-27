// =====================================================================
// YardDog — Sprint 37 delivery: anti-CSRF hardening of the web control plane.
// Resolves issWebCsrf (High) found by the security critique of Sprint 36.
// =====================================================================
package Sprint37WebCsrf {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyWebCsrf : Story {
        :>> id = "955f7025-51cc-451e-95d2-73f450804257";
        :>> title = "Block cross-site POSTs to the web control plane (require JSON + loopback origin)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p0;
        :>> owner = "ai";
        :>> estimatedPoints = 2;
    }

    #CharteredBy dependency from storyWebCsrf to needSecureByDefault;

    action hardenWebCsrf;
    verification hardenWebCsrfDoD : Test { :>> id = "cca68c7c-8eef-41ab-a7b9-8d884a74b1e5"; :>> method = VerificationMethod::test; :>> procedureText = "mutation_allowed(content_type, origin) returns true only for Content-Type application/json AND (no Origin OR a loopback Origin); a text/plain or missing content-type, or a non-loopback Origin, is refused. serve() applies it to every POST /api/* and returns 415 otherwise. Unit-tested + live: text/plain drive-by => 415, application/json from evil Origin => 415, legit application/json UI request succeeds."; }
    part hardenWebCsrfDoDR1 : TestResult { :>> id = "0e7f3f0d-8f89-4bdb-9dcc-f7856cdf116c"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b9f4c64"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate37 : Test { :>> id = "43abaf6b-f0db-4bc2-abad-6d7d5d521141"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (2); charter edge set; triaged High security Issue issWebCsrf with a #Resolves resolver; fix = require application/json + loopback Origin on mutations (defense-in-depth over loopback bind + Host allowlist); correctness/security-first."; }
    part refineGate37R1 : TestResult { :>> id = "22088cbf-41b6-4e60-8ef4-6c7e6605afe8"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b9f4c64"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate37 : Test { :>> id = "d349a9fb-dabf-4ccd-ada7-48e4b3cb7cea"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: DoD green (114 lib + 22 integration, 0 warnings). mutation_allowed gate added and enforced on all POST /api/* (415 otherwise); requiring application/json forces a CORS preflight the server never allows, so a cross-origin 'simple' POST cannot reach an action, and a non-loopback Origin is refused outright. Verified live. The UI already sends application/json, so it is unaffected."; }
    part reviewGate37R1 : TestResult { :>> id = "d508edb4-f8b0-481c-b658-63401235b235"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b9f4c64"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate37 : Test { :>> id = "aecbc141-e943-4827-b8bd-f5b9d8fa73e1"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: hardenWebCsrf DoD pass; issWebCsrf resolved via #Resolves. The web control plane's mutation path now resists cross-site drive-by requests, closing the last known gap in the secure-by-default UI surface."; }
    part closeOutGate37R1 : TestResult { :>> id = "1bf37cd1-3c75-4f4a-ac75-97e768b8ad51"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b9f4c64"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
