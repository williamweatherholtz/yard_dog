// =====================================================================
// YardDog — Sprint 35 delivery: real registry-digest resolution for yd updates.
// Docker Hub + GHCR (public, anonymous) via ureq; validates ucUpdateCheck live.
// =====================================================================
package Sprint35RealUpdates {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyRealUpdates : Story {
        :>> id = "1bcbc8d7-7a4a-4bdd-bbc9-6ffafb415bd0";
        :>> title = "yd updates resolves real remote digests (Docker Hub + GHCR)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyRealUpdates to needSafeUpdates;

    action parseImageRef;
    verification parseImageRefDoD : Test { :>> id = "ea42ff81-d296-4da7-aa6f-79bb6feb0ed6"; :>> method = VerificationMethod::test; :>> procedureText = "registry::parse_image_ref splits an image into (api_host, token_url, repository, tag): Docker Hub official images get the library/ prefix and auth.docker.io token; namespaced and GHCR (ghcr.io/owner/img) images keep their repo and use the registry's own /token; no tag defaults to latest; a digest-pinned ref returns None. Unit-tested."; }
    part parseImageRefDoDR1 : TestResult { :>> id = "dafb7b84-5d65-40d5-8170-39c4a2cf5c2a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "409dbe0"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action registryLive;
    verification registryLiveDoD : Test { :>> id = "436a998c-c199-41b8-a96b-9d8c3804d164"; :>> method = VerificationMethod::demo; :>> procedureText = "registry::tests::remote_digest_live (opt-in, --ignored): HttpRegistryClient resolves a real sha256 digest for a Docker Hub image (nginx:1.27-alpine) AND a GHCR image (ghcr.io/astral-sh/uv:latest) via the anonymous token + manifest HEAD flow."; }
    part registryLiveDoDR1 : TestResult { :>> id = "aa664562-2708-40f0-8fd0-265786963aac"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "409dbe0"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action updatesDemo;
    verification updatesDemoDoD : Test { :>> id = "9c8f2160-5224-453a-8c73-4dd33198e8c1"; :>> method = VerificationMethod::demo; :>> procedureText = "e2e_docker::e2e_uc_update_check + manual: after deploying nginx:1.27-alpine, `yd updates` reports the web service UpToDate — the locally-pulled digest matches the current Docker Hub digest. run_updates reads local digests via `docker image inspect` and remote digests via HttpRegistryClient."; }
    part updatesDemoDoDR1 : TestResult { :>> id = "a7d3dd57-e33f-4cb5-8077-5dac89ac3727"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "409dbe0"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    #Verify dependency from updatesDemoDoD to ucUpdateCheck;
    #Verify dependency from registryLiveDoD to ucUpdateCheck;

    verification refineGate35 : Test { :>> id = "bd217067-84e0-490b-89c9-34fd34497354"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edge set; scope per human decision = Docker Hub + GHCR public (anonymous) via ureq; pure image-ref parsing + URL building unit-tested, HTTP validated live; add ucUpdateCheck + e2e. Self-update apply deferred (decDeferSelfUpdate)."; }
    part refineGate35R1 : TestResult { :>> id = "7cda0b74-ced4-4254-b766-469a5da4b86f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "409dbe0"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate35 : Test { :>> id = "c39f9726-b515-4c0f-ac41-7140ab09ffcc"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (109 lib + 22 integration + 9 opt-in tests, 0 warnings). New registry.rs: pure parse_image_ref/manifest_url (unit-tested for Docker Hub official/namespaced + GHCR + digest-pinned) and HttpRegistryClient (ureq anonymous token + manifest HEAD -> Docker-Content-Digest). run_updates now uses real local digests (docker image inspect) + HttpRegistryClient; PendingRegistry stub removed. Live: Docker Hub AND GHCR resolve real digests; `yd updates` reports UpToDate for a freshly-pulled image."; }
    part reviewGate35R1 : TestResult { :>> id = "93e73de6-9a79-4ae2-a06a-fff9bce1230a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "409dbe0"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate35 : Test { :>> id = "0b6041bf-3184-4867-a602-de2358d8fbd8"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; ucUpdateCheck validated live against Docker Hub + GHCR. Second deferred seam (registry-digest resolution) is now real. The remaining seam — self-update apply — is deferred by accepted decision decDeferSelfUpdate until a release pipeline exists."; }
    part closeOutGate35R1 : TestResult { :>> id = "d900399f-05df-4fe5-8ad1-4ce7dc7872d0"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "409dbe0"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
