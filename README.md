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

### Inspect (read-only)
| Command | Purpose |
|---|---|
| `yd inspect <compose>` | Classify every mount (host bind / named / anonymous / network) and report existence + remediation. |
| `yd check <compose>` | Run the preventative policy guardrails over a compose file. |
| `yd doctor <compose>` | One preflight verdict (READY / NOT READY) from guardrails + lifecycle, with a matching exit code. |
| `yd serve [--root <dir>] [--port N] [--host <addr>]` | Serve the browser control plane over the stacks under `<dir>` (default `.`, port 8770). `--host` defaults to `127.0.0.1` (loopback); use `0.0.0.0` only inside a container whose port is published to the host's loopback (`127.0.0.1:`) — that loopback publish is the access boundary, since this plane has no auth. |
| `yd updates <compose>` | Show image-update status (real digest check against Docker Hub / GHCR) plus the suggested action per service (a service with a persistent data mount is notify-only, never auto-applied). |
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
| `yd restore <compose> --from <dir> [--yes]` | Restore a stack's bind data from a backup — verified first, dry-run without `--yes`. |
| `yd push --from <dir> --to <target>` | Mirror a backup directory to a destination. |
| `yd prune --dest <dir> --keep <N>` | Prune old backup snapshots, keeping the newest N. |

