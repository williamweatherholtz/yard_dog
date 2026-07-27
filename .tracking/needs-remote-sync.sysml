// =====================================================================
// YardDog — Need: sync versioned config to a remote git, credentials handled.
// =====================================================================
package YardDogRemoteSyncNeeds {
    private import EngineElement::*;
    private import EngineNeeds::*;

    requirement needRemoteConfigSync : Need {
        :>> id = "5e691e7c-7d7f-4626-b9d3-70d478598a94";
        :>> title = "Connect a git remote and sync versioned config elegantly";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "The operator can connect the versioned stack-config repo to a remote git (GitHub, GitLab, or a self-hosted host) and push/pull it, with authentication handled elegantly (a token or SSH key entered once and stored safely), so config history is backed up offsite and portable. Secrets and data remain excluded from what is pushed (as they are from the local repo).";
        :>> marketJustification = "Local-only versioning protects against bad changes but not against losing the box. Offsite config sync is what makes a homelab recoverable and reproducible; doing the auth handshake painlessly (not raw git CLI) is a differentiator for non-expert operators.";
        :>> priority = Priority::should;
    }
}
