// =====================================================================
// YardDog — System Requirement for operational visibility (health events +
// notifications).
// =====================================================================
package YardDogNotifyReqs {
    private import EngineElement::*;
    private import EngineNeeds::*;
    private import EngineRequirements::*;
    private import EngineRelationships::*;

    requirement srNotifications : SystemRequirement {
        :>> id = "e3fa37ad-9276-4128-8236-c89061846ba9";
        :>> title = "Emit health events and notify through a pluggable channel";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> statement = "The system shall derive health events (container down / unhealthy) from container states and deliver them through a pluggable notification channel, so the operator is told when a container dies or becomes unhealthy.";
        :>> rationale = "'Tell me when a container dies' is a near-universal expectation (Apprise/ntfy/Discord); a channel abstraction with a default stdout notifier delivers it now and admits webhook/push channels next.";
        :>> kind = RequirementKind::functional;
        :>> verificationMethod = VerificationMethod::test;
        :>> priority = Priority::should;
    }

    satisfy needOperationalVisibility by srNotifications;

    #Verify dependency from healthEventsDoD to srNotifications;
    #Verify dependency from notifyDispatchDoD to srNotifications;
}
