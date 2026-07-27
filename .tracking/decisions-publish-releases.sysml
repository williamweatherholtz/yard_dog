// =====================================================================
// YardDog — Decision to publish GitHub Releases and build self-update apply,
// superseding the earlier defer (decDeferSelfUpdate).
// =====================================================================
package YardDogPublishReleasesDecision {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part decPublishReleases : Decision {
        :>> id = "e014142c-4ee2-4942-9670-3b234ff54f2d";
        :>> title = "Publish GitHub Releases (binaries + SHA256SUMS) and build self-update apply";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> status = DecisionStatus::accepted;
        :>> context = "decDeferSelfUpdate deferred the self-update apply because there was no release pipeline to validate against. The repo williamweatherholtz/yard_dog is already public; publishing real releases removes that blocker.";
        :>> decision = "Add a GitHub Actions release workflow that builds native yd binaries per platform and publishes them with SHA256SUMS on a version tag, and implement `yd self-update --apply`: resolve the latest release via the GitHub API, download the platform asset, verify it against the published SHA256SUMS, and atomically replace the running binary (keeping a .old backup). Verification is SHA256 integrity for v1 (cryptographic signing is a later option). crates.io publishing is out of scope for now.";
        :>> rationale = "Publishing binary releases is exactly the artifact self-update needs; SHA256 verification before an atomic in-place swap keeps the most security-sensitive operation safe (needSecureByDefault). Chosen by the human operator on 2026-07-27 (GitHub Releases + push; SHA256 baseline).";
        :>> consequences = "self-update becomes functional end to end once a release is published. A .old backup is left beside the binary after an update. aarch64-linux has no prebuilt asset in v1 (reports NoAsset). Signing can be layered on later without changing the download/verify/apply shape.";
    }

    #Supersede dependency from decPublishReleases to decDeferSelfUpdate;

    verification decPublishReleasesAccept : Test { :>> id = "da72d17d-cbcc-4c7e-b213-34e0f495081a"; :>> method = VerificationMethod::confirmation; :>> procedureText = "Human operator chose 'GitHub Releases + push' and 'SHA256 from the release' for program self-update on 2026-07-27, authorizing publishing releases and building the download/verify/atomic-replace apply."; }
    part decPublishReleasesAcceptR1 : TestResult { :>> id = "dd9120e0-d4db-4011-867e-1efc2b65147c"; :>> outcome = VerdictKind::pass; :>> judgedAt = "2026-07-27"; :>> judgedBy = "wweatherholtz"; }
}
