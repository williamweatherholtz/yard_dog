// =====================================================================
// YardDog — product backlog: candidate work not yet pulled into a sprint.
// Tasks here are added via `keel add-task --def ProductBacklog`; a #Resolves
// edge triages an Issue to the action that will fix it (D0077).
// =====================================================================
package YardDogBacklog {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

        action fixComposeInterpolation;
        verification fixComposeInterpolationDoD : Test { :>> id = "a26d897a-80c7-4e23-8a50-e207333beded"; :>> method = VerificationMethod::test; :>> procedureText = "Compose interpolation handles the ${VAR:-default}, ${VAR-default}, and ${VAR:?err} forms, verified by unit tests including a source like ${CONFIG:-/opt/immich}/config resolving correctly."; }
    action def ProductBacklog { }

    // Triage: this action resolves the compose-interpolation gap (cross-package
    // bare name ref — generic .tracking validation, per sysmlv2-syntax-notes).
    #Resolves dependency from fixComposeInterpolation to issueComposeInterpolation;
}
