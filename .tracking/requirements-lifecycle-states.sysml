// =====================================================================
// YardDog — System Requirement for the stack lifecycle state machine.
// =====================================================================
package YardDogLifecycleStateReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srLifecycleFsm : SystemRequirement {
        :>> id = "d201561b-a827-44f2-934a-cd04423c5705";
        :>> title = "Model a stack's lifecycle as an explicit state machine";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall represent a stack's lifecycle as an explicit finite state machine over the states Draft, Active, Deprecated, and Archived, with guarded transitions: activate (Draft|Deprecated|Archived -> Active), deprecate (Active -> Deprecated), archive (Active|Deprecated|Draft -> Archived), and restore (Archived -> Active). Transitions not in the table shall be rejected (unrepresentable), and the current state shall be persisted per-stack on disk (default Draft when unset).";
        :>> rationale = "The user wants holistic stack management — archive, restore, deprecate, instantiate new — rather than ad-hoc start/stop. An explicit FSM makes invalid lifecycle transitions unrepresentable (the project's state-machine philosophy) and gives every later feature (instantiate-from-kind, retention of archived stacks) a defined state to key off.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needLifecycleStates by srLifecycleFsm;

    #Verify dependency from lifecycleTransitionsDoD to srLifecycleFsm;
    #Verify dependency from lifecycleGuardsDoD to srLifecycleFsm;
    #Verify dependency from lifecyclePersistDoD to srLifecycleFsm;
}
