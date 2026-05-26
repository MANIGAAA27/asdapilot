/**
 * @file        CaseTrigger.trigger
 * @description Routes Case DML events to CaseTriggerHandler.
 *              All logic lives in the handler — no trigger body logic
 *              (CLAUDE.md Sr Dev rule §6). Fires on before update to stamp
 *              Last_Owner_Change_Timestamp__c and after update to enqueue
 *              the summary-generation queueable when ownership changes.
 * @author      ASDA Dev Agent (Claude Code)
 * @testClass   CaseTriggerHandlerTest
 */
trigger CaseTrigger on Case (before update, after update) {
    new CaseTriggerHandler().run();
}