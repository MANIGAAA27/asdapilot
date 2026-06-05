/**
 * @file              CaseTriggerHandler.cls
 * @description       Handles Case after-update trigger events. Detects OwnerId
 *                    changes in a bulk-safe manner and delegates to
 *                    CaseTransferService to initiate summary generation.
 *                    Implements HLD-CMP-002 and the bulk-safe pattern from
 *                    HLD Section 5.2. Collects all transferred Case IDs into
 *                    a single Set before calling the service — never enqueues
 *                    one job per record.
 * @author            ASDA Dev Agent
 * @created           2026-06-05
 * @lastModified      2026-06-05
 * @group             CaseTransfer
 *
 * @dependencies      CaseTransferService
 * @calledBy          CaseTrigger
 * @testClass         CaseTriggerHandlerTest
 *
 * @see               HLD-CMP-001, HLD-CMP-002, HLD Section 5.2
 */
public with sharing class CaseTriggerHandler {

    /**
     * Processes after-update Case events. Identifies records where OwnerId
     * has changed and passes the collected IDs to CaseTransferService as a
     * single bulk call. Implements BR-001.
     *
     * @param newCases   Trigger.new — list of updated Case records.
     * @param oldCaseMap Trigger.oldMap — map of Case Id to pre-update Case.
     *
     * @calledBy    CaseTrigger
     * @testMethods test_onAfterUpdate_ownerChanged_callsService,
     *              test_onAfterUpdate_noOwnerChange_doesNotCallService,
     *              test_onAfterUpdate_bulkTransfer_collectsAllIds
     */
    public void onAfterUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        Set<Id> transferredCaseIds = new Set<Id>();

        for (Case newCase : newCases) {
            Case oldCase = oldCaseMap.get(newCase.Id);
            if (oldCase != null && newCase.OwnerId != oldCase.OwnerId) {
                transferredCaseIds.add(newCase.Id);
            }
        }

        if (!transferredCaseIds.isEmpty()) {
            CaseTransferService.beginSummaryGeneration(transferredCaseIds);
        }
    }
}
