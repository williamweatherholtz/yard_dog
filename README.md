# Yard Dog (`yd`)

A single-host Docker Compose manager that treats **correctness as the product**.
Where other compose UIs (Portainer, Dockge) stop at "start/stop the stack", Yard Dog
adds the two things that actually bite operators:

1. **Mount-path intelligence** — it knows whether a compose mount is a host bind, a
   named volume, an anonymous volume, or a network path, and whether the path
   actually exists — so it never silently creates a directory where you meant a file,
   and it can *propose the fix* instead of just warning.
2. **Application-consistent backup** — database-respecting dumps plus file copies,
   captured into a verifiable manifest, before anything changes.

Everything destructive is wrapped in the same safety model: **back up → version in git
→ apply → health-gate → roll back on failure (config *and* running stack).**

---

## The safety model

Every change that touches a running stack goes through one shared lifecycle FSM
(`flow.rs`), whether it is a plain deploy or an image upgrade:

```
Guardrails → Backup → Apply → Snapshot → Health → Decide → (Regress)
```

- **Guardrails** — a small, high-signal policy check runs *first*. Block-severity
  findings (a floating `:latest` tag, a plaintext secret, a **privileged** container,
  a mounted **Docker socket**, a dangerous **`cap_add`** like `SYS_ADMIN`) stop the
  change before any backup; warnings (missing healthcheck/restart/limits, host
  networking or host PID) are surfaced. An **archived** stack is also refused here — it must be explicitly
  restored (`yd lifecycle --event restore`) before a deploy or upgrade can resurrect it. Warn-severity findings (no healthcheck, no restart policy, no resource
  limits) are printed to the operator. For an upgrade, guardrails evaluate the
  **post-change** compose — the image you are actually about to deploy.
- **Backup** — a pre-change recovery point is taken. If it fails, the change aborts.
- **Snapshot** — the exact config being deployed is committed to a git repo that
  excludes data and secrets by construction.
- **Health** — the deploy waits for containers to become **healthy**
  (`docker compose up -d --wait`), not merely started. A timeout or unhealthy result
  is treated as failure.
