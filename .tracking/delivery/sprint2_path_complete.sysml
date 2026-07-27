// =====================================================================
// YardDog — Sprint 2 delivery: complete the path pillar.
// Turns the path core from "reports problems" into "prevents & fixes them":
// apply remediations on explicit confirmation, read PUID/PGID from compose,
// detect network mounts from the host mount table (fixture-tested), and handle
// the ${VAR:-default} interpolation forms (resolving issueComposeInterpolation).
// Charter targets referenced by bare name (generic .tracking validation).
// =====================================================================
package Sprint2PathComplete {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyPathComplete : Story {
        :>> id = "580db355-2cb1-40d6-b963-508f968bd686";
        :>> title = "Complete the path pillar: apply-remediation, PUID/PGID, network detection, interpolation forms";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    // Charter lineage: the Needs this sprint advances.
    #CharteredBy dependency from storyPathComplete to needGuidedRemediation;
    #CharteredBy dependency from storyPathComplete to needPermissionAwareness;
    #CharteredBy dependency from storyPathComplete to needPathTyping;
    #CharteredBy dependency from storyPathComplete to needComposeManagement;

    // Backlog: tasks added via `keel add-task --def Sprint2Backlog`.
        action interpolationForms;
        verification interpolationFormsDoD : Test { :>> id = "d9e742f9-cb43-448d-a1c6-dc0aaccdb663"; :>> method = VerificationMethod::test; :>> procedureText = "Compose interpolation handles ${VAR:-default}, ${VAR-default}, and ${VAR:?err}; unit tests include ${CONFIG:-/opt/immich}/config resolving to the default when unset and to the value when set."; }
        action puidPgidFromCompose;
        verification puidPgidFromComposeDoD : Test { :>> id = "8f041151-7786-4301-a1c6-dc0aad8fd86f"; :>> method = VerificationMethod::test; :>> procedureText = "PUID/PGID are read from a service's environment (both list and map forms) and passed into ownership detection; a unit test flags a bind whose owner differs from the declared PUID/PGID."; }
        action networkMountDetection;
        verification networkMountDetectionDoD : Test { :>> id = "ef5e91bc-9007-459d-a1c6-dc0aae50d9cf"; :>> method = VerificationMethod::test; :>> procedureText = "Mount-table parsing is a pure function unit-tested against a fixture /proc/mounts: a bind path under an nfs/cifs mount classifies as network, one under ext4 does not."; }
        action applyRemediation;
        verification applyRemediationDoD : Test { :>> id = "570e359f-e021-4e09-a1c6-dc0aaf0becd3"; :>> method = VerificationMethod::test; :>> procedureText = "A selected remediation (create-with-owner / chown / chmod) is applied ONLY on explicit confirmation; a recording-fixture test asserts no filesystem action without confirmation and the correct action with it."; }
        action cliApply;
        verification cliApplyDoD : Test { :>> id = "7faaeeb8-bd20-4375-a1c6-dc0aafc4bcef"; :>> method = VerificationMethod::test; :>> procedureText = "yd applies confirmed remediations end-to-end; an integration test over a tempdir drives a confirmation and asserts the fix was applied, and that declining applies nothing."; }
    action def Sprint2Backlog { }

    // This sprint's interpolation task resolves the logged compose-interpolation Issue.
    #Resolves dependency from interpolationForms to issueComposeInterpolation;

    // Refine/DoR gate.
    verification refineGate2 : Test { :>> id = "71b9dcf7-8c23-47ca-a303-614e915110b1"; :>> method = VerificationMethod::inspect; :>> procedureText = "Definition of Ready: estimatedPoints set (5); #CharteredBy edges set; scope/acceptance unambiguous; DoD tasks authored with method-tagged criteria; builds on the Sprint 1 path core."; }
    part refineGate2R1 : TestResult { :>> id = "e82b752d-d0ef-4401-a1d2-d0438b9060eb"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "5d1c8bd"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "ai"; }
}
