// =====================================================================
// YardDog — needs surfaced by voice-of-customer research (2026-07-26).
// Five VoC batches across GitHub issues/discussions, Reddit (r/selfhosted,
// r/homelab, r/docker), and community writeups converged on these. Priority
// reflects signal: MUST = validated top-unmet pain on a pillar; SHOULD =
// strong differentiator or table-stakes we must not fumble. Distractions are
// captured as a scope-cut Decision, not needs. Status is COMPUTED — keel orient.
// =====================================================================
package YardDogLifecycle {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineWork::*;
    private import EngineRelationships::*;
    private import EngineVerification::*;

    // -- Source-of-truth / no lock-in (the #1 "why I left Portainer" reason) --
    requirement needFilesOnDisk : Need {
        :>> id = "f520012f-42a0-49a8-b67f-bed4aff97615";
        :>> title = "Compose config stays as plain files on disk, owned by the operator";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::competitive;
        :>> statement = "A stack's Compose and .env remain plain files on the host filesystem, owned and directly editable by the operator — never locked inside the tool's own database.";
        :>> marketJustification = "The single most-cited reason self-hosters leave Portainer ('it kidnaps your compose files' / stacks trapped in its DB); files-on-disk is the baseline Dockge set and the foundation versioning and safe-deploy build on.";
        :>> priority = Priority::must;
    }

    // -- Path pillar extension: ownership / permission awareness --
    requirement needPermissionAwareness : Need {
        :>> id = "f6a64eae-ecd9-4d95-ae6e-9749a81bbd81";
        :>> title = "Warn on ownership / permission mismatches for bind and network paths";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "Before deploy, the operator is warned about ownership and permission mismatches on bind and network mounts — root-owned directories, PUID/PGID misalignment, and NFS/CIFS root_squash — AND is offered concrete, safe remediations the tool can apply on the operator's confirmation (e.g. chown/chmod to the container's UID/GID, align PUID/PGID, adjust the mount) rather than being left to diagnose and fix it manually.";
        :>> marketJustification = "Root-owned auto-created bind dirs and PUID/PGID/NFS permission hell are among the most recurring self-hosting frustrations; a warning alone is insufficient — the differentiator is guiding the operator to a fix. See [[needGuidedRemediation]].";
        :>> priority = Priority::should;
    }

    // -- Deploy-safety extension: drift detection --
    requirement needDriftDetection : Need {
        :>> id = "afd258c3-9c9e-4957-a9d5-7c0c7c3fe1a7";
        :>> title = "Detect drift between the running stack and its Compose file";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "The operator can see when a running stack has drifted from its Compose file (out-of-band docker changes), rather than the tool silently misreporting the running state.";
        :>> marketJustification = "Portainer misreporting state after out-of-band changes is a repeatedly-cited trust-erosion driver ('I'd head to the terminal to verify what Portainer showed'); drift surfacing is unclaimed.";
        :>> priority = Priority::should;
    }

    // -- Backup pillar extension: verified restores --
    requirement needRestoreVerification : Need {
        :>> id = "e270cd71-f9ee-4fa7-ad91-b8bfa24d5749";
        :>> title = "Automated restore verification";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "Backups are automatically restore-tested and verified, so a backup that cannot be restored is surfaced to the operator before it is ever needed.";
        :>> marketJustification = "'An untested backup isn't a backup' is a near-universal community refrain; almost no DIY or manager-integrated setup verifies restores — a clean unserved differentiator.";
        :>> priority = Priority::should;
    }

    // -- Adjacent flagship: safe update management (fuses backup + deploy) --
    requirement needSafeUpdates : Need {
        :>> id = "2948211e-507a-4e8e-be93-ade45590d0eb";
        :>> title = "Safe image-update management with pre-update snapshot and rollback";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::competitive;
        :>> statement = "The operator can manage image updates safely — review before applying, pin versions (never auto-major a database), take an automatic pre-update snapshot, and roll back a bad update to last-good.";
        :>> marketJustification = "Updates are the loudest single theme (Watchtower simultaneously loved for convenience and distrusted for silent breakage with no rollback); 'snapshot-before-update + notify + rollback' fuses the backup and deploy-safety pillars into the strongest adjacent bet.";
        :>> priority = Priority::should;
    }

    // -- Table-stakes: operational visibility --
    requirement needOperationalVisibility : Need {
        :>> id = "dce83f14-4596-424a-be9a-9a76df96eb77";
        :>> title = "Live logs and container health notifications";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "The operator can view live container logs and be notified through common channels when a container dies or becomes unhealthy.";
        :>> marketJustification = "Table-stakes to not look toy-like: Dozzle-style live logs and 'tell me when a container dies' (Apprise/ntfy/Discord) are near-universal expectations; full metrics/observability is explicitly out of scope.";
        :>> priority = Priority::should;
    }

    // -- Table-stakes: frictionless onboarding --
    requirement needImportAdopt : Need {
        :>> id = "32ffbc6e-19bf-4e60-ac0b-98515c5b65e9";
        :>> title = "Adopt existing stacks and import existing Compose without rebuilding";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "The operator can adopt already-running stacks and import existing Compose/.env files (e.g. migrating off Portainer) without rebuilding or losing data.";
        :>> marketJustification = "Migration-off-Portainer is a recurring story; a 'scan a folder / adopt running stacks' path is low-cost, high-trust onboarding that reinforces the files-on-disk story.";
        :>> priority = Priority::should;
    }

    // -- Cross-cutting posture: prevent & remediate, don't just warn (2026-07-26 feedback) --
    requirement needGuidedRemediation : Need {
        :>> id = "5450c32f-5e6a-4d24-9705-6ee0490008e7";
        :>> title = "Preventative, guided remediation — don't just warn, help fix";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "When the tool detects a problem — permission/ownership mismatch, a missing or mistyped path, config drift, or a failed or risky change — it does not merely warn: it identifies the likely cause and offers concrete, safe remediations it can apply on the operator's explicit confirmation, preventing the bad state rather than only reporting it.";
        :>> marketJustification = "Incumbents at best surface a warning and leave the operator to diagnose and fix; the operator wants prevention and guided resolution. This posture governs the path (existence/ownership), drift, backup, and deploy/update needs — a warning is useful but insufficient.";
        :>> priority = Priority::must;
    }

    // -- Scope-cut Decision: what the research says NOT to build in v1 --
    part decV1Exclusions : Decision {
        :>> id = "2b918eb2-77db-4dec-866e-cd6b4ca04a90";
        :>> title = "Exclude from v1: multi-host, template catalog, full RBAC/SSO, heavyweight secrets, full observability, built-in reverse proxy";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::accepted;
        :>> context = "VoC research surfaced many adjacent asks. Several are either explicitly low-value for a single-host audience or scope-heavy enough to dilute the two pillars if built in v1.";
        :>> decision = "v1 deliberately excludes: multi-host/agent fleet management; curated template/app catalogs; full RBAC / SSO / audit; heavyweight secrets backends (e.g. Vault); a full metrics/observability platform (Prometheus/Grafana); and a built-in reverse proxy. Reverse-proxy and secrets are addressed by lightweight AWARENESS/integration, not by building the subsystem.";
        :>> rationale = "Single-host users repeatedly call agent/fleet models overkill, and deliberately staying single-host is a positioning asset. Template catalogs go stale and power users prefer authoring Compose. Full RBAC/observability/proxy are large subsystems that would compete with the path+backup+deploy-safety bet for effort; the research shows lightweight integration (Traefik/Caddy label awareness; SOPS/age + warn-on-plaintext) captures most of the value cheaply.";
        :>> consequences = "Keeps v1 focused and light (supporting the simplicity need). Leaves clean seams to revisit multi-host, RBAC, and richer secrets/proxy later; each exclusion remains open to re-evaluation as the product matures.";
    }

    verification decV1ExclusionsAccept : Test { :>> id = "9c8a1215-78e4-4c69-a0e8-f6ea355fe3e9"; :>> method = VerificationMethod::confirmation; :>> procedureText = "wweatherholtz attests acceptance of decV1Exclusions — exclude multi-host, template catalog, full RBAC/SSO, heavyweight secrets, full observability, and built-in reverse proxy from v1 (agreed 2026-07-26)."; }
    part decV1ExclusionsAcceptR1 : TestResult { :>> id = "cd688c32-166b-4ac2-9b1e-33c18a913398"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "wweatherholtz"; }
}
