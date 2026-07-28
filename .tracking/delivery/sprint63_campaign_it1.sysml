// =====================================================================
// YardDog — Sprint 63 delivery: iteration 1 of the 5-iteration correctness
// campaign. Implements ALL findings (every severity) from the five iteration-1
// hostile critiques.
// =====================================================================
package Sprint63CampaignIt1 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyCampaignIt1 : Story {
        :>> id = "1e4dfe56-850d-4cba-93a6-65274cee7956";
        :>> title = "Campaign iteration 1: implement all findings (guardrail/lifecycle/parse/supply-chain/gitver)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 13;
    }

    #CharteredBy dependency from storyCampaignIt1 to needSecureByDefault;

    verification fixGuardrailOverblockDoD : Test { :>> id = "a3bdb26b-3ccb-40fd-b5b1-9f547c2a3ba0"; :>> method = VerificationMethod::demo; :>> procedureText = "Guardrail volume/device logic is :ro-aware with safe allowlists: writable host-system binds + raw memory/disk devices Block; read-only system binds Warn; ubiquitous safe leaves (/etc/localtime, /sys/fs/cgroup:ro, /dev/dri, /dev/ttyUSB0) deploy. New test common_safe_host_mounts_and_devices_do_not_block + updated evasion test; 8 guardrail tests green."; }
    part fixGuardrailOverblockDoDR1 : TestResult { :>> id = "6627d2a3-9ea5-44f4-9421-b2d1f08c8198"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b91460"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixLifecycleAdoptSafetyDoD : Test { :>> id = "9cc41e56-c67d-4934-9571-887ac5e63507"; :>> method = VerificationMethod::demo; :>> procedureText = "Lifecycle state writes atomically (temp+rename) so a truncated file can't bypass the archived gate; import/new validate --name is a single path segment (no traversal/overwrite); import carries override composes + env_file companions. Full suite green."; }
    part fixLifecycleAdoptSafetyDoDR1 : TestResult { :>> id = "efbc630f-9d0a-4224-8aa7-2930c7451ae6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b91460"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixParseRobustnessDoD : Test { :>> id = "f0f81d7c-7d21-4b80-b00f-a9189cddd6d6"; :>> method = VerificationMethod::demo; :>> procedureText = "compose::yaml_guard (2 MiB size + depth-100 nesting cap) runs before every serde_yaml parse (guardrails returns a Block for pathological input) — a crafted compose can no longer stack-overflow/OOM the server or CLI. The request body is capped at 8 MiB. Drift normalizes image refs (registry prefix + implicit :latest) and parses pretty-printed single-object `ps`. 133 lib tests green."; }
    part fixParseRobustnessDoDR1 : TestResult { :>> id = "eea20d56-574d-4804-a843-1d625d8333e2"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b91460"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixSupplyChainHardeningDoD : Test { :>> id = "8bb805ce-fab7-4e71-8dd6-6560636c9d4e"; :>> method = VerificationMethod::demo; :>> procedureText = "registry: SSRF guard (reject loopback/private/link-local hosts) + connect/read timeouts. selfupdate: prerelease-aware ordering (test), atomic in-place Unix swap, download timeout + 512 MiB cap. Release authenticity: ed25519 signature verification of SHA256SUMS.sig against an embedded pubkey (verify_ed25519 test: accepts valid, rejects tampered/empty), a hidden `sign-release` CLI, and a CI signing step gated on the YD_SIGNING_KEY secret. Verification enforced only once the operator provisions the key (pubkey const empty ⇒ checksum-only + a printed note). 7 selfupdate tests green."; }
    part fixSupplyChainHardeningDoDR1 : TestResult { :>> id = "cff9342b-7638-4bfe-af10-272ebb61bcbc"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b91460"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification fixGitverCorrectnessDoD : Test { :>> id = "c8063e9e-2af3-4e54-b7f8-f3c2568e0425"; :>> method = VerificationMethod::demo; :>> procedureText = "gitver: adopt of an existing repo installs the data/secret ignore block (marked, non-clobbering); restore tolerates a stack absent at the target sha; ls-files/rm are NUL-safe; commit.gpgsign=false + core.hooksPath= so host config can't block the bot; :(literal) pathspecs; fetch failures surfaced (not silent in-sync); sha-slice made char-safe. Concurrency re-scoped: a cross-process gitver index file-lock serializes the shared monorepo index while per-stack web locks let different stacks run concurrently (10/10 concurrent saves already proven; different-stack mutations no longer wedge behind one deploy). 9 gitver tests green."; }
    part fixGitverCorrectnessDoDR1 : TestResult { :>> id = "40aa9824-8b0b-4f12-a472-801f208674b6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b91460"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification refineGate63 : Test { :>> id = "a89f485c-0472-4584-978b-62bedae4b395"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points (13); charter to needSecureByDefault. Iteration 1 of the operator's 5-iteration campaign: five hostile critiques over fresh + safety-critical surface. Per the operator's direction, this iteration implements ALL findings (every severity) before iteration 2 begins."; }
    part refineGate63R1 : TestResult { :>> id = "0f6c2465-f159-47ec-806a-3bb54c2bb3f6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b91460"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification reviewGate63 : Test { :>> id = "9500dbaf-4efa-4a78-b7f2-94b83d5009d7"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI critique battery. (correctness) the campaign is self-correcting — the regression critique caught a battery-2 SHIP-BLOCKER (guardrail over-block of /etc/localtime, /dev/dri, cAdvisor) which is fixed with a test; the YAML bomb (whole-process SIGABRT) that defeated the panic-isolation guarantee is closed. (security) SSRF, unsigned-update authenticity (verification implemented, key provisioning handed to the operator), path traversal via --name, and the adopt-repo secret-leak are all closed. (honesty) the reviewers verified large tracts as sound (lifecycle FSM totality, drift panic-freedom, self-update verify-before-swap, --ff-only pull). One item legitimately needs an operator action (provisioning the signing key) — flagged explicitly, not silently. (concision) shared helpers (is_plain_name, yaml_guard, host_is_public, split_z, acquire_index_lock) avoid duplication. 155 Rust + 28 Playwright tests green; no warnings."; }
    part reviewGate63R1 : TestResult { :>> id = "02c9136e-e969-464f-9a3e-86068b048b07"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b91460"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }

    verification closeOutGate63 : Test { :>> id = "b2e6a942-0597-4664-9207-50a49d68cb44"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: all five iteration-1 issues resolved (guardrail over-block, lifecycle/adopt safety, parse robustness, supply-chain hardening, gitver correctness + lock re-scope). cargo build clean (no warnings); 155 Rust + 28 Playwright tests green; keel validate + guard green. Iteration 1 complete — iteration 2 may begin. Operator follow-up: provision the release signing key to activate signature enforcement."; }
    part closeOutGate63R1 : TestResult { :>> id = "8fb20965-0c68-4eb7-92d9-dd5bee83586d"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "4b91460"; :>> judgedAt = "2026-07-28"; :>> judgedBy = "ai"; }
}
