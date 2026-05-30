/**
 * @file        DealRegistrationTrigger.trigger
 * @description Routes Deal Registration DML events to DealRegistrationHandler.
 *              All logic lives in the handler (Sr Dev rule: no trigger body logic).
 *              Bulkified — handler operates on Trigger.new / Trigger.oldMap lists.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-05-30
 * @lastModified 2026-05-30
 * @testClass   DealRegistrationHandlerTest
 */
trigger DealRegistrationTrigger on Deal_Registration__c (after insert, after update) {
    DealRegistrationHandler handler = new DealRegistrationHandler();
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.processAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.processAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
