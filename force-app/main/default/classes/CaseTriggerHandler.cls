/**
 * @file              CaseTriggerHandler.cls
 * @description       Handles Case DML events fired by CaseTrigger.
 *                    Before-update: stamps Last_Owner_Change_Timestamp__c on
 *                    records whose OwnerId is changing (no DML required since
 *                    this runs before the database write).
 *                    After-update: enqueues CaseSummaryTransferQueueable for
 *                    each transferred case, keeping the trigger transaction
 *                    non-blocking.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-25
 * @lastModified      2026-05-25
 * @group             CaseSummaryTransfer
 *
 * @dependencies      CaseSummaryTransferService
 * @calledBy          CaseTrigger
 * @testClass         CaseTriggerHandlerTest
 *
 * @see               LLD-Case Summary Transfer 1.0 §2.1 Event Listener
 */
public with sharing class CaseTriggerHandler {

    /**
     * Routes Case trigger events to the appropriate handler methods.
     * Called by CaseTrigger; all trigger-context variables (Trigger.new,
     * Trigger.oldMap, etc.) are accessed inside this method.
     *
     * @calledBy    CaseTrigger
     * @testMethods test_onAfterUpdate_ownerChanged_enqueuesJob,
     *              test_onAfterUpdate_ownerNotChanged_doesNotEnqueueJob,
     *              test_onBeforeUpdate_ownerChanged_setsTransferTimestamp
     */
    public void run() {
        if (Trigger.isBefore && Trigger.isUpdate) {
            onBeforeUpdate(
                (List<Case>) Trigger.new,
                (Map<Id, Case>) Trigger.oldMap
            );
        } else if (Trigger.isAfter && Trigger.isUpdate) {
            onAfterUpdate(
                (List<Case>) Trigger.new,
                (Map<Id, Case>) Trigger.oldMap
            );
        }
    }

    /**
     * Sets Last_Owner_Change_Timestamp__c to the current time whenever a case
     * ownership change is detected. Runs before the record is written to the
     * database so no separate DML is needed.
     *
     * @param  newCases    Trigger.new list of Case records being updated.
     * @param  oldCaseMap  Trigger.oldMap keyed by Case Id.
     */
    private void onBeforeUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        for (Case newCase : newCases) {
            if (newCase.OwnerId != oldCaseMap.get(newCase.Id).OwnerId) {
                newCase.Last_Owner_Change_Timestamp__c = System.now();
            }
        }
    }

    /**
     * Enqueues a CaseSummaryTransferQueueable for each case whose owner changed.
     * The timestamp is read from Last_Owner_Change_Timestamp__c set in
     * onBeforeUpdate, with System.now() as a fallback.
     *
     * @param  newCases    Trigger.new list of Case records after update.
     * @param  oldCaseMap  Trigger.oldMap keyed by Case Id.
     */
    private void onAfterUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        for (Case newCase : newCases) {
            if (newCase.OwnerId != oldCaseMap.get(newCase.Id).OwnerId) {
                DateTime transferTime = newCase.Last_Owner_Change_Timestamp__c != null
                    ? newCase.Last_Owner_Change_Timestamp__c
                    : System.now();
                CaseSummaryTransferService.initiateSummaryGeneration(newCase.Id, transferTime);
            }
        }
    }
}