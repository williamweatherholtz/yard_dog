# Yard Dog — UI end-to-end tests (Playwright)

Drives the real `yd serve` browser control plane in Chromium and asserts every tab
and interactive element. The suite is the regression net for client-side state bugs
(the "compose lost on tab switch" class) that Rust unit tests can't see.

## Run

```sh
cd app && cargo build --release      # the tests launch this binary
cd ../ui-e2e
npm install                          # first time
npx playwright install chromium      # first time
npx playwright test                  # run the matrix
npx playwright test --ui             # interactive
```

The Playwright config (`playwright.config.ts`) copies `fixtures/stacks/` into an
isolated temp root and launches `yd serve --root <temp> --port 8788 --host 127.0.0.1`
as its web server, so runs never touch your real stacks. Rebuild the binary after
editing `app/src/ui.html` — the UI is embedded in `yd`.

## Fixtures

| Stack | Exercises |
|---|---|
| `web` | warn-only guardrails; one existing + one missing host-bind (Mounts) |
| `cache` | clean stack (ok badge); named volume; COMPLIANT (Permissions) |
| `risky` | block-severity guardrails (privileged + socket) → notification badge, NOT COMPLIANT |

## Coverage

Rail (list/filter/badges/notify/active) · tab rendering · **compose draft
persistence across tab switches** (new + existing stacks, per-stack) · live
validate panel · new-stack template · save→history · Mounts typing/existence ·
Permissions compliance · Fleet · Git · Backups/Logs empty states · **persistent
output console** · theme toggle.

Docker-dependent actions (deploy/backup-run/logs/stats) are asserted at the
render/affordance level only, so the suite runs without a daemon.