**Where automatic backups go.** The pre-change recovery point (and the UI's "Back up
now") default to each stack's own `.yd-backups` — *same disk as the data*. Set
**`BACKUP_ROOT`** (env for `yd serve`, or `--backup-root` on `deploy`/`upgrade`/`fleet
backup`) to store them under `<BACKUP_ROOT>/<stack-name>` instead — e.g. a mounted NAS
volume, keeping recovery points off the data's disk. Empty/unset ⇒ the local default.

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
| `yd new --into <dir> --name <n> [--service <s>]` | Instantiate a guardrail-clean starter stack (pinned image, healthcheck, restart, limit) in the Draft lifecycle state. |
| `yd lifecycle --repo <dir> [--event <e>]` | Show or transition a stack's lifecycle state; `<e>` = `activate` / `deprecate` / `archive` / `restore`. |
| `yd import <compose> --into <dir> [--name <n>]` | Import an existing compose stack into a managed stacks directory. |
| `yd pin add --repo <dir> --service <s>` / `yd pin list --repo <dir>` | Pin services to hold their updates. |
| `yd notify --message <msg>` | Send a notification through the default (stdout) channel. |
| `yd self-update [--apply]` | Check for a newer release; with `--apply`, download it, verify its SHA256, and atomically replace the running binary. |
| `yd git remote/push/pull/status --repo <dir>` | Connect and sync the config monorepo with a git remote (auth via your system git). |
| `yd fleet status/check/backup --root <dir>` | Act across every stack under a root — summary, preflight-all, or backup-all. |

---

## Install

**Linux / macOS** — downloads the right binary for your OS/arch and verifies its SHA256:
```sh
curl -fsSL https://raw.githubusercontent.com/williamweatherholtz/yard_dog/main/install.sh | sh
```
**Windows** (PowerShell):
```powershell
irm https://raw.githubusercontent.com/williamweatherholtz/yard_dog/main/install.ps1 | iex
```
**Linux packages** — `.deb` and `.rpm` for **arm64** (Raspberry Pi / ARM homelab)
and x86_64 are attached to each release:
```sh
# Debian/Ubuntu (arm64 shown; also x86_64)
sudo dpkg -i yard-dog_*_arm64.deb        # or: sudo apt install ./yard-dog_*_arm64.deb
# Fedora/RHEL
sudo rpm -i yard-dog-*.aarch64.rpm
```
The package installs `/usr/bin/yd` plus a **disabled** `yd.service`; to run the
control plane as a service, set `ROOT` in `/etc/yard-dog/yd.env` then
`sudo systemctl enable --now yd`.

**macOS (Homebrew, Apple Silicon):**
```sh
brew install https://raw.githubusercontent.com/williamweatherholtz/yard_dog/main/packaging/homebrew/yd.rb
```
**Windows (Scoop):**
```powershell
scoop install https://raw.githubusercontent.com/williamweatherholtz/yard_dog/main/packaging/scoop/yd.json
```

Prebuilt binaries (x86_64 + arm64 Linux, arm64 macOS, x86_64 Windows) and
`SHA256SUMS` are attached to each [GitHub Release](https://github.com/williamweatherholtz/yard_dog/releases).
Once installed, `yd self-update --apply` keeps it current (also SHA256-verified).

**Container (`docker compose up`)** — the frictionless on-ramp:
```sh
# packaging/docker/docker-compose.yml
ROOT=/srv/stacks PORT=8770 docker compose -f packaging/docker/docker-compose.yml up -d
# → http://127.0.0.1:8770   (change the port any time via PORT, then re-run `up -d`)
```
It **auto-runs** (`restart: unless-stopped` + an HTTP healthcheck) and the port is
yours to set. It needs the Docker socket **and** your stacks dir mounted at the same
path, because Yard Dog's path-intelligence and backup/restore read the host
filesystem — that's real host access, so the **host binary above is the
lower-exposure, full-feature path we recommend**; the container is the try-it/opt-in
option. The UI is published to your machine's **loopback only** (`127.0.0.1:`),
which is the sole access boundary for this no-auth control plane — the Host
allowlist is only a browser DNS-rebinding defense, not access control, so **don't
widen the publish to a non-loopback address** (that would expose unauthenticated
host root via the socket mount). See [`packaging/docker/`](packaging/docker/) for
the annotated, security-commented compose.

## Browser control plane

`yd serve` starts a **loopback-only** browser UI (a thin wrapper over the same
library and CLI) for operators who prefer a dashboard to the terminal:

```sh
cd /srv/stacks      # the directory holding your compose stacks
yd serve            # → http://127.0.0.1:8770  (loopback only)
```

The left rail lists every stack with a status signal (healthy / warning / blocking);
opening one gives a tabbed detail view — **Overview** (ranked guardrail issues,
per-service drift/update/CPU/mem chips, and the guarded actions), **Compose** (an
editor with **live** guardrail feedback as you type; Save snapshots to git, Save &
deploy runs the guarded path), **Mounts** (how each service connects to the outside —
host binds, named/anonymous volumes, networks — typed with existence), **Permissions**
(the security/compliance lens), **History** (git timeline with a unified **diff** and
one-click **restore**), **Backups**, and **Terminal** (live **logs-follow** and a
full **interactive PTY shell** into any service — top, vi, and interactive prompts
all work, via a bundled xterm.js over the same loopback server).

Every action runs through the same guarded path (guardrails → backup → health-gate →
rollback). Data entry is **fully in-page** — no browser popups: new stacks, image
upgrades, git connect, and confirmations are inline forms. A persistent **Console**
dock at the bottom shows everything yd runs. The header opens **All stacks** (the
fleet view: bulk check/backup and one-click **adoption** of newly-discovered stacks)
and **Git** (connect a remote and push/pull all config; sign-in uses your system Git
credentials — credential helper or SSH — and no tokens are stored). The interface is
theme-aware (light/dark, remembered) and built around a container-terminal identity:
Yard Dog is the yard truck that couples to and safely moves your containers.

Config is versioned in a single **monorepo** at the served root; the header **Git**
panel connects a remote and pushes/pulls all your config offsite in one action,
reusing your **system git credentials** (credential helper / SSH) — Yard Dog never
stores tokens.

**Security model (secure by default).** The server binds `127.0.0.1` only; it
never listens on a non-loopback address. It rejects any request whose `Host`
header is not a loopback name/address (a DNS-rebinding defense for a no-auth local
server), serves mutations over `POST` only, and confines every path parameter
under the served root (no absolute paths, no `..`). Secret values are never
rendered. For remote access, front it with your own SSH tunnel or authenticated
reverse proxy rather than widening the bind.

## Exit codes

`yd deploy`, `yd upgrade`, `yd check`, `yd doctor`, and `yd restore` share one
exit-code scheme so scripts and CI can react uniformly:

| Code | Meaning |
|---|---|
| `0` | Success (deployed / upgraded / cleanly rolled back / skipped / ready / restored). |
| `2` | Pre-change backup failed — nothing was applied (`deploy`, `upgrade`). |
| `3` | Blocked / not-ready / refused: a guardrail block (floating tag, plaintext or URL-embedded secret), an unresolvable service, `doctor`/`check` judging the stack not deploy-ready, `restore` refusing an unverifiable backup (missing/tampered manifest or failed verification), or `drift` detecting drift. |
| `4` | **Critical:** the change failed *and* the rollback redeploy also failed — the live stack needs attention (`deploy`, `upgrade`). |

A successful `deploy`/`upgrade` still prints `note: deployed but health NOT
verified — no healthcheck on: …` when a deployed service has no healthcheck, so
exit `0` never silently implies health was proven. Add a `healthcheck:` (or pass
`--wait-timeout` to widen the health-gate for a slow-starting stack).

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

The **browser control plane** has its own Playwright end-to-end matrix under
[`ui-e2e/`](ui-e2e/), driving real `yd serve` in Chromium across every tab and
interactive element (rail, compose draft persistence, validate, mounts,
permissions, history, fleet, git, backups, logs, theme):
```sh
cd app && cargo build --release      # the UI is embedded in yd; rebuild after editing ui.html
cd ../ui-e2e && npm install && npx playwright install chromium
npx playwright test
```

---

## Project tracking

This repository is tracked by **keel** (a SysML-based work-tracking engine): needs,
requirements, decisions, and test results live under `.tracking/`, and every
status/view is computed (`keel orient .`, `keel validate .`, `keel guard .`). See
`CLAUDE.md` for how work is authored here. The engine itself lives under `.engine/`
and is not part of this product.
