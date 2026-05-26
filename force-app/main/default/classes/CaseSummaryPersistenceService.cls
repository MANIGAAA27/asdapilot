/**
 * @file              CaseSummaryPersistenceService.cls
 * @description       Creates and persists Case_Transfer_Summary__c records.
 *                    Called by CaseSummaryTransferQueueable after the LLM response
 *                    has been validated (or after an exception to record the failure).
 *                    Enforces FLS via Security.stripInaccessible before insert.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-25
 * @lastModified      2026-05-25
 * @group             CaseSummaryTransfer
 *
 * @dependencies      (none in this changeset)
 * @calledBy          CaseSummaryTransferQueueable
 * @testClass         CaseSummaryPersistenceServiceTest
 *
 * @see               LLD-Case Summary Transfer 1.0 §2.5 Summary Persistence Service
 */
public with sharing class CaseSummaryPersistenceService {

    /**
     * Creates and inserts a Case_Transfer_Summary__c record for the given case.
     * Used for both success and failure paths; the caller passes the appropriate
     * generationStatus ('Success' or 'Failed').
     *
     * @param  caseId             Parent Case Id — populates Case__c (MasterDetail).
     * @param  summaryText        LLM-generated text (or error message on failure).
     * @param  transferTimestamp  Timestamp of the ownership change event.
     * @param  modelName          Name of the LLM model (e.g., 'gpt-4').
     * @param  modelVersion       Version string (e.g., '1.0').
     * @param  generationStatus   'Success' or 'Failed' — drives UI visibility.
     * @return Inserted Case_Transfer_Summary__c with Id populated.
     * @throws DmlException if the insert fails (e.g., validation rule violation).
     *
     * @calledBy    CaseSummaryTransferQueueable.execute
     * @testMethods test_createSummaryRecord_validInputs_createsRecord,
     *              test_createSummaryRecord_failedStatus_persistsErrorRecord
     */
    public static Case_Transfer_Summary__c createSummaryRecord(
        Id       caseId,
        String   summaryText,
        DateTime transferTimestamp,
        String   modelName,
        String   modelVersion,
        String   generationStatus
    ) {
        Case_Transfer_Summary__c record = new Case_Transfer_Summary__c(
            Case__c               = caseId,
            Summary_Text__c       = summaryText,
            Transfer_Timestamp__c = transferTimestamp,
            Model_Name__c         = modelName,
            Model_Version__c      = modelVersion,
            Generation_Status__c  = generationStatus
        );

        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<Case_Transfer_Summary__c>{ record }
        );
        List<Case_Transfer_Summary__c> sanitised =
            (List<Case_Transfer_Summary__c>) decision.getRecords();

        Database.insert(sanitised, true);
        return sanitised[0];
    }
}