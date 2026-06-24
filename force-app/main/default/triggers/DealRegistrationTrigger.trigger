/**
 * Trigger on Deal_Registration__c to auto-create and sync Opportunities.
 */
trigger DealRegistrationTrigger on Deal_Registration__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        DealRegistrationTriggerHandler.handleAfterInsert(Trigger.new);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        DealRegistrationTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
    }
}
