// =====================================================================
// YardDog — Sprint 41 delivery: self-update apply + release pipeline.
// =====================================================================
package Sprint41SelfUpdate {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storySelfUpdate : Story {
        :>> id = "680581a8-66c3-42b7-8c4f-69120a855933";
        :>> title = "yd self-update --apply: download, verify (SHA256), atomic replace; + release workflow";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storySelfUpdate to needSelfUpdate;

    action selfUpdateApply;
    verification selfUpdateApplyDoD : Test { :>> id = "1f7e8862-79d1-4eca-bef4-51b1f2234239"; :>> method = VerificationMethod::test; :>> procedureText = "Unit-tested: parse_latest_release extracts version + assets from the GitHub API JSON; parse_sha256sums + verify_sha256 validate a known digest (case-insensitive, tamper-detecting); apply_update replaces a target file in place and keeps the old bytes as a .old backup. perform_update ties resolve->download->verify->apply with a ChecksumMismatch refusal path."; }
    part selfUpdateApplyDoDR1 : TestResult { :>> id = "4e3a0410-fbea-4048-ad23-cf0d28584ad7"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "5201bd1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action releaseWorkflow;
    verification releaseWorkflowDoD : Test { :>> id = "5e8ab76c-7d74-4265-8743-61a7e1203105"; :>> method = VerificationMethod::inspect; :>> procedureText = ".github/workflows/release.yml builds native yd binaries on tag push (linux/windows/macos x86_64 + macos arm64), names each asset to match selfupdate::platform_asset_name(), generates SHA256SUMS, and publishes a GitHub Release with the binaries + checksums (softprops/action-gh-release, contents: write)."; }
    part releaseWorkflowDoDR1 : TestResult { :>> id = "0472090f-c0fc-425e-8971-053f4fa638e7"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "5201bd1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    action selfUpdateLive;
    verification selfUpdateLiveDoD : Test { :>> id = "69d30564-1ad5-4565-9da4-e44caaa2e799"; :>> method = VerificationMethod::demo; :>> procedureText = "Against the real published release: `yd self-update` reports status via the live GitHub API; the platform asset + SHA256SUMS download and the asset verifies against its published digest; an older binary running `yd self-update --apply` installs the newer version in place (backup kept). Recorded after v0.1.0 is published by the release workflow."; }

    part selfUpdateLiveDoDR1 : TestResult { :>> id = "5b3e9f1e-e15f-4f08-bd25-5e95bcee99e2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "8a70486"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification refineGate41 : Test { :>> id = "809ecdbc-a1db-4a9c-b1d7-f3e8a926881f"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edge set; decPublishReleases accepted (supersedes decDeferSelfUpdate); scope per human = GitHub Releases + SHA256 verify (no crates.io); SR srSelfUpdateApply satisfies needSelfUpdate; apply path unit-tested, workflow authored, live demo pending publish."; }
    part refineGate41R1 : TestResult { :>> id = "5b0b91b6-e761-4892-8468-8f583ad291d5"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "5201bd1"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate41 : Test { :>> id = "1466dc6f-5ba4-49b8-8c34-2b71e0fc5382"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green. The release workflow published v0.1.0 and v0.1.1 (linux/windows x86_64 + macOS arm64 binaries + SHA256SUMS; macOS Intel trimmed after its runner queued unreliably). Live end-to-end proof: a stashed 0.1.0 binary ran `self-update` (=> 'update available -> v0.1.1'), then `--apply` downloaded the 0.1.1 windows asset, verified it against the published SHA256SUMS, atomically replaced itself (backup kept), and afterward reported 'yd 0.1.1: up to date'. Detection also verified against the live GitHub API."; }
    part reviewGate41R1 : TestResult { :>> id = "92b27060-97f2-4977-bf2b-bfa5c6d73d3d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "8a70486"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate41 : Test { :>> id = "5939ae42-404d-4603-8008-fe29203a679d"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srSelfUpdateApply verified; needSelfUpdate now covered end to end (detection + verified atomic apply). The last deferred seam is closed — publishing GitHub Releases made self-update real, exactly as the operator anticipated."; }
    part closeOutGate41R1 : TestResult { :>> id = "36489df0-3a69-4e0a-af30-fa8a1b3d43fe"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "8a70486"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