- **Decide / Regress** — on failure (or an upgrade you don't accept), Yard Dog
  restores the last-good commit **and redeploys it**, so the *running* stack returns
  to good — not just the file on disk. If even the rollback redeploy fails, it tells
  you loudly (see exit code 4) rather than reporting a clean rollback.

Config versioning is plain **git** (`gitver`): opinionated `.gitignore`
(data/secrets never tracked), a single bot committer, history, and
restore-as-a-new-commit (never a detached/dirty tree). A restore makes the worktree
match the target commit exactly, including removing files added afterwards.

---

## Commands

Run `yd <command> --help` for full flags. Grouped by what they touch:

### Inspect & classify (read-only)
| Command | Purpose |
|---|---|
| `yd inspect <compose>` | Classify every mount (host bind / named / anonymous / network) and report existence + remediation. |
| `yd check <compose>` | Run the preventative policy guardrails over a compose file. |
| `yd doctor <compose>` | One preflight verdict (READY / NOT READY) from guardrails + lifecycle, with a matching exit code. |
| `yd serve [--root <dir>] [--port N]` | Serve the loopback-only browser control plane over the stacks under `<dir>` (default `.`, port 8770). |
| `yd classify <compose>` | Classify each service into a workload kind (datastore / web / worker / cron / proxy). |
| `yd updates <compose>` | Show image-update status (real digest check against Docker Hub / GHCR) plus the kind-gated action per service. |
| `yd drift <compose>` | Report drift between the declared compose and the running stack. |
| `yd stacks --root <dir>` | List the compose stacks discovered under a root directory. |

### Change the running stack (guarded)
| Command | Purpose |
|---|---|
| `yd fix <compose> [--yes]` | Apply remediations for detected path issues (dry-run unless `--yes`). |
| `yd deploy <compose> [--yes]` | Safe deploy: guardrails → back up → snapshot → health-gate → roll back on failure. |
| `yd upgrade <compose> --repo <dir> --service <s> --image <img> [--yes]` | Safe image upgrade: as deploy, then **regress-or-accept** on the healthcheck. |

### Backup & restore
| Command | Purpose |
|---|---|
| `yd backup <compose> [--plan] [--run --dest <dir>]` | Plan or run an application-consistent backup (DB dumps + file copies + manifest). |
| `yd verify --dest <dir>` | Verify a backup's integrity against its recorded manifest. |
| `yd push --from <dir> --to <target>` | Mirror a backup directory to a destination. |
| `yd prune --dest <dir> --keep <N>` | Prune old backup snapshots, keeping the newest N. |

### Versioning
| Command | Purpose |
|---|---|
| `yd version init --repo <dir>` | Initialise the versioning repo (opinionated `.gitignore` + attributes). |
| `yd version snapshot --repo <dir> -m <msg>` | Commit the current config as a snapshot. |
| `yd version history --repo <dir>` | List version history (newest first). |
| `yd version restore --repo <dir> --sha <sha>` | Restore a prior version by sha (as a new commit). |

### Other
| Command | Purpose |
|---|---|
| `yd new --into <dir> --name <n> --kind <k> [--service <s>]` | Instantiate a guardrail-clean starter stack for a workload kind (`datastore` / `web` / `worker` / `cron` / `proxy`), in the Draft lifecycle state. |
| `yd lifecycle --repo <dir> [--event <e>]` | Show or transition a stack's lifecycle state; `<e>` = `activate` / `deprecate` / `archive` / `restore`. |
| `yd import <compose> --into <dir> [--name <n>]` | Import an existing compose stack into a managed stacks directory. |
| `yd pin add --repo <dir> --service <s>` / `yd pin list --repo <dir>` | Pin services to hold their updates. |
| `yd notify --message <msg>` | Send a notification through the default (stdout) channel. |
| `yd self-update [--apply]` | Check for a newer release; with `--apply`, download it, verify its SHA256, and atomically replace the running binary. |

---

## Browser control plane

`yd serve` starts a **loopback-only** browser UI (a thin wrapper over the same
library and CLI) for operators who prefer a dashboard to the terminal:

```sh
cd /srv/stacks      # the directory holding your compose stacks
yd serve            # → http://127.0.0.1:8770  (loopback only)
```

The dashboard lists every stack with its lifecycle and service count; opening one
shows its services (with workload kind), guardrail findings, the READY/NOT-READY
preflight verdict, and lifecycle controls — and lets you deploy, upgrade, back up,
check drift/updates, transition lifecycle, or take the stack down. Every action
runs through the same guarded CLI path (guardrails → backup → health-gate →
rollback).

**Security model (secure by default).** The server binds `127.0.0.1` only; it
never listens on a non-loopback address. It rejects any request whose `Host`
header is not a loopback name/address (a DNS-rebinding defense for a no-auth local
server), serves mutations over `POST` only, and confines every path parameter
under the served root (no absolute paths, no `..`). Secret values are never
rendered. For remote access, front it with your own SSH tunnel or authenticated
reverse proxy rather than widening the bind.

## Exit codes

`yd deploy` / `yd upgrade` use exit codes so scripts and CI can react:

| Code | Meaning |
|---|---|
| `0` | Success (deployed / upgraded / cleanly rolled back / skipped). |
| `2` | Pre-change backup failed — nothing was applied. |
| `3` | Blocked by a guardrail (e.g. floating tag or plaintext secret). |
| `4` | **Critical:** the change failed *and* the rollback redeploy also failed — the live stack needs attention. |

---

## Building

```sh
cd app
cargo build --release   # binary: target/release/yd
cargo test              # unit + integration tests (hermetic, no Docker)

# End-to-end tests that run the real `yd` binary against a live Docker daemon,
# one per persona use case (see .tracking/personas-usecases.sysml). Opt-in:
cargo test --test e2e_docker -- --ignored --test-threads=1
```

The OS- and Docker-touching pieces sit behind traits, so the classification,
backup, guardrail, and lifecycle logic is unit-tested on any platform against
fixtures — no Docker required for the default `cargo test`. The `e2e_docker`
suite additionally proves the full journeys (deploy, rollback, upgrade, backup+
verify, guardrails, lifecycle) against a real daemon; the Docker-touching cases
skip gracefully when no daemon is reachable.

---

## Project tracking

This repository is tracked by **keel** (a SysML-based work-tracking engine): needs,
requirements, decisions, and test results live under `.tracking/`, and every
status/view is computed (`keel orient .`, `keel validate .`, `keel guard .`). See
`CLAUDE.md` for how work is authored here. The engine itself lives under `.engine/`
and is not part of this product.
