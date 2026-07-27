// =====================================================================
// YardDog — System Requirements for the path-intelligence + existence-guard
// core (Pillar 1). Each SR fulfils a Need via a native `satisfy <need> by <sr>`
// edge (SysML: the requirement is satisfied by the SR). These are the testable
// "what" the first sprint decomposes the path Needs into; the "how" (stack,
// algorithm details) is a later architecture Decision. Verification is COMPUTED
// from verify-edge Tests once implementation exists — keel coverage.
// =====================================================================
package YardDogRequirements {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;
    private import YardDog::*;           // needPathTyping, needPathExistence
    private import YardDogLifecycle::*;  // needGuidedRemediation, needPermissionAwareness

    requirement srClassifyMounts : SystemRequirement {
        :>> id = "70b75449-cef2-49c2-ae2d-0a56248c585e";
        :>> title = "Classify every mount into exactly one of the four path types";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> statement = "For every mount declared or resolved for a stack, the system shall determine and display exactly one classification — host bind path, named Docker volume, anonymous/container-only path, or network path (NFS/CIFS/SMB) — computed from the Compose definition, `docker inspect` / `docker volume inspect`, and the host mount table, before the stack is deployed.";
        :>> rationale = "Incumbents render mounts as opaque strings; deterministic classification from authoritative sources (compose + inspect + mount table) is the foundation of Pillar 1 and everything downstream (existence, remediation, backup path coverage).";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    requirement srHostPathExistence : SystemRequirement {
        :>> id = "3aa1f71f-5cf0-48a4-b369-7fa0307d850e";
        :>> title = "Report host-path existence and type; never implicitly create";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> statement = "For every host bind and network mount, the system shall report — before deploy — whether the resolved host path exists and whether its filesystem type (directory vs file) matches the mount's intended use, and shall NOT create a missing host path implicitly; creation happens only via an explicit, operator-confirmed action.";
        :>> rationale = "Directly answers the most-recurring path footgun (Docker/Portainer/Coolify silently auto-creating a missing bind source as a root-owned directory, or a file-mount as a directory); refusing implicit creation is the safety guarantee.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    requirement srGuidedRemediation : SystemRequirement {
        :>> id = "cb66fa9e-5bd7-4eed-b7f7-260363a7babe";
        :>> title = "Offer ranked, confirm-to-apply remediations for detected path issues";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> statement = "When the system detects a missing path, a directory/file type mismatch, or an ownership/permission mismatch (root-owned directory, PUID/PGID misalignment, NFS/CIFS root_squash), it shall present ranked, concrete remediation actions — e.g. create the path with a chosen owner, chown/chmod to the container's UID/GID, or align PUID/PGID — and apply the selected action only on explicit operator confirmation, preventing the bad state rather than only reporting it.";
        :>> rationale = "The operator wants prevention and guided resolution, not a bare warning ([[needGuidedRemediation]]); this SR is where the preventative posture becomes concrete for the path pillar.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::must;
    }

    // -- satisfy edges: each Need is fulfilled by its SR(s) --
    satisfy needPathTyping by srClassifyMounts;
    satisfy needPathExistence by srHostPathExistence;
    satisfy needGuidedRemediation by srGuidedRemediation;
    satisfy needPermissionAwareness by srGuidedRemediation;
}
