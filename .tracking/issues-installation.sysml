// =====================================================================
// YardDog — installation gaps (researched 2026-07-27). Today the only install
// path is "download a release binary + yd self-update"; there is no OS-native
// installation per arch, no install script, and no container image. Each Issue
// is triaged with a #Resolves resolver.
// =====================================================================
package YardDogInstallIssues {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    // -- one-line, checksum-verifying installer -------------------------------
    part issInstallScript : Issue {
        :>> id = "631bce01-ea48-4bbe-8a3b-5870b239824b";
        :>> title = "No install script — provide a checksum-verifying one-liner (sh + PowerShell)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "There is no `curl … | sh` / `irm … | iex` installer. Provide a POSIX sh script and a PowerShell script that detect OS + arch, download the matching release asset from GitHub Releases, VERIFY it against the published SHA256SUMS (reusing the same asset-name + digest scheme as `yd self-update`), and install `yd` onto PATH (e.g. /usr/local/bin or %LOCALAPPDATA%). This is the fastest broad-coverage install and shares the self-update trust model.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- Linux packages + service unit ----------------------------------------
    part issInstallLinuxPkg : Issue {
        :>> id = "e23e7b3f-5944-4194-a7d7-4d10e0abb3ab";
        :>> title = "No Linux packages — provide .deb/.rpm (x86_64 + aarch64) and a systemd unit for `yd serve`";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Proper OS installation on Linux: build .deb and .rpm packages for x86_64 and aarch64 (e.g. via cargo-deb / cargo-generate-rpm or nfpm in the release workflow), plus a tarball fallback. Ship an OPTIONAL systemd unit that runs `yd serve` bound to loopback (needSecureByDefault) for operators who want the control plane always available. Requires the aarch64-linux release asset to exist (see issReleaseArchGaps).";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- macOS Homebrew --------------------------------------------------------
    part issInstallMacosBrew : Issue {
        :>> id = "f64f3f65-3206-4660-ac51-8e481f4590dd";
        :>> title = "No Homebrew formula — provide a tap (arm64 + Intel)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "macOS operators expect `brew install`. Publish a Homebrew tap/formula that installs the release binary for both arm64 and Intel (the Intel asset is currently missing — see issReleaseArchGaps). Consider automating the formula bump on each release.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- Windows package managers ---------------------------------------------
    part issInstallWindows : Issue {
        :>> id = "7f1f9bbb-3791-4a5a-9b4e-ac8ea3c10f4a";
        :>> title = "No Windows package — provide a Scoop manifest and/or winget package";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Windows operators expect `scoop install` or `winget install`. Publish a Scoop manifest (and/or a winget manifest) pointing at the windows release asset with its SHA256; optionally an MSI later. The install script (issInstallScript) covers the interim.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- optional container image (with the socket caveat) --------------------
    part issContainerImage : Issue {
        :>> id = "081ade53-c0e9-44e4-861a-198e998daa61";
        :>> title = "No container image — offer one, documenting the Docker-socket security trade-off";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "There is no way to run yd itself as a container / compose stack. yd manages the HOST's Docker, so a containerized yd must mount /var/run/docker.sock — which Yard Dog's own guardrails flag as host-root-equivalent (Block). Decide and document: either (a) publish an image + an example compose with a prominent socket-risk warning for operators who insist, framing the host binary as the recommended install; or (b) explicitly decline a container image and say why. Do not silently ship a socket-mounting compose that contradicts needSecureByDefault.";
        :>> discoveredInField = false;
        :>> severity = Severity::Low;
    }

    // -- complete the per-arch release matrix ---------------------------------
    part issReleaseArchGaps : Issue {
        :>> id = "5eb91e7c-2434-4f57-82a9-e7906123fbd0";
        :>> title = "Release matrix is incomplete: no aarch64-linux and no macOS Intel asset";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "The release workflow currently publishes linux x86_64, windows x86_64, and macOS arm64. For 'proper OS installation per arch' it should also publish aarch64-linux (common on Raspberry Pi / ARM homelab boxes) and macOS x86_64 (Intel, trimmed earlier when its runner queued). Add aarch64-linux via `cross` or an ARM runner, and re-add macOS Intel (or via `lipo` universal binary). selfupdate::platform_asset_name already anticipates aarch64-linux and reports NoAsset until it exists.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- publish the container image from CI (Sprint 53 follow-up) ------------
    part issContainerCiPublish : Issue {
        :>> id = "975e33fe-0c04-4e35-85f1-36ab6065ef45";
        :>> title = "CI must build + publish the multi-arch container image to GHCR per release";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Sprint 53 shipped packaging/docker/{Dockerfile,docker-compose.yml}, proved the image live locally, AND added a `docker-publish` job to release.yml (buildx --platform linux/arm64,linux/amd64 --push to ghcr.io, tagging version + latest). REMAINING (why still open): that job only runs on a version-tag push, so it is written-but-unproven — the ghcr.io/williamweatherholtz/yard-dog:latest image the compose pins does not exist until the next tagged release actually publishes it. Resolve by cutting a release and confirming `docker pull` + `docker compose up -d` work against the published image. Until then `docker compose build` (the compose's build: stanza) is the working path. Correctness lens: don't consider the pull on-ramp done until a real release proves it.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    // -- image build is slow/fragile under emulation (Sprint 55) --------------
    part issContainerBuildSlow : Issue {
        :>> id = "73e81c1d-0c12-41c8-89e0-b365fb5e3394";
        :>> title = "Container image build takes ~40 min because arm64 compiles from source under QEMU";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "The first docker-publish job used a single runner with docker/setup-qemu-action and `platforms: linux/arm64,linux/amd64`, so the arm64 image compiled the Rust binary (bollard/tokio/ring) under EMULATION — ~40 min wall-clock for v0.1.4, and emulated builds are flaky. Fix: build each arch NATIVELY on its own runner (ubuntu-24.04-arm for arm64, ubuntu-latest for amd64), push each by digest, and merge into one multi-arch tag with `docker buildx imagetools create`. No QEMU; per-arch build drops to a couple of minutes. Local `docker compose build` keeps building from source unchanged. Velocity/reliability, not correctness — the v0.1.4 image did publish correctly, just slowly.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }

    // -- triage: resolver per issue -------------------------------------------
    action fixInstallScript;
    action fixInstallLinuxPkg;
    action fixInstallMacosBrew;
    action fixInstallWindows;
    action decideContainerImage;
    action fixReleaseArchGaps;
    action fixContainerCiPublish;
    action fixContainerBuildSlow;

    #Resolves dependency from fixInstallScript to issInstallScript;
    #Resolves dependency from fixInstallLinuxPkg to issInstallLinuxPkg;
    #Resolves dependency from fixInstallMacosBrew to issInstallMacosBrew;
    #Resolves dependency from fixInstallWindows to issInstallWindows;
    #Resolves dependency from decideContainerImage to issContainerImage;
    #Resolves dependency from fixReleaseArchGaps to issReleaseArchGaps;
    #Resolves dependency from fixContainerCiPublish to issContainerCiPublish;
    #Resolves dependency from fixContainerBuildSlow to issContainerBuildSlow;
}
