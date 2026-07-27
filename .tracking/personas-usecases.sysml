// =====================================================================
// YardDog — product personas and the use-case catalog (business layer).
// Personas = who we build for (goals, solution-free). UseCases = the end-to-end
// journeys those personas run; each is validated by a real-Docker E2E demo
// (a #Verify edge from an e2e test, per D0006 — validation is verify-to-usecase).
// =====================================================================
package YardDogPersonas {
    private import EngineElement::*;
    private import EngineNeeds::*;

    // ---- Personas -----------------------------------------------------------
    part rileyPersona : Persona {
        :>> id = "b7b04c98-0e3d-45ca-b27e-4377cf3ffa5c";
        :>> title = "Riley — the homelab self-hoster";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Runs ~10 self-hosted services (photos, media, notes, *arr) via docker compose on one always-on box. Comfortable editing YAML but not a Docker/ops expert; treats the homelab as important infrastructure, not a toy.";
        :>> goals = "Keep services running with minimal ceremony; make every change safe and reversible so a bad edit never means downtime or a manual recovery.";
    }

    part samPersona : Persona {
        :>> id = "f719e503-72bc-4b81-be79-9b63eff5b92e";
        :>> title = "Sam — the data steward";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Runs stateful apps (Immich, Nextcloud, Postgres) where the data is irreplaceable. Has been burned by a backup that turned out to be unrestorable.";
        :>> goals = "Have application-consistent, verified, restorable backups; be confident an upgrade cannot corrupt or lose data, and be told immediately if a backup no longer matches what was captured.";
    }

    part alexPersona : Persona {
        :>> id = "c3a246d8-eae3-4f23-9644-1f6cf3f35fe6";
        :>> title = "Alex — the tinkerer / upgrader";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Frequently tries new images and versions, spins up experiments, and retires them. Wants to move fast without breaking the stable services.";
        :>> goals = "Try upgrades fearlessly with automatic rollback on failure; instantiate new stacks from a sane template; archive/deprecate/restore experiments cleanly through defined lifecycle states.";
    }

    // ---- Use cases (end-to-end journeys) ------------------------------------
    use case ucFirstDeploy : UseCase {
        :>> id = "364b6b2f-fc52-495e-999c-8ad46e731535";
        :>> title = "First safe deploy of a new stack";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley brings a new compose stack online safely for the first time.";
        :>> mainSuccess = "Riley writes (or instantiates) a compose file, runs `yd doctor` (READY), then `yd deploy --yes`: Yard Dog initializes the stack's versioning repo, snapshots the config, brings the container up and waits for it to become HEALTHY, and reports Deployed. `docker ps` shows the service running healthy.";
        :>> extensions = "If the compose has a block-severity guardrail finding, doctor reports NOT READY and deploy is blocked (exit 3) before anything starts.";
    }

    use case ucAutoRollback : UseCase {
        :>> id = "d34444c6-d512-4cc1-a073-834a9c12b8be";
        :>> title = "A broken change is automatically rolled back";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley deploys a change that never becomes healthy and expects the live stack to return to good.";
        :>> mainSuccess = "Riley edits the compose in a way that fails the healthcheck and runs `yd deploy --yes`: the health-gate (up -d --wait) fails, Yard Dog restores the last-good compose AND redeploys it, and the live container ends healthy on the good config (RolledBack). The git history records snapshot/snapshot/restore.";
        :>> extensions = "If even the rollback redeploy fails, the outcome is RollbackFailed (exit 4, CRITICAL message) so the operator knows the stack needs attention.";
    }

    use case ucHealthGatedUpgrade : UseCase {
        :>> id = "cb568dc4-37ba-4ceb-b1fe-c7d4aa5c310b";
        :>> title = "Health-gated image upgrade (accept or regress)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Alex upgrades a running service to a new image version.";
        :>> mainSuccess = "Alex runs `yd upgrade --service web --image nginx:1.29-alpine --yes`: Yard Dog backs up, snapshots, surgically edits the image line, deploys, waits for HEALTHY, and accepts — the running container is now the new image, healthy, and the compose reflects the new tag.";
        :>> extensions = "An upgrade to an image that fails the healthcheck regresses to the last-good image; an upgrade of an unknown/build-only service is refused (NoSuchService, exit 3) rather than silently reporting success.";
    }

    use case ucBackupVerifiedRestore : UseCase {
        :>> id = "f815f3fb-81b2-478b-ac1d-a695b88169f2";
        :>> title = "Application-consistent backup with verified integrity";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Sam backs up a stack's data and proves the backup is intact.";
        :>> mainSuccess = "Sam runs `yd backup <compose> --run --dest bak`: Yard Dog captures the bind-mounted data (and DB dumps where applicable) into a destination with a checksum manifest. `yd verify --dest bak` reports clean.";
        :>> extensions = "If a backed-up file is later modified, added, or removed, `yd verify` detects it (Changed / Unexpected / Missing) and exits non-zero — an untested backup becomes a tested one.";
    }

    use case ucGuardrailsBlock : UseCase {
        :>> id = "3f9ac4b1-8b54-493b-a01a-a955c6a30013";
        :>> title = "Guardrails block a dangerous stack before it deploys";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley/Sam are protected from a risky compose by preventative guardrails.";
        :>> mainSuccess = "A compose with a floating :latest tag or an inline plaintext secret is reported NOT READY by `yd doctor` and refused by `yd deploy` (Blocked, exit 3) before any container starts; a missing healthcheck is surfaced as a warning.";
        :>> extensions = "A *_FILE secret reference (Docker-secrets convention) is NOT flagged; an upgrade that would introduce a floating tag is blocked on the post-change compose.";
    }

    use case ucDriftDetection : UseCase {
        :>> id = "d703fb7a-66ed-4a80-bec8-68f16bc2c804";
        :>> title = "See drift between the declared compose and the running stack";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Riley wants to know when what is running no longer matches the compose on disk (an out-of-band change, a not-yet-applied edit, or a stopped service).";
        :>> mainSuccess = "With the stack deployed, `yd drift <compose>` reports 'no drift'. After Riley edits the declared image without redeploying, `yd drift` reports ImageChanged (declared vs running); a stopped service reports Missing; a container with no compose entry reports Unexpected.";
        :>> extensions = "When the Docker daemon is unreachable, drift reports the declared services and notes running-state is unavailable rather than guessing.";
    }

    use case ucLifecycle : UseCase {
        :>> id = "7dd97abc-6f17-4546-9b80-0b06b3488062";
        :>> title = "Manage a stack through its lifecycle states";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "Alex instantiates, activates, deprecates, archives, and restores a stack.";
        :>> mainSuccess = "Alex runs `yd new --kind <k>` to scaffold a guardrail-clean stack in Draft, then `yd lifecycle` transitions it activate -> deprecate -> archive; deploying an Archived stack is refused until `yd lifecycle --event restore` brings it back.";
        :>> extensions = "Invalid transitions (e.g. restore from Active) are rejected and leave the persisted state unchanged.";
    }
}
