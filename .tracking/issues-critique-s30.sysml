// =====================================================================
// YardDog — critique-battery findings (project-level sweep, post-Sprint 29).
// An antagonistic correctness pass over the deploy/upgrade/guardrail surface.
// Each Issue is triaged with a #Resolves edge to its Sprint 30 resolver task.
// =====================================================================
package YardDogCritiqueIssuesS30 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    // -- CORRECTNESS (High): an upgrade of an absent/build-only service is a silent no-op --
    part issSilentNoopUpgrade : Issue {
        :>> id = "91720852-3ea2-456c-a860-b22fcf73adc9";
        :>> title = "Upgrade of an absent/build-only service reports Upgraded but changes nothing";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "image_changed_yaml returns the text UNCHANGED when the named service has no image line (a typo'd service name, or a build-only service). safe_upgrade then snapshots a no-op, deploys, and reports Upgraded — so the operator believes an image upgrade happened when nothing changed. A safe upgrade must fail loudly when it cannot apply the requested change. Fix: signal 'no image line changed' from the edit and surface it as a distinct non-success outcome (NoSuchService) rather than Upgraded.";
        :>> discoveredInField = false;
        :>> severity = Severity::High;
    }

    // -- CORRECTNESS (Medium): _FILE secret references are falsely flagged as plaintext --
    part issSecretFileFalsePositive : Issue {
        :>> id = "4a445ebe-1708-4b5b-a3eb-4340e6952fe2";
        :>> title = "Guardrails flag *_FILE secret references as plaintext secrets (false positive Block)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "The plaintext-secret rule flags e.g. POSTGRES_PASSWORD_FILE: /run/secrets/db because the key contains PASSWORD and the value has no ${...}. But a *_FILE key is the Docker-secrets convention — a path to a mounted secret, which is MORE secure, not less. Flagging it as a block-severity plaintext secret wrongly blocks a good stack (and via the deploy gate, refuses the deploy). Fix: exclude keys ending in _FILE from the plaintext-secret rule.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    #Resolves dependency from fixSilentNoopUpgrade to issSilentNoopUpgrade;
    #Resolves dependency from fixSecretFileFalsePositive to issSecretFileFalsePositive;
}
