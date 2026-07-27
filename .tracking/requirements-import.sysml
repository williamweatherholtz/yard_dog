// =====================================================================
// YardDog — System Requirement for importing/adopting existing compose stacks.
// =====================================================================
package YardDogImportReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srImportAdopt : SystemRequirement {
        :>> id = "7e3f6326-080f-4420-acaf-bf045fb1d42a";
        :>> title = "Import an existing compose stack into management without rebuilding";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall import an existing compose file (and its sibling .env) into the managed stacks directory as a named stack, without rebuilding or modifying the original, and refuse to overwrite an existing stack of the same name.";
        :>> rationale = "Migration off Portainer is a recurring story; a low-friction 'adopt my existing compose' path reinforces the files-on-disk model and lowers the switching cost.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needImportAdopt by srImportAdopt;

    #Verify dependency from importComposeDoD to srImportAdopt;
    #Verify dependency from importSafetyDoD to srImportAdopt;
}
