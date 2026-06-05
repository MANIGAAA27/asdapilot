/**
 * @file        CaseTrigger.trigger
 * @description Routes Case after-update DML events to CaseTriggerHandler.
 *              All logic lives in the handler (no trigger body logic).
 *              Bulk-safe — handler operates on Trigger.new / Trigger.oldMap lists.
 *              Detects OwnerId changes and delegates to CaseTransferService
 *              via the handler. Implements HLD-CMP-001.
 * @author      ASDA Dev Agent
 * @created     2026-06-05
 * @lastModified 2026-06-05
 * @group       CaseTransfer
 * @testClass   CaseTriggerHandlerTest
 * @see         HLD-CMP-001, HLD Section 5.2
 */
trigger CaseTrigger on Case (after update) {
    new CaseTriggerHandler().onAfterUpdate(Trigger.new, Trigger.oldMap);
}
