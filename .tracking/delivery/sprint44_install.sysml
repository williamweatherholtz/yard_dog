// =====================================================================
// YardDog — Sprint 44 delivery: install story (script + per-arch matrix).
// Resolves issInstallScript and issReleaseArchGaps (aarch64-linux added;
// macOS Intel deferred for runner reliability).
// =====================================================================
package Sprint44Install {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyInstall : Story {
        :>> id = "9a152229-2584-48c7-aeeb-bcd8dfa01a0f";
        :>> title = "Install scripts (sh + PowerShell) + aarch64-linux in the release matrix";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 3;
    }

    #CharteredBy dependency from storyInstall to needSimplicity;

    // resolver DoDs for the triaged install issues (actions declared in
    // issues-installation.sysml; keel pairs action X with verification XDoD).
    verification fixInstallScriptDoD : Test { :>> id = "ea1ecf7d-2fad-4acb-abc7-a255605d9db1"; :>> method = VerificationMethod::demo; :>> procedureText = "install.sh / install.ps1 detect OS+arch, resolve the latest release, download the matching asset + SHA256SUMS, verify the SHA256, and install to PATH. Verified live on Windows: install.ps1 downloaded yd-x86_64-windows.exe for v0.1.2, reported 'checksum OK', installed to %LOCALAPPDATA%\\Programs\\yd, added it to PATH, and the installed binary reported 'yd 0.1.2: up to date'."; }
    part fixInstallScriptDoDR1 : TestResult { :>> id = "b847c757-534c-46e6-a91a-285e85b2128e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "efb8185"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification fixReleaseArchGapsDoD : Test { :>> id = "44e6aa89-638e-4a0c-a105-2e9e61119b53"; :>> method = VerificationMethod::demo; :>> procedureText = "The release matrix now builds aarch64-linux (ubuntu-24.04-arm) for Raspberry Pi / ARM homelab hosts. Verified: the v0.1.2 GitHub release publishes yd-aarch64-linux alongside yd-x86_64-linux, yd-aarch64-macos, yd-x86_64-windows.exe, and SHA256SUMS. macOS Intel (x86_64-apple-darwin) is deferred — GitHub's Intel-mac runners queue unreliably and blocked the release twice; Apple Silicon is covered."; }
    part fixReleaseArchGapsDoDR1 : TestResult { :>> id = "b571f7f3-1fc4-4d0d-893b-e1d467851fb2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "efb8185"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate44 : Test { :>> id = "0209274b-5c73-44d3-b84e-259cc9897794"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (3); scope per human (proceed with b) = a checksum-verifying install script + completing the per-arch matrix (aarch64-linux) first; other packaging (deb/rpm, brew, scoop/winget, container) remain open roadmap issues."; }
    part refineGate44R1 : TestResult { :>> id = "f02307e4-5e51-4cd0-accd-16cf5b878b07"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "efb8185"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate44 : Test { :>> id = "65777cd6-9e83-4942-aa3b-cddc7548d439"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: install.sh/install.ps1 reuse the self-update asset+SHA256 scheme; both refuse to install on a checksum mismatch. README documents the one-liners + the host-binary rationale. Release matrix covers linux x86_64/aarch64, macOS arm64, windows x86_64. v0.1.2 published and the Windows installer verified live end to end. Remaining install issues (deb/rpm+systemd, brew, scoop/winget, container-image decision) are open roadmap."; }
    part reviewGate44R1 : TestResult { :>> id = "d82f0233-c2de-4f92-a237-0bad663f5d93"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "efb8185"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate44 : Test { :>> id = "df957bfe-39dc-4dde-82a4-34437e9c204d"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: issInstallScript + issReleaseArchGaps resolved. Yard Dog now installs with a verified one-liner on Linux (x86_64+aarch64), macOS (arm64), and Windows (x86_64), and stays current via self-update. Native packages (deb/rpm/brew/scoop/winget) + the container-image decision remain as recorded roadmap issues."; }
    part closeOutGate44R1 : TestResult { :>> id = "62715b5f-39ec-47e5-8be4-de30b02bea81"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "efb8185"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
