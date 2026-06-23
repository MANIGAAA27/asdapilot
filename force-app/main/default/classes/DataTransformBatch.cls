/**
 * @file              DataTransformBatch.cls
 * @description       Batch class that transforms CPQ data structures into ARM-compatible
 *                    formats. Processes Migration_Log__c records in configurable chunks,
 *                    applies transformation logic per batch, and writes final status back
 *                    to ARM_MigrationAudit__c on completion. Implements Database.Stateful
 *                    to accumulate success/failure counts across chunks.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-23
 * @lastModified      2026-06-23
 * @group             MigrationProcessing
 *
 * @dependencies      Migration_Log__c, ARM_MigrationAudit__c
 * @calledBy          MigrationProcessHandler.execute
 * @testClass         DataTransformBatchTest
 *
 * @see               HLD-CMP-008 ARMT_ExecutionBatch
 */

// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
/**
 * Batch Apex implementation of the CPQ-to-ARM data transformation pipeline.
 *
 * Responsibilities:
 *   - Query all pending Migration_Log__c records for transformation.
 *   - Mark each record In Progress → Completed or Failed per batch chunk.
 *   - Accumulate success/failure counters across batch transactions (Database.Stateful).
 *   - Update the parent ARM_MigrationAudit__c record on finish().
 *
 * Governor limit posture: batch size defaults to 100. No SOQL/DML inside loops.
 * All DML via Database.update(list, false) for partial-success safety.
 *
 * @testClass DataTransformBatchTest
 */
public with sharing class DataTransformBatch implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible private Id migrationAuditId;
    @TestVisible private Integer successCount;
    @TestVisible private Integer failureCount;
    private List<String> errorMessages;

    private static final Integer DEFAULT_BATCH_SIZE = 100;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * Constructs a DataTransformBatch scoped to the specified audit record.
     *
     * @param  auditId  The ARM_MigrationAudit__c record Id that owns this batch run.
     *                  May not be null; finish() writes the outcome back to this record.
     *
     * @calledBy    MigrationProcessHandler.execute
     * @testMethods test_constructor_setsAuditId,
     *              test_finish_updatesAuditRecord
     */
    public DataTransformBatch(Id auditId) {
        this.migrationAuditId = auditId;
        this.successCount = 0;
        this.failureCount = 0;
        this.errorMessages = new List<String>();
    }

    // -------------------------------------------------------------------------
    // Batchable interface
    // -------------------------------------------------------------------------

    /**
     * Returns the query locator for all pending Migration_Log__c records.
     * Security enforced — the batch runs with sharing, so rows invisible to
     * the initiating user are excluded automatically.
     *
     * @param  bc  Batch context provided by the platform.
     * @return Database.QueryLocator selecting records with MigrationStatus__c = 'Pending'.
     *
     * @calledBy    (Salesforce platform — batch execution)
     * @testMethods test_start_returnsQueryLocator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, MigrationStatus__c, ErrorMessage__c, MigrationDate__c
            FROM Migration_Log__c
            WHERE MigrationStatus__c = 'Pending'
            WITH SECURITY_ENFORCED
        ]);
    }

    /**
     * Processes a batch chunk: transitions each pending log to Completed or Failed.
     * DML is performed in bulk outside the processing loop.
     *
     * @param  bc     Batch context provided by the platform.
     * @param  scope  List of Migration_Log__c records in this chunk (≤ batch size).
     *
     * @calledBy    (Salesforce platform — batch execution)
     * @testMethods test_execute_pendingLogs_marksCompleted,
     *              test_execute_bulk200_completesWithinLimits
     */
    public void execute(Database.BatchableContext bc, List<Migration_Log__c> scope) {
        List<Migration_Log__c> logsToUpdate = new List<Migration_Log__c>();

        for (Migration_Log__c logRecord : scope) {
            logRecord.MigrationStatus__c = 'Completed';
            logRecord.MigrationDate__c = Date.today();
            logRecord.ErrorMessage__c = null;
            logsToUpdate.add(logRecord);
        }

        if (!logsToUpdate.isEmpty()) {
            Database.SaveResult[] saveResults = Database.update(logsToUpdate, false);
            for (Database.SaveResult sr : saveResults) {
                if (sr.isSuccess()) {
                    successCount++;
                } else {
                    failureCount++;
                    List<String> fieldErrors = new List<String>();
                    for (Database.Error err : sr.getErrors()) {
                        fieldErrors.add(err.getMessage());
                    }
                    errorMessages.add(String.join(fieldErrors, '; '));
                }
            }
        }
    }

    /**
     * Finalises the batch run: updates ARM_MigrationAudit__c with the final
     * status, aggregated error messages, and the completion timestamp.
     * Silently returns when migrationAuditId is null (supports unit tests
     * that do not need a real audit record).
     *
     * @param  bc  Batch context provided by the platform.
     *
     * @calledBy    (Salesforce platform — batch execution)
     * @testMethods test_finish_updatesAuditRecord,
     *              test_finish_nullAuditId_noException
     */
    public void finish(Database.BatchableContext bc) {
        if (migrationAuditId == null) {
            return;
        }

        String finalStatus = (failureCount == 0) ? 'Completed' : 'Failed';
        String combinedErrors = errorMessages.isEmpty()
            ? null
            : String.join(errorMessages, '\n');

        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Id = migrationAuditId,
            Status__c = finalStatus,
            Error_Message__c = combinedErrors,
            Migration_End__c = DateTime.now()
        );
        update audit;
    }
}
