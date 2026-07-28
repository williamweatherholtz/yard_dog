// =====================================================================
// YardDog — 5-iteration correctness campaign, ITERATION 4 findings. Three parallel
// hostile critiques: a regression pass on iteration-3, a PTY/pin/self-update/
// packaging sweep, and an end-to-end backup→verify→restore lifecycle review. Eight
// resolved in Sprint 66; two genuinely-low items filed OPEN (risk-to-fix / moot).
// =====================================================================
package YardDogCampaignIt4 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    part issSecretDetectionRegression : Issue {
        :>> id = "c39bd19b-4dd4-45b4-aed5-86358a0442d2";
        :>> title = "Iteration-3 secret-detection fix over-corrected: letter-led modular-crypt hashes evaded plaintext-secret";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med (regression the battery caught): iteration-3's looks_interpolated fix dropped the constraint that the whole post-`$` tail be name-chars, so ANY `$<letter>...` read as interpolation — a literal `$apr1$...`/`$argon2id$...`/`$y$...` password hash (exactly what gets pasted into *_PASSWORD) silently evaded. Fixed: a variable reference has NO second `$` (an MCF hash does), so `$PREFIX-suffix` still passes while all MCF hashes flag; new test covers the hashes + the partial reference.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issPermissionsCwd : Issue {
        :>> id = "0dead890-d943-46b3-b6d8-b26f135ac99d";
        :>> title = "/api/permissions probed relative binds against the server CWD (inconsistent with iteration-3's fix)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med: iteration-3 resolved relative binds against the stack dir in the CLI analyzer and mounts_json, but permissions_json still passed raw sources to build_report — so a `./data` bind was stat'd against the web server's CWD, computing ownership findings on the wrong (usually nonexistent) path and disagreeing with the mounts panel. Fixed: permissions_json now applies resolve_bind_sources like mounts_json.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issDriftAsymmetricDigest : Issue {
        :>> id = "6067663f-eb14-4a1b-8b77-bb9ce92de727";
        :>> title = "normalize_image gave false drift on an asymmetric digest (declared tag vs running tag@digest)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med: the iteration-1/2 normalize dropped the tag when a digest was present, so a declared `nginx:1.27` vs a running `nginx:1.27@sha256:...` (the resolved digest compose reports) never matched → false ImageChanged drift. Replaced the string-normalize comparison with a structured images_match((repo,tag,digest)): digests win when BOTH carry one (a same-tag re-push is real drift), else compare tags, else (one tag-only, one digest-only) can't prove drift so match. New test covers all cases.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issFleetBackupSilentFailure : Issue {
        :>> id = "e1a3ad51-f8e5-49a7-842d-2c552171bee6";
        :>> title = "`yd fleet backup` reported success while stacks failed; relative paths misresolved after the first stack";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med: the fleet-backup loop swallowed each stack's Err and returned Ok → exit 0, so a CI/cron fleet backup with failing stacks looked successful. Also run_backup's set_current_dir polluted the CWD so a later stack's relative compose path canonicalized against a previous stack's dir. Fixed: canonicalize every compose path UP FRONT (before any chdir) and count failures, returning a non-zero error when any stack fails.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issRestoreCoverageGap : Issue {
        :>> id = "b52fd323-bb49-4e6e-8ee0-9863754576dd";
        :>> title = "The data-loss-critical restore round-trip had NO runnable coverage (the one e2e test was stale + never called restore)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med (correctness verified, coverage absent): the lifecycle critique confirmed the backup→restore code is sound (manifest keys relative; subdir mapping symmetric; verify fail-closed) but the only restore test (e2e_docker) was #[ignore]d, asserted the pre-collision-hash path `bak/data/photo.jpg` (now `data-<hash>/`), and never invoked `yd restore`. Fixed: added a RUNNABLE (no-Docker) cli test that backs up a bind, corrupts the live data, restores, and asserts recovery; and de-staled the Docker e2e test to use the `data-<hash>` subdir + a real restore round-trip.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issCliExitCodeConsistency : Issue {
        :>> id = "4d6dd50d-4b7e-4b40-a8cc-1338b1be04c1";
        :>> title = "restore manifest-refusal and drift-detected didn't use the documented exit-code scheme";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low: a restore refused for a missing/unparseable manifest returned generic exit 1 (while a failed verification was 3); `yd drift` always exited 0 so CI couldn't gate on drift. Fixed: a manifest-refusal now exits 3 (same class as verify-fail); `yd drift` exits 3 when drift is detected (0 when in sync / running state unavailable); README exit-code table updated to cover both.";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }
    part issPinValidationAtomic : Issue {
        :>> id = "9f7fde81-8083-4621-b7a0-321a0fe92e47";
        :>> title = "`yd pin` didn't validate service names and wrote the pins file non-atomically";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low: write_pin persisted any string verbatim (a newline split read_pins into phantom pins) and did a read-modify-write with no atomicity (concurrent pins clobber). Fixed: is_valid_service_name gate + temp-then-rename atomic write.";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }
    part issWinUpdateTmpCleanup : Issue {
        :>> id = "68b06656-4ca0-4822-8cea-594b1b2a8c10";
        :>> title = "Windows self-update left .yd-update.tmp on a move-aside failure";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low: the Windows apply_update branch returned Err on a failed move-aside without removing the already-downloaded tmp (the Unix branch cleaned up). The running binary was always left intact; this only fixes the leftover. Fixed: remove the tmp on both Windows failure paths.";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }

    action fixSecretDetectionRegression; action fixPermissionsCwd; action fixDriftAsymmetricDigest;
    action fixFleetBackupSilentFailure; action fixRestoreCoverageGap; action fixCliExitCodeConsistency;
    action fixPinValidationAtomic; action fixWinUpdateTmpCleanup;
    #Resolves dependency from fixSecretDetectionRegression to issSecretDetectionRegression;
    #Resolves dependency from fixPermissionsCwd to issPermissionsCwd;
    #Resolves dependency from fixDriftAsymmetricDigest to issDriftAsymmetricDigest;
    #Resolves dependency from fixFleetBackupSilentFailure to issFleetBackupSilentFailure;
    #Resolves dependency from fixRestoreCoverageGap to issRestoreCoverageGap;
    #Resolves dependency from fixCliExitCodeConsistency to issCliExitCodeConsistency;
    #Resolves dependency from fixPinValidationAtomic to issPinValidationAtomic;
    #Resolves dependency from fixWinUpdateTmpCleanup to issWinUpdateTmpCleanup;

    // ---- filed OPEN (genuinely low; fixing now would add more risk than value) --

    part issTermReapOnEof : Issue {
        :>> id = "0cf7f822-21e5-4ae7-8954-f37da69528ae";
        :>> title = "A PTY session whose shell exits on its own isn't reaped until the idle sweep";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low (self-healing): on child EOF the reader thread sets alive=false but doesn't reap the child; the slot + zombie linger until /api/term/close or the 300s idle sweep. Bounded and self-healing, not a leak-forever. A direct reap-on-EOF risks racing close()/read() for the child handle, so it is deferred rather than rushed — the safe fix is to have the idle sweeper also collect !alive sessions promptly.";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }
    part issContainerNonRoot : Issue {
        :>> id = "fee598d9-39b8-4ed9-b4c7-7d0909219345";
        :>> title = "Control-plane container runs as root with no cap_drop (defense-in-depth)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Low: the runtime image has no USER and compose has no cap_drop/security_opt. Largely moot because the image mounts the Docker socket (host-root-equivalent, and loudly flagged) — dropping in-container privilege doesn't change the trust boundary. Filed for a defense-in-depth pass; no secret is baked into the image.";
        :>> discoveredInField = true;
        :>> severity = Severity::Low;
    }

    action fixTermReapOnEof; action fixContainerNonRoot;
    #Resolves dependency from fixTermReapOnEof to issTermReapOnEof;
    #Resolves dependency from fixContainerNonRoot to issContainerNonRoot;
}
