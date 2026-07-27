// =====================================================================
// YardDog — Sprint 31 delivery: bidirectional backup verify.
// Resolves issVerifyExtraFiles (Medium): verify flags unexpected/extra files.
// =====================================================================
package Sprint31VerifyExact {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyVerifyExact : Story {
        :>> id = "953aaeff-cb88-44c8-a622-14168cacc9fb";
        :>> title = "Backup verify is an exact match: detect unexpected/extra files";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 2;
    }

    #CharteredBy dependency from storyVerifyExact to needRestoreVerification;

    action verifyDetectsExtra;
    verification verifyDetectsExtraDoD : Test { :>> id = "ec8ead02-6c7e-4341-a0b2-28f6b6e7ee11"; :>> method = VerificationMethod::test; :>> procedureText = "verify() reports Finding::Unexpected for a file present under the backup dir but absent from the manifest (manifest.json itself excluded); an intact backup still yields no findings and Missing/Changed detection is unaffected. Unit-tested."; }
    part verifyDetectsExtraDoDR1 : TestResult { :>> id = "b95485bb-3ba2-45bd-85d2-094f420b46ef"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c6999aa"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate31 : Test { :>> id = "ea596daf-4573-4573-8de1-0f7d0cc6213a"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (2); charter edge set; triaged Issue issVerifyExtraFiles (Medium) with a #Resolves resolver; makes the integrity check bidirectional; correctness-first on the backup pillar."; }
    part refineGate31R1 : TestResult { :>> id = "80ca0619-d939-4673-93f9-2e62cceb57bb"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c6999aa"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate31 : Test { :>> id = "902c9406-dff9-40d7-90b0-abdcf9dd7aed"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: DoD green (103 lib + 22 integration, 0 build warnings). verify() now walks the backup dir after the manifest-entry pass and flags Finding::Unexpected for any file absent from the manifest (manifest.json excluded), making integrity an exact match in both directions. Existing intact / Missing / Changed tests unaffected; verify still exits non-zero on any finding."; }
    part reviewGate31R1 : TestResult { :>> id = "0b5c673b-7efb-4185-b8d9-3f0f9cf99b81"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c6999aa"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate31 : Test { :>> id = "931a1709-7c5d-4e06-8df2-e9516b3bc455"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: verifyDetectsExtra DoD pass; issVerifyExtraFiles resolved via #Resolves. The backup integrity check is now bidirectional, closing the last gap found in the data-safety sweep."; }
    part closeOutGate31R1 : TestResult { :>> id = "7552ac89-fb54-4c61-9c77-f223dce6af72"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "c6999aa"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
