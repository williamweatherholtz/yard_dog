// =====================================================================
// YardDog — Sprint 51 delivery: macOS Homebrew + Windows Scoop manifests.
// Resolves issInstallMacosBrew and issInstallWindows.
// =====================================================================
package Sprint51PkgManagers {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyPkgManagers : Story {
        :>> id = "92e02987-0f6f-4df7-8c21-65ff0d2d4451";
        :>> title = "Homebrew formula (macOS arm64) + Scoop manifest (Windows)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p2;
        :>> owner = "ai";
        :>> estimatedPoints = 2;
    }

    #CharteredBy dependency from storyPkgManagers to needSimplicity;

    // resolver DoDs (actions fixInstallMacosBrew / fixInstallWindows in issues-installation.sysml)
    verification fixInstallMacosBrewDoD : Test { :>> id = "d5c538c1-c9c0-4d46-96d3-5a67298766a1"; :>> method = VerificationMethod::inspect; :>> procedureText = "packaging/homebrew/yd.rb is a valid Homebrew formula for Apple Silicon: version 0.1.3, on_arm url pointing at the v0.1.3 yd-aarch64-macos release asset, sha256 matching the published SHA256SUMS (609cbc63...), installs the binary as `yd`, with a `yd --help` test. Verified: sha matches the release and the asset URL returns HTTP 200. Installable via `brew install <raw-url>`. macOS Intel pending (issReleaseArchGaps)."; }
    part fixInstallMacosBrewDoDR1 : TestResult { :>> id = "7d8cf025-b12c-48a9-98a5-beac97e6d42a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1527a57"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixInstallWindowsDoD : Test { :>> id = "75ddc6c9-dbe4-495f-bfe4-6f2eca9ed61e"; :>> method = VerificationMethod::inspect; :>> procedureText = "packaging/scoop/yd.json is a valid Scoop manifest: version 0.1.3, 64bit url pointing at the v0.1.3 yd-x86_64-windows.exe asset (renamed to yd.exe via #/yd.exe), hash matching the published SHA256SUMS (9c05ec46...), bin yd.exe, plus checkver/autoupdate for future releases. Verified: valid JSON, sha matches the release, the asset URL returns HTTP 200. Installable via `scoop install <raw-url>`."; }
    part fixInstallWindowsDoDR1 : TestResult { :>> id = "fc5a0d04-c60d-4c6a-a6d3-d327854add88"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1527a57"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate51 : Test { :>> id = "d7208862-0aad-4cac-9d42-1382de261a0b"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (2); charter edge set; two backlog install issues (issInstallMacosBrew, issInstallWindows) pulled from whats-next; both are static manifests over the existing checksummed release assets (no new binaries needed)."; }
    part refineGate51R1 : TestResult { :>> id = "32d87563-fce9-40a2-ae7e-b3f07bf20a26"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1527a57"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate51 : Test { :>> id = "8e915111-90b1-443e-b092-9c8869e2cd2c"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery: (correctness) both manifests' sha256 hashes cross-checked against the published SHA256SUMS and the asset URLs return 200 — a wrong hash would break install; (security) install pulls the checksummed release asset, same trust model as the installer/self-update; (docs) README adds brew + scoop one-liners; (concision) reuses existing release assets, no new build. Known limitation (logged, not silent): the manifests pin v0.1.3 and must be bumped per release (scoop autoupdate helps bucket maintainers; a CI auto-bump is a follow-up); macOS Intel formula pending with the Intel asset."; }
    part reviewGate51R1 : TestResult { :>> id = "485d9cdb-8b5d-4092-9b64-e5d10f4227a3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1527a57"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate51 : Test { :>> id = "f5569071-c9e3-4144-a660-4e6bba335739"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issInstallMacosBrew + issInstallWindows resolved. Yard Dog installs via Homebrew (macOS arm64) and Scoop (Windows) in addition to the install script, Linux .deb/.rpm, and self-update. One backlog item remains: the container-image decision (issContainerImage), routed as a Decision for human sign-off."; }
    part closeOutGate51R1 : TestResult { :>> id = "bc4cb6cd-8f1e-423b-b4b1-c3b3751053ef"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "1527a57"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
