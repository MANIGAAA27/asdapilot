/**
 * @file              CaseSummaryTransferService.cls
 * @description       Entry point for the case-transfer summary pipeline. Called by
 *                    CaseTriggerHandler after a Case ownership change is detected.
 *                    Enqueues a CaseSummaryTransferQueueable to process the summary
 *                    asynchronously, keeping the trigger transaction non-blocking
 *                    per the NFR §7.1 (transfer must not be delayed by summarisation).
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-25
 * @lastModified      2026-05-25
 * @group             CaseSummaryTransfer
 *
 * @dependencies      CaseSummaryTransferQueueable
 * @calledBy          CaseTriggerHandler
 * @testClass         CaseSummaryTransferServiceTest
 *
 * @see               LLD-Case Summary Transfer 1.0 §2.1 Event Listener
 */
public with sharing class CaseSummaryTransferService {

    /**
     * Enqueues an async job to generate a case transfer summary.
     * Returns immediately; the queueable handles the full pipeline.
     *
     * @param  caseId             Id of the transferred Case.
     * @param  transferTimestamp  Timestamp of the ownership change (set in the
     *                            before-update trigger and passed here via Trigger.new).
     *
     * @calledBy    CaseTriggerHandler.onAfterUpdate
     * @testMethods test_initiateSummaryGeneration_validCaseId_enqueuedSuccessfully,
     *              test_initiateSummaryGeneration_createsSummaryViaQueueable
     */
    public static void initiateSummaryGeneration(Id caseId, DateTime transferTimestamp) {
        System.enqueueJob(new CaseSummaryTransferQueueable(caseId, transferTimestamp));
    }
}