// =====================================================================
// YardDog — Sprint 49 delivery: native Linux packages (.deb + .rpm, arm64-first).
// Resolves issInstallLinuxPkg.
// =====================================================================
package Sprint49LinuxPkg {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyLinuxPkg : Story {
        :>> id = "a4d1e946-4ca3-445c-8aa3-1b710e0a729e";
        :>> title = "Native Linux packages: .deb + .rpm for arm64 + amd64, with a systemd unit";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyLinuxPkg to needSimplicity;

    // resolver for issInstallLinuxPkg (action fixInstallLinuxPkg in issues-installation.sysml)
    verification fixInstallLinuxPkgDoD : Test { :>> id = "551d8d06-2c87-4e5d-b0d0-7cee7c52e8c1"; :>> method = VerificationMethod::demo; :>> procedureText = "packaging/nfpm.yaml builds .deb + .rpm from a prebuilt yd binary (one config, both formats); a CI `package` job runs nfpm for amd64 + arm64 and attaches them to the release. Each package installs /usr/bin/yd + a DISABLED yd.service (loopback, reads /etc/yard-dog/yd.env for YD_ROOT/YD_PORT) + docs. Verified: v0.1.3 publishes yard-dog_0.1.3_{arm64,amd64}.deb and yard-dog-0.1.3-1.{aarch64,x86_64}.rpm; the arm64 .deb installs and RUNS in an emulated arm64 container (`yd doctor` executes, blocks a floating tag, exit 3; service + env files present)."; }
    part fixInstallLinuxPkgDoDR1 : TestResult { :>> id = "0a5a803d-0790-4a72-a6df-c286e49abbf4"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a31a9c7"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate49 : Test { :>> id = "75e4cf41-6d88-414a-9752-3ee3c1d05dde"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); charter edge set; scope per human (Linux arm64 first) = .deb/.rpm via nfpm (one config, both formats), arm64 + amd64, with a disabled loopback systemd unit; ship as release assets (hosted apt/dnf repo is a later follow-up)."; }
    part refineGate49R1 : TestResult { :>> id = "e08c0480-489a-4d66-8d9a-65aba5931a85"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a31a9c7"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate49 : Test { :>> id = "bca85734-c4dc-4525-8bd5-17e191bb3804"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: nfpm chosen over cargo-deb+cargo-generate-rpm (one config, both formats, trivial cross-arch). The systemd unit is installed disabled (needSecureByDefault: no service the operator didn't start) and binds loopback via yd. Locally verified via docker+nfpm (deb layout + arm64 metadata) AND live in CI (v0.1.3 assets) AND by installing+running the arm64 .deb in an emulated arm64 container. README documents apt/dnf install + the service. Native binaries + install script remain for macOS/Windows package managers (open roadmap)."; }
    part reviewGate49R1 : TestResult { :>> id = "969f5148-b9fa-4927-9276-3a5196980d47"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a31a9c7"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate49 : Test { :>> id = "d04405be-2740-4ff2-94d9-12afd819b1ed"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issInstallLinuxPkg resolved. Yard Dog now installs on Linux via .deb/.rpm for arm64 (Raspberry Pi first) and amd64, with an optional loopback service. Remaining install roadmap: Homebrew, Scoop/winget, and the container-image decision."; }
    part closeOutGate49R1 : TestResult { :>> id = "648b4a80-dc70-4a0d-be4c-db806d5f39eb"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "a31a9c7"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
