// =====================================================================
// YardDog — Business-layer authored facts (Brief, Needs, scope Decision).
// Product concept: a self-hosted, OSS, single-host Docker + Compose manager
// whose two co-equal pillars are (1) accurate mount-path intelligence and
// (2) database-respecting, application-consistent backup.
// Authored 2026-07-26. Status/coverage/trace are COMPUTED — see `keel orient`.
// =====================================================================
package YardDog {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineWork::*;
    private import EngineRelationships::*;
    private import EngineVerification::*;

    // -- Project brief: the problem + the opportunity --
    part brief : Brief {
        :>> id = "8618e1a9-a40a-4f5c-8135-e2ab8216d1a1";
        :>> title = "Yard Dog — a safe self-hosted Docker/Compose manager";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> problem = "Self-hosters running single-host Docker/Compose rely on managers (Portainer, Dockge, etc.) that treat every mount path as an opaque string: they cannot tell a host bind-mount from a named volume, an anonymous/container-only path, or a network (NFS/CIFS/SMB) path, and some silently create missing host directories (the Portainer footgun) — scattering data in the wrong place or as root-owned empty dirs. The same tools have no integrity-aware backup: 'backup' means copying files out from under a live database (corruption risk) or merely exporting the manager's own settings — not the stack's actual data.";
        :>> opportunity = "A self-hosted, open-source, single-host Docker + Compose manager that (a) accurately classifies and validates every mount's true type and existence before deploy, and (b) performs application-consistent, database-respecting backups of named volumes, bind mounts, and managed databases to local and remote targets with retention. Path intelligence and backup integrity are co-equal pillars that no incumbent self-hosted tool combines.";
    }

    // -- PILLAR 1: path intelligence --

    requirement needPathTyping : Need {
        :>> id = "2affcab4-a140-4b39-9f20-64d8128de39f";
        :>> title = "Accurate mount-path type classification";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "For any mount referenced by a stack, the operator can see its true classification — host bind path, named Docker volume, anonymous/container-only path, or network (NFS/CIFS/SMB) path — accurately, before the stack is deployed.";
        :>> marketJustification = "Incumbent managers render mounts as opaque strings, so operators cannot reason about where data actually lives; accurate typing is a core differentiator.";
        :>> priority = Priority::must;
    }

    requirement needPathExistence : Need {
        :>> id = "248d66a7-acf5-44d9-ae65-fa84419f03a8";
        :>> title = "Host-path existence awareness; no erroneous creation";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "The operator is told whether a referenced host path already exists on the host before deploy, and the system never silently or erroneously creates a missing host bind path.";
        :>> marketJustification = "Portainer and the Docker CLI silently create missing bind-source directories (often root-owned, in the wrong place), a well-known data-placement footgun this product refuses to repeat.";
        :>> priority = Priority::must;
    }

    // -- PILLAR 2: backup integrity --

    requirement needDbConsistentBackup : Need {
        :>> id = "abcdbc2d-c302-4ffd-bbe4-d96e7ab59ca4";
        :>> title = "Application-consistent database backup";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "The operator can back up a stack's databases in an application-consistent state (quiesced or logically dumped), not as raw copies of live database files.";
        :>> marketJustification = "Self-hosted managers either lack backup or copy live files, risking corrupt/torn database backups; integrity is the headline of pillar 2.";
        :>> priority = Priority::must;
    }

    requirement needBackupCoverage : Need {
        :>> id = "4bb3d898-2e7f-4ccc-aa1c-3733990691bd";
        :>> title = "Backup covers all persistent stack data";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "A single backup covers all of a stack's persistent data — named Docker volumes and bind-mounted host paths — not only its databases and not merely the manager's own configuration.";
        :>> priority = Priority::must;
    }

    requirement needRemoteBackup : Need {
        :>> id = "54f3fd15-52a7-4aac-9d98-2f487b38908b";
        :>> title = "Remote backup destinations with retention";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "The operator can send backups to remote destinations (e.g. object storage or SFTP) and retain them under a scheduled rotation/retention policy, not just to local disk.";
        :>> priority = Priority::must;
    }

    // -- Base platform (table-stakes parity so the pillars have a home) --

    requirement needComposeManagement : Need {
        :>> id = "de5e851b-71bd-4d35-b803-dbc4c9f33bb0";
        :>> title = "Single-host Docker + Compose management";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "A self-hoster can deploy, view, edit, and control single-host Docker and docker-compose stacks from one self-hosted, open-source tool.";
        :>> marketJustification = "Parity with Dockge/Portainer-CE is table-stakes; it is the surface the path-intelligence and backup pillars attach to.";
        :>> priority = Priority::must;
    }

    // -- Deployment safety & lifecycle (surfaced 2026-07-26) --

    requirement needVersionedCompose : Need {
        :>> id = "8be9fe1b-6f66-49e7-8c8e-24c159c19283";
        :>> title = "Versioned Compose configuration with rollback";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "The operator can view the change history of a stack's Compose configuration and roll it back to any previous version.";
        :>> marketJustification = "Incumbents either store the stack in an opaque internal DB (Portainer) with no history, or leave versioning entirely to the user; prior working config is not first-class or recoverable.";
        :>> priority = Priority::must;
    }

    requirement needSafeDeploy : Need {
        :>> id = "35f7e1e6-fb07-434c-8f8d-9869e7890393";
        :>> title = "Safe deploy — a failed change never loses prior state or edits";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "When a deployment fails, the operator's edits and the previously-running working state are both preserved and restorable; a failed change never destroys the prior stack nor discards the operator's in-progress changes.";
        :>> marketJustification = "A failed `docker compose up` today can leave a stack broken and the operator's edits lost; deployments must be atomic and safe-by-default with rollback to last-good.";
        :>> priority = Priority::must;
    }

    requirement needPreChangeBackup : Need {
        :>> id = "549c12f8-526e-4a03-bfb3-7b72bdcccaa3";
        :>> title = "Automatic backup before applying a change";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "Before a change is applied to a running stack, its persistent data and configuration are automatically backed up, so that any change is reversible.";
        :>> marketJustification = "Ties backup integrity (pillar 2) to deployment safety: today backup and deploy are separate, so a bad change can corrupt data with no automatic recovery point.";
        :>> priority = Priority::must;
    }

    requirement needSimplicity : Need {
        :>> id = "faa31dff-8378-44d9-97b1-18eba5823611";
        :>> title = "Simple to operate for a single-host self-hoster";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> source = NeedSource::operator;
        :>> statement = "A single-host self-hoster can perform the common tasks — deploy, edit, back up, restore, roll back — with minimal cognitive overhead, without deep Docker expertise or manual per-container wiring.";
        :>> marketJustification = "Power comes bundled with complexity in the PaaS tier (Coolify/Dokploy) while the simple tier (Dockge) lacks backup/path safety; simplicity WITH the safety features is the unmet posture.";
        :>> priority = Priority::must;
    }

    // -- Scope Decision (captured per CLAUDE.md §2.4, even though it cuts no Need yet) --
    part decScope : Decision {
        :>> id = "7b3cce33-6504-4efe-becb-68a01549ff12";
        :>> title = "Scope v1 to single-host Docker + Compose, self-hosted OSS; defer Kubernetes/Swarm";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::accepted;
        :>> context = "The container-management landscape splits between single-host Compose managers (Dockge, Yacht) and multi-host/K8s platforms (Portainer BE, Rancher, Komodo). Our differentiators — path-type intelligence and database-respecting backup — are most acute, and least served, in the single-host self-hosted niche.";
        :>> decision = "v1 targets single-host Docker + docker-compose only, shipped as self-hosted open-source software. Kubernetes and Swarm orchestration are explicitly out of scope for v1.";
        :>> rationale = "Single-host keeps path semantics tractable (one host filesystem) and lets backup reason about concrete local paths and volumes. The self-hosted OSS posture matches the homelab/SMB audience that feels the Portainer path/backup pain. K8s/Swarm add distributed-storage complexity that would dilute the core bet; revisit once the path+backup pillars are proven.";
        :>> consequences = "Head-to-head comparison centers on Dockge / Portainer-CE / Komodo / Coolify-class tools; K8s platforms are context, not competitors. Multi-host and clustered storage remain open questions for a later decision.";
    }

    verification decScopeAccept : Test { :>> id = "8d6bb158-3bbd-4fd5-a0cd-2deb7e08585e"; :>> method = VerificationMethod::confirmation; :>> procedureText = "wweatherholtz attests acceptance of decScope — scope v1 to single-host Docker + Compose, self-hosted OSS, defer Kubernetes/Swarm (agreed 2026-07-26)."; }
    part decScopeAcceptR1 : TestResult { :>> id = "3c81101a-ceb2-48d5-b9aa-a0311adbd187"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "wweatherholtz"; }
}
