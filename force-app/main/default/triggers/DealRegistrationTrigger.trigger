/**
 * @file              DealRegistrationTrigger.trigger
 * @description       Routes Deal_Registration__c DML events (after insert,
 *                    after update) to DealRegistrationHandler. All business
 *                    logic lives in the handler class — no trigger body logic
 *                    per Sr Dev rule §6. Bulkified — handler operates on
 *                    Trigger.new / Trigger.old lists.
 * @author            ASDA Dev Agent
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             PartnerRegistrationAutomation
 *
 * @dependencies      DealRegistrationHandler
 * @calledBy          (none in this changeset — fired by Salesforce platform)
 * @testClass         DealRegistrationHandlerTest
 *
 * @see               LLD - Partner Registration Automation (Feature: Partner Registration Automation)
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
