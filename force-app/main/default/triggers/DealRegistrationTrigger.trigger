/**
 * @file        DealRegistrationTrigger.trigger
 * @description Routes Deal_Registration__c DML events to DealRegistrationHandler.
 *              All logic lives in the handler (trigger body logic rule §6).
 *              Fires after insert and after update; bulkified via Trigger.new.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-05-29
 * @lastModified 2026-05-29
 * @testClass   DealRegistrationHandlerTest
 */
trigger DealRegistrationTrigger on Deal_Registration__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            DealRegistrationHandler.processAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            DealRegistrationHandler.processAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
