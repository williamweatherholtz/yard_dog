// =====================================================================
// YardDog — Sprint 24 delivery: preserve compose formatting on image edits.
// Resolves issYamlReformat: replace the serde_yaml round-trip in the image edit
// with a surgical in-place line edit that preserves comments and formatting.
// Work item is the ProductBacklog resolver preserveComposeFormat.
// =====================================================================
package Sprint24YamlPreserve {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyYamlPreserve : Story {
        :>> id = "b1f064f3-480b-4318-9e59-3b377aea0561";
        :>> title = "Surgical image edit preserves compose comments and formatting";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyYamlPreserve to needSafeUpgrade;

    verification refineGate24 : Test { :>> id = "045ddca3-9cd5-4267-a952-c10fa4a5483d"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope = image_changed_yaml edits the target service's image line in place, preserving comments and the rest of the file byte-for-byte; work item is preserveComposeFormat."; }
    part refineGate24R1 : TestResult { :>> id = "6bd5b7e9-1a4a-4f1f-9145-33a8822ed0fe"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7af4b16"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate24 : Test { :>> id = "63cde5c7-4db6-46bf-bcd1-d28103102cca"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: resolver green (83 lib + 19 integration, 0 build warnings). image_changed_yaml now does a surgical, line-oriented edit of the target service's image line — top-of-file and inline comments, sibling keys, and other services survive byte-for-byte; only the matched image value changes. serde_yaml round-trip removed from the edit path. Existing rewrites-only-that-service test still green (surgical output is valid YAML)."; }
    part reviewGate24R1 : TestResult { :>> id = "58780a9a-07b1-4771-bcaf-5e417ee16984"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7af4b16"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate24 : Test { :>> id = "c45dce82-cec4-4052-bbaf-a97bea62f110"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: preserveComposeFormat DoD pass; issYamlReformat resolved via #Resolves. The files-on-disk promise holds — an upgrade no longer reformats the compose or drops operator comments. Remaining critique issue: issReadme (Sprint 25)."; }
    part closeOutGate24R1 : TestResult { :>> id = "0f315f97-66b9-480d-8d19-9bfdd9ee0493"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "7af4b16"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
