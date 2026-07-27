// =====================================================================
// YardDog — Sprint 30 delivery: correctness fixes from the project-level sweep.
// Resolves issSilentNoopUpgrade (High) and issSecretFileFalsePositive (Medium).
// =====================================================================
package Sprint30CorrectnessFix {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyCorrectnessFix : Story {
        :>> id = "112cbea1-d2d7-479e-bd8b-a91fa02f9355";
        :>> title = "Fail-loud upgrade for unknown service + stop false-flagging _FILE secrets";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyCorrectnessFix to needSafeUpgrade;
    #CharteredBy dependency from storyCorrectnessFix to needDeployGuardrails;

    action fixSilentNoopUpgrade;
    verification fixSilentNoopUpgradeDoD : Test { :>> id = "e35fb5dc-a5f3-4386-9116-c8a0282e0dd8"; :>> method = VerificationMethod::test; :>> procedureText = "An upgrade whose target service has no image line (absent or build-only) returns a distinct NoSuchService outcome (not Upgraded), applies no change, and invokes no deployer; a normal upgrade still returns Upgraded. Unit-tested at the flow and safe_upgrade layers."; }
    part fixSilentNoopUpgradeDoDR1 : TestResult { :>> id = "c49d52c3-a72e-4772-9e9a-d1762b79d50e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fefdca5"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action fixSecretFileFalsePositive;
    verification fixSecretFileFalsePositiveDoD : Test { :>> id = "ac505943-3b1b-4dea-8c42-c091bebc5f05"; :>> method = VerificationMethod::test; :>> procedureText = "run_guardrails does NOT flag a *_FILE secret reference (e.g. POSTGRES_PASSWORD_FILE: /run/secrets/db) as a plaintext-secret, while a real plaintext secret (POSTGRES_PASSWORD: hunter2) is still flagged Block. Unit-tested both directions."; }
    part fixSecretFileFalsePositiveDoDR1 : TestResult { :>> id = "f07ed9c4-6ced-45ae-9e9a-d1762cd39dc2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fefdca5"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate30 : Test { :>> id = "ba725aa4-46d0-4598-83d7-4f58146db00e"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edges set; two triaged correctness Issues (issSilentNoopUpgrade High, issSecretFileFalsePositive Medium) pulled from the project-level sweep, each with a #Resolves resolver; correctness-first."; }
    part refineGate30R1 : TestResult { :>> id = "4da2698d-9c62-4b27-9cf2-bc6993d147d9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fefdca5"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate30 : Test { :>> id = "05c32230-b297-4d06-9aba-20f5441387a0"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 2/2 DoD green (102 lib + 22 integration, 0 build warnings). (1) try_image_change returns None when the target service has no image line; flow::run fails loudly with NoSuchService BEFORE any backup/apply, so an upgrade of an absent/build-only service no longer reports Upgraded (CLI exits 3). (2) key_is_secret excludes *_FILE keys, so a Docker-secrets file reference is no longer a false-positive plaintext-secret block while inline secrets are still flagged."; }
    part reviewGate30R1 : TestResult { :>> id = "d418139a-c86d-4c9f-8377-54dd7e6b6af9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fefdca5"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate30 : Test { :>> id = "5ba1fb24-eb5c-47b8-8c8e-1ffa4c98c68e"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 2/2 DoD pass; issSilentNoopUpgrade and issSecretFileFalsePositive resolved via #Resolves. Two real correctness defects found by the project-level antagonistic sweep are fixed; safe upgrade now fails loudly and the guardrails no longer punish the more-secure _FILE convention."; }
    part closeOutGate30R1 : TestResult { :>> id = "89c08ee5-ecbe-48a6-9ac3-941bda48925f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "fefdca5"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
