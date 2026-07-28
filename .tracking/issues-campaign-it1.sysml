// =====================================================================
// YardDog — 5-iteration correctness campaign, ITERATION 1 findings (five parallel
// hostile critiques over lifecycle/drift/adopt, gitver, self-update supply chain,
// a whole-crate panic sweep, and a regression pass on battery-2). All fixed in the
// iteration-1 remediation.
// =====================================================================
package YardDogCampaignIt1 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    part issGuardrailOverblock : Issue {
        :>> id = "60c7c969-dde4-4ad9-90f9-36a2cbf57933";
        :>> title = "Guardrail sensitive-path/device Block refused legitimate common stacks (battery-2 over-correction)";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Ship-blocker: battery-2's hard Block on sensitive host binds + all devices refused ubiquitous safe patterns — /etc/localtime:ro, /sys/fs/cgroup:ro (cAdvisor/node-exporter), /dev/dri (Plex/Jellyfin transcode), /dev/ttyUSB0 (Home Assistant/Zigbee). Fixed: host binds are :ro-aware (read-only system binds Warn, a safe-leaf allowlist is silent, only writable system binds Block); devices Block only for raw memory/disk (/dev/mem, /dev/sd*, …) and Warn otherwise. New test asserts common safe patterns deploy.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issLifecycleAdoptSafety : Issue {
        :>> id = "56f22144-58b8-4d92-9566-37e30c27c4e9";
        :>> title = "Lifecycle state non-atomic (archived-gate bypass); import/new --name path traversal; import drops companions";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med: a truncated .yd-lifecycle file silently degraded Archived→Draft, bypassing the deploy-gate — fixed with an atomic temp+rename write. `yd import/new --name ../x` escaped the stacks root and clobbered other stacks — fixed by validating the name is a single path segment. Import silently dropped override composes + env_file targets — now carried.";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issParseRobustness : Issue {
        :>> id = "70abb416-19cf-43ad-97ff-2dc8525cf83d";
        :>> title = "Crafted YAML crashes the whole process (stack overflow/OOM); unbounded body; drift false-positives";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "High: serde_yaml recurses with no depth limit → a small flow-style `[[[…]]]` bomb SIGABRTs the entire server (defeating per-request panic isolation) or the CLI; alias bombs OOM. Fixed with yaml_guard (size + nesting-depth cap) at every parse entry (run_guardrails returns a Block). The request body was read unbounded (OOM / unbounded /api/save write) → now capped at 8 MiB. Drift compared raw image strings → false drift on registry-prefix/implicit-latest and missed pretty-printed `ps` output; now normalized + robust.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }
    part issSupplyChainHardening : Issue {
        :>> id = "ef6d8ac8-9c82-4279-a6af-0e6c387a33c9";
        :>> title = "Registry SSRF + no timeouts; self-update: no signature, non-atomic swap, semver, unbounded download";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "Med: /api/updates dialed the registry host from an image string (SSRF to 169.254.169.254 / localhost) → fixed with a loopback/private/link-local block; no HTTP timeouts → hung threads, fixed. self-update: prerelease-blind version ordering (fixed); Unix swap moved the exe aside leaving a no-binary window (fixed to an atomic in-place rename); unbounded download read (capped + timeout). Authenticity: SHA256SUMS was unsigned + co-located (integrity, not authenticity) — implemented ed25519 SIGNATURE VERIFICATION (verify SHA256SUMS.sig against an embedded pubkey; refuse if configured-and-invalid) + a `sign-release` CLI + a CI signing step. OPERATOR ACTION REQUIRED to activate: generate a keypair, put the private key in the CI secret YD_SIGNING_KEY, and paste the public key into selfupdate::RELEASE_PUBKEY_HEX; until then releases are checksum-only (a printed note says so).";
        :>> discoveredInField = true;
        :>> severity = Severity::Medium;
    }
    part issGitverCorrectness : Issue {
        :>> id = "9cd765e7-44d1-468a-8429-4cdddf3e6c37";
        :>> title = "gitver: ignore skipped on adopt; restore edge failures; NUL/quote/glob pathspec bugs; commit-blockers; coarse lock";
        :>> createdAt = "2026-07-28";
        :>> createdBy = "wweatherholtz";
        :>> description = "High cluster: ensure_repo skipped the data/secret .gitignore on an ADOPTED existing repo (would commit secrets) — now installs a marked block idempotently without clobbering the operator's. restore_scoped errored when a stack didn't exist at the target sha (added/renamed) — now tolerated. ls-files/rm quote-mangled non-ASCII filenames — now NUL-safe (-z). A host gpgsign/pre-commit-hook could block the bot's commits — now neutralized (commit.gpgsign=false, core.hooksPath=). Glob-active pathspecs could mis-scope stacks with `*?[]` — now :(literal). ahead_behind swallowed fetch failures as in-sync — now surfaced. sha[..12] slice could panic — now char-safe. The thread-per-request global mutation lock wedged all stacks behind one deploy — re-scoped to per-stack web locks + a cross-process gitver index file-lock so different stacks run concurrently.";
        :>> discoveredInField = true;
        :>> severity = Severity::High;
    }

    action fixGuardrailOverblock; action fixLifecycleAdoptSafety; action fixParseRobustness;
    action fixSupplyChainHardening; action fixGitverCorrectness;
    #Resolves dependency from fixGuardrailOverblock to issGuardrailOverblock;
    #Resolves dependency from fixLifecycleAdoptSafety to issLifecycleAdoptSafety;
    #Resolves dependency from fixParseRobustness to issParseRobustness;
    #Resolves dependency from fixSupplyChainHardening to issSupplyChainHardening;
    #Resolves dependency from fixGitverCorrectness to issGitverCorrectness;
}
