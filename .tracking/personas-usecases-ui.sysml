// =====================================================================
// YardDog — UI-focused use-case catalog (the browser control plane roadmap) and
// the security/compliance persona. These are the journeys the fleshed-out UI is
// designed around; each will be validated by a demo when built.
// =====================================================================
package YardDogUiPersonas {
    private import EngineElement::*;
    private import EngineNeeds::*;

    // ---- new persona ---------------------------------------------------------
    part danaPersona : Persona {
        :>> id = "2dda62a5-89b8-4cfd-a608-6a8970fd0bd8";
        :>> title = "Dana — the security/compliance-minded operator";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Runs the homelab (or a small team's infra) with a security hat on. Reviews what each stack is allowed to do, cares about mount/permission posture and container hardening, and wants an at-a-glance compliance read before trusting a stack.";
        :>> goals = "Know that no stack is over-privileged or leaking secrets; see mount typing and permission/compliance status plainly; keep an auditable history of what changed and when.";
    }

    // ---- UI use cases --------------------------------------------------------
    use case ucComposeEditor : UseCase {
        :>> id = "913132dd-2f00-4ae1-8746-8a8306fc8a27";
        :>> title = "Create a stack from scratch or edit one in the browser";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Alex/Riley author or change a stack's compose in the UI without hand-editing YAML in a terminal.";
        :>> mainSuccess = "The operator starts a new stack (blank or from a workload-kind template) or opens an existing one in an in-browser compose editor; as they type, guardrails + the preflight verdict update live; saving snapshots the config (git) and offers to deploy through the guarded path.";
        :>> extensions = "Invalid YAML is flagged inline; a block-severity guardrail (floating tag, plaintext secret, privileged, docker socket) prevents save-and-deploy until resolved; a datastore edit that drops its named volume is warned.";
    }

    use case ucStackIssues : UseCase {
        :>> id = "ddd19807-f1d2-4f2f-ae27-305269ae1c4b";
        :>> title = "See at a glance whether a stack has issues";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley wants one consolidated health/issues read per stack.";
        :>> mainSuccess = "A stack's Issues view aggregates guardrail findings (incl. security lens), drift, update availability, health, missing/absent mounts, and permission problems into a single ranked list with severity; the stack list shows an issue-count badge.";
        :>> extensions = "Zero issues shows an explicit all-clear; each issue links to the relevant view (Compose, Mounts, Permissions) and, where possible, a remediation.";
    }

    use case ucMountAnalysis : UseCase {
        :>> id = "a9743e19-eae5-429a-8d66-1d7b09b57a24";
        :>> title = "Inspect mount typing and existence metadata";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley/Sam want to understand each mount: is it a host bind path, a named volume, an anonymous volume, or a network path — and does it exist?";
        :>> mainSuccess = "A Mounts view lists every service mount with its classified type, resolved host path, existence status, and (for binds) whether Yard Dog would create or refuse to create it, with the guided remediation surfaced.";
        :>> extensions = "A bind path that does not exist is flagged with the exact fix; a network/anonymous mount is called out so it is not mistaken for durable local storage.";
    }

    use case ucPermissionCompliance : UseCase {
        :>> id = "745236ba-5c17-444c-9ab7-0b2120e79bc9";
        :>> title = "View permissions data and check compliance";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Dana reviews ownership/permission posture and a compliance read for a stack.";
        :>> mainSuccess = "A Permissions/Compliance view shows bind-mount ownership/mode data and a pass/warn/fail compliance summary derived from the guardrail security lens (privileged, docker socket, dangerous caps, host net/pid, plaintext secrets) plus permission-awareness checks.";
        :>> extensions = "Each failing check explains the risk and the remediation; a stack that is clean shows a green compliance badge usable as an at-a-glance trust signal.";
    }

    use case ucUpdateHistory : UseCase {
        :>> id = "d170787c-bde5-4866-a894-cabe47b59f72";
        :>> title = "View a stack's change / update history";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Sam/Alex want a timeline of what changed for a stack and when.";
        :>> mainSuccess = "A History view lists the git snapshots (deploys, upgrades, edits, restores) newest-first with timestamp, author, and message, so the operator can see the stack's evolution and correlate a problem with a change.";
        :>> extensions = "Each entry opens its diff (see ucConfigDiff) and offers restore (see ucRollbackFromHistory).";
    }

    use case ucConfigDiff : UseCase {
        :>> id = "986bde28-bfe3-4c73-85f1-1a696d777739";
        :>> title = "View compose diffs over time (git diff)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Alex/Riley want to see exactly what changed between two versions of a stack's config.";
        :>> mainSuccess = "Selecting two snapshots (or a snapshot vs. the working tree) renders a readable side-by-side / unified diff of the compose, so the operator can review a change before deploying or understand a past change.";
        :>> extensions = "The diff powering an upgrade or a rollback is shown as a confirmation preview before the action is applied.";
    }

    use case ucGitRemote : UseCase {
        :>> id = "50be03b2-46b3-4c48-a973-af33e4e128f1";
        :>> title = "Connect a git remote and sync config elegantly";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley/Sam want their versioned config backed up offsite without wrestling raw git.";
        :>> mainSuccess = "From a Git/Settings view the operator connects a remote (URL + a token or SSH key entered once, stored safely), and can push/pull the versioned config; status shows connected/ahead/behind, and secrets/data stay excluded from what is pushed.";
        :>> extensions = "Auth failures are explained plainly (bad token, host key); a first push offers to create the remote repo; the credential is never displayed back.";
    }

    use case ucSmoothBackupRestore : UseCase {
        :>> id = "4f7371da-a063-45e5-87a6-0669a5235c5f";
        :>> title = "Back up and restore extremely smoothly";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Sam wants backup and (especially) restore to be a confident, guided, low-anxiety flow.";
        :>> mainSuccess = "A Backups view lists recovery points with their verify status; taking a backup is one action with progress; restoring is guided — pick a point, see what it contains and a preview of what changes, confirm, and restore, with verification shown throughout.";
        :>> extensions = "A backup that fails verification is flagged and not offered as a restore source without warning; restore runs behind the same pre-change backup so the current state is itself recoverable.";
    }

    use case ucLiveLogs : UseCase {
        :>> id = "d6681c88-9ed7-4875-9ccb-3018ea608c6c";
        :>> title = "Stream a stack's container logs";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley wants to watch what a container is doing, especially right after a deploy or when diagnosing an issue.";
        :>> mainSuccess = "A Logs view streams `docker compose logs -f` for the stack (per-service filterable) into the UI, so the operator can watch startup and errors without a terminal.";
        :>> extensions = "Logs are read-only and bounded (tail + follow); the stream stops cleanly when the view is closed.";
    }

    use case ucRollbackFromHistory : UseCase {
        :>> id = "a0bc0033-0c0a-4838-8e01-3e9d00a3c0fd";
        :>> title = "Restore or redeploy a past version from history";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Alex wants to roll a stack back to a known-good past config from the timeline.";
        :>> mainSuccess = "From History, the operator picks a past snapshot, reviews its diff against current, and restores it — which snapshots the current state first, restores the chosen config, and (optionally) redeploys through the guarded health-gated path.";
        :>> extensions = "A restore that fails to redeploy healthy regresses like any other change; the chosen version is clearly labeled in the resulting history entry.";
    }

    use case ucResourceStats : UseCase {
        :>> id = "d90ef9d1-8678-45c9-a2bf-796010922e47";
        :>> title = "See per-container resource and health at a glance";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley wants a quick read on what each container is consuming and whether it is healthy.";
        :>> mainSuccess = "A stack view shows per-container status, health, and live CPU/memory usage (docker stats), so the operator spots a runaway or unhealthy container without a terminal.";
        :>> extensions = "Stats update periodically and stop when the view is closed; a stopped container is shown as such rather than as zero usage.";
    }

    use case ucImportWizard : UseCase {
        :>> id = "49e87f69-fdea-466b-9f7b-29fac2f3c516";
        :>> title = "Adopt existing compose stacks via a guided import";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley points Yard Dog at an existing directory of compose stacks and onboards them.";
        :>> mainSuccess = "An import/onboarding flow discovers compose stacks under a chosen root, shows each with an initial issues/preflight read, and adopts them (initialising versioning + a lifecycle state) so they become managed stacks.";
        :>> extensions = "A directory with no compose files is reported clearly; adoption never mutates the stack's running state, only begins managing it.";
    }

    use case ucNotifications : UseCase {
        :>> id = "ea7e06de-cd79-4cb4-9704-0b954dc98908";
        :>> title = "Be alerted to problems and available updates";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley wants to be told when something needs attention rather than having to go look.";
        :>> mainSuccess = "The UI surfaces notifications for healthcheck failures, drift, available image updates, and failed backups (via the existing notify channel), with a badge/inbox so the operator sees what changed since last visit.";
        :>> extensions = "Datastore updates are notify-only (never auto-applied); notifications link to the stack/view that can resolve them.";
    }

    use case ucBulkOps : UseCase {
        :>> id = "e8e9a50f-32ef-4e58-ae6b-0eebe03b4068";
        :>> title = "Act across many stacks at once";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley operates a dozen stacks and wants fleet-wide actions.";
        :>> mainSuccess = "The operator can run a check/backup across all stacks, and review + apply available updates across stacks in one place, each still going through the per-stack guarded path (guardrails, backup, health-gate, rollback) and kind policy (datastores notify-only).";
        :>> extensions = "Bulk actions report per-stack success/failure individually; a block/failure on one stack never silently affects the others.";
    }
}
