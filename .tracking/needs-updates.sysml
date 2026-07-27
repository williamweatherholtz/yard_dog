// =====================================================================
// YardDog — update-capability Needs (2026-07-27): the tool updates itself, and
// it can keep managed containers up to date through the safe-update path.
// =====================================================================
package YardDogUpdateNeeds {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    requirement needSelfUpdate : Need {
        :>> id = "d13d498a-e239-43ea-8a99-6e88681fd259";
        :>> title = "Yard Dog can update its own binary safely";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "The operator can update the Yard Dog program itself to a newer released version from within the tool — with a verified download (checksum/signature), an atomic binary replacement, and a way to revert if the new version misbehaves.";
        :>> marketJustification = "A self-hosted tool that can't update itself creates maintenance friction; safe self-update (verified + atomic + revertible) keeps a single-host install current without manual binary juggling. Rust self_update/self_replace crates make this tractable; the care is signature verification, the Windows exe-lock swap, and revert.";
        :>> priority = Priority::should;
    }

    requirement needSafeUpgrade : Need {
        :>> id = "fd242158-a538-420d-a100-f0786b7a945d";
        :>> title = "One-shot safe upgrade: back up, attempt, health-gate, regress or accept";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "The operator can upgrade a service to a target image through one orchestrated, safe flow: back up its data and snapshot its config, apply the new image, and then automatically regress to the last-good state if the healthcheck fails — and, when it passes, either auto-accept the upgrade or hold it for explicit user acceptance, regressing if the user rejects it even though it is healthy.";
        :>> marketJustification = "Addresses the headline self-hosting fear ('I upgraded and it broke and couldn't get back'). Assessed valuable and FEASIBLE by composition: pre-change backup, git config snapshot, deploy + healthcheck-gated auto-rollback, and kind-aware update detection are already built ([[needPreChangeBackup]], [[needSafeDeploy]], [[needContainerAutoUpdate]]); the only genuinely-new pieces are rewriting a service's image and the accept/regress-even-if-healthy branch — low added complexity.";
        :>> priority = Priority::should;
    }

    requirement needContainerAutoUpdate : Need {
        :>> id = "ea89704e-558f-46a3-b599-0fbd67df1f6f";
        :>> title = "Detect and safely auto-apply container image updates";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::competitive;
        :>> statement = "The tool can detect when a newer image is available for a managed service (by comparing the running image's digest to the registry's current digest for its tag) and, on a schedule or on demand, apply the update AUTOMATICALLY through the safe path — pre-update backup + config snapshot + deploy + healthcheck + rollback-on-failure + notify — gated by workload kind (never auto-major a datastore).";
        :>> marketJustification = "This is the safe, automated flavor of [[needSafeUpdates]] — Watchtower's convenience without its silent-breakage footgun, because the risky parts (backup, rollback, deploy safety, notifications, guardrails) already exist. The new work is registry digest-checking, an update policy, and a scheduler wired into safe deploy — a natural payoff of the platform.";
        :>> priority = Priority::should;
    }
}
