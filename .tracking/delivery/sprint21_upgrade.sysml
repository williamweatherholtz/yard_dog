// =====================================================================
// YardDog — Sprint 21 delivery: one-shot safe upgrade.
// set_service_image + safe_upgrade (backup+snapshot+deploy+health-gate+
// regress-or-accept); `yd upgrade`.
// =====================================================================
package Sprint21Upgrade {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyUpgrade : Story {
        :>> id = "907dc6da-f952-46dd-accb-2d2279cf129b";
        :>> title = "Safe upgrade flow (regress-or-accept) + `yd upgrade`";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyUpgrade to needSafeUpgrade;

        action setServiceImage;
        verification setServiceImageDoD : Test { :>> id = "0e222b4a-f790-462d-973e-2e4c0e11aabb"; :>> method = VerificationMethod::test; :>> procedureText = "set_service_image(compose_path, service, image) rewrites just that service's image in the compose file, preserving other services; unit-tested (read back shows the new image)."; }
        part setServiceImageDoDR1 : TestResult { :>> id = "68913902-03fd-4be3-80ab-54808c265b49"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b2fd30e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action safeUpgrade;
        verification safeUpgradeDoD : Test { :>> id = "2d1dd938-bafe-4149-973e-2e4c0ede88d3"; :>> method = VerificationMethod::test; :>> procedureText = "safe_upgrade orchestrates backup + git snapshot + set-image + deploy; on a passing deploy with accept => Upgraded (new image kept), passing without accept => Regressed (image reverted to last-good), failing deploy => Regressed; unconfirmed => Skipped; unit-tested over a git repo with fixture deployer/backup."; }
        part safeUpgradeDoDR1 : TestResult { :>> id = "20109e52-e28f-46e7-80ab-54808d368329"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b2fd30e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
        action cliUpgrade;
        verification cliUpgradeDoD : Test { :>> id = "a79e2712-ac88-4605-973e-2e4c0f9f80d3"; :>> method = VerificationMethod::test; :>> procedureText = "yd upgrade <compose> --repo DIR --service S --image IMG applies via safe_upgrade; without --yes it is a no-op (no image change, no new commit); integration test asserts the dry run leaves the compose unchanged."; }
        part cliUpgradeDoDR1 : TestResult { :>> id = "54b6f649-d5fe-4b67-80ab-54808e99d9f5"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b2fd30e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    action def Sprint21Backlog { }

    verification refineGate21 : Test { :>> id = "cf5dc21e-33d0-4e06-bf13-620af8941101"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edge set; scope clear; DoD tasks authored; composes backup + gitver + deploy primitives."; }
    part refineGate21R1 : TestResult { :>> id = "8ca17a58-4538-43ad-973e-2e4c119a36cb"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b2fd30e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate21 : Test { :>> id = "7b8394a1-fdbd-4d6c-bb3a-5f4ffdd91ebb"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: 3/3 DoD green (73 lib + 19 integration, 0 warnings); set_service_image rewrites one service's image, safe_upgrade backs up + snapshots + deploys + regresses on failed healthcheck or when a healthy upgrade is not accepted, `yd upgrade` dry-run is a no-op."; }
    part reviewGate21R1 : TestResult { :>> id = "8b0a6b07-7904-4c1e-8305-1f869451506e"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b2fd30e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
    verification closeOutGate21 : Test { :>> id = "b67228aa-0651-4c33-973e-2d8c1f768b35"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: 3/3 DoD pass; srSafeUpgrade verified; needSafeUpgrade covered — the operator's health-gated regress-or-accept upgrade, composed from existing primitives."; }
    part closeOutGate21R1 : TestResult { :>> id = "24e123e8-6f57-4c36-8305-1f869557c4b6"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b2fd30e"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
