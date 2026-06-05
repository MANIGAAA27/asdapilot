/**
 * @file        CaseTrigger.trigger
 * @project     Case Transfer
 * @lld         LLD-CaseTransfer-2 (BR3-BR4)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-05
 */
/**
 * @file              CaseTrigger.trigger
 * @description       Delegating trigger for Case object. Routes all DML events
 *                    to CaseTriggerHandler for centralized processing.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-23
 * @lastModified      2026-05-23
 * @group             CaseManagement
 *
 * @dependencies      CaseTriggerHandler
 * @calledBy          Salesforce DML operations on Case
 * @testClass         CaseTriggerHandlerTest
 *
 * @see               LLD Case Transfer Summary Generation
 */
trigger CaseTrigger on Case (before insert, before update, after insert, after update) {
    CaseTriggerHandler handler = new CaseTriggerHandler();
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
