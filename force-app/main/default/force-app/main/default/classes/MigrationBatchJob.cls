/**
 * @file              MigrationBatchJob.cls
 * @description       Batch job class that executes migration in configurable batches.
 *                    Handles start, execute, and finish processing for the ARMT
 *                    migration pipeline. Implements Database.Stateful to track
 *                    progress across batch executions and Database.AllowsCallouts
 *                    for integration with external org APIs.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             MigrationExecution
 *
 * @dependencies      MigrationProgressMonitoring
 * @calledBy          (none in this changeset)
 * @testClass         TestMigrationBatchJob
 *
 * @see               HLD-CMP-008 MigrationExecutionBatch
 */

/**
 * Batchable Apex class that processes ARMT_Snapshot__c records in configurable
 * batch sizes, logging progress and errors via MigrationProgressMonitoring.
 *
 * Responsibilities:
 *   - Query ARMT_Snapshot__c records scoped to a given job context.
 *   - Process each batch, serializing and persisting snapshot data.
 *   - Track success/failure counts across all batch executions.
 *   - Log completion summary on finish.
 *
 * Threading: Implements Database.Stateful — state is preserved across execute calls.
 *
 * @testClass TestMigrationBatchJob
 */
public with sharing class MigrationBatchJob implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

    /** Total records successfully processed across all batch executions. */
    @TestVisible
    private Integer successCount = 0;

    /** Total records that failed processing across all batch executions. */
    @TestVisible
    private Integer errorCount = 0;

    /** Optional filter string appended to the SOQL query for scoping. */
    @TestVisible
    private String jobFilter;

    /** Correlation identifier for progress logging. */
    @TestVisible
    private String correlationId;

    // ─────────────────────────────────────────────────────────────────────────
    // Constructors
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Default constructor. Processes all ARMT_Snapshot__c records with
     * Status__c = 'In Progress'.
     *
     * @calledBy    (none in this changeset)
     * @testMethods test_start_defaultConstructor_returnsQueryLocator,
     *              test_execute_successPath_incrementsSuccessCount,
     *              test_finish_logsCompletion
     */
    public MigrationBatchJob() {
        this.jobFilter = null;
        this.correlationId = String.valueOf(System.currentTimeMillis());
    }

    /**
     * Parameterised constructor allowing callers to scope the batch to a
     * specific correlation context.
     *
     * @param correlationId  Identifier linking this batch run to a migration job.
     *
     * @calledBy    (none in this changeset)
     * @testMethods test_start_paramConstructor_returnsQueryLocator
     */
    public MigrationBatchJob(String correlationId) {
        this.correlationId = String.isBlank(correlationId)
            ? String.valueOf(System.currentTimeMillis())
            : correlationId;
        this.jobFilter = null;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Database.Batchable interface
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns the query locator that defines the scope of records to process.
     * Queries ARMT_Snapshot__c records with Status__c = 'In Progress'.
     *
     * @param  bc  The batch context provided by the platform.
     * @return Database.QueryLocator scoping the batch execution.
     *
     * @calledBy    Salesforce Batch Framework
     * @testMethods test_start_defaultConstructor_returnsQueryLocator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        MigrationProgressMonitoring.logProgress(
            correlationId,
            'MigrationBatchJob',
            'START',
            'Batch job started. CorrelationId: ' + correlationId
        );
        return Database.getQueryLocator(
            'SELECT Id, Name, Status__c, Record_Count__c, Snapshot_Time__c ' +
            'FROM ARMT_Snapshot__c ' +
            'WHERE Status__c = \'In Progress\''
        );
    }

    /**
     * Processes a single batch of ARMT_Snapshot__c records. Updates each
     * record's Status__c to 'Complete' and increments success/error counters.
     *
     * @param  bc      The batch context provided by the platform.
     * @param  scope   The list of ARMT_Snapshot__c records in this batch.
     *
     * @calledBy    Salesforce Batch Framework
     * @testMethods test_execute_successPath_incrementsSuccessCount,
     *              test_execute_bulkRecords_processesAll,
     *              test_execute_dmlException_incrementsErrorCount
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<ARMT_Snapshot__c> snapshotsToUpdate = new List<ARMT_Snapshot__c>();
        List<String> errorMessages = new List<String>();

        for (SObject record : scope) {
            ARMT_Snapshot__c snap = (ARMT_Snapshot__c) record;
            try {
                snap.Status__c = 'Complete';
                snapshotsToUpdate.add(snap);
            } catch (Exception ex) {
                errorCount++;
                errorMessages.add('Record ' + snap.Id + ': ' + ex.getMessage());
            }
        }

        if (!snapshotsToUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(snapshotsToUpdate, false);
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    successCount++;
                } else {
                    errorCount++;
                    for (Database.Error err : sr.getErrors()) {
                        errorMessages.add(err.getMessage());
                    }
                }
            }
        }

        if (!errorMessages.isEmpty()) {
            MigrationProgressMonitoring.logProgress(
                correlationId,
                'MigrationBatchJob',
                'EXECUTE_ERRORS',
                String.join(errorMessages, '; ')
            );
        }
    }

    /**
     * Called by the platform after all batches have been processed. Logs the
     * final summary of success and error counts.
     *
     * @param  bc  The batch context provided by the platform.
     *
     * @calledBy    Salesforce Batch Framework
     * @testMethods test_finish_logsCompletion
     */
    public void finish(Database.BatchableContext bc) {
        String summary = 'MigrationBatchJob finished. CorrelationId: ' + correlationId
            + ' | Success: ' + successCount
            + ' | Errors: ' + errorCount;

        MigrationProgressMonitoring.logProgress(
            correlationId,
            'MigrationBatchJob',
            'FINISH',
            summary
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Accessors (for test assertions)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns the current success count. Exposed for test assertions.
     *
     * @return Integer count of successfully processed records.
     *
     * @calledBy    TestMigrationBatchJob
     * @testMethods test_execute_successPath_incrementsSuccessCount
     */
    public Integer getSuccessCount() {
        return successCount;
    }

    /**
     * Returns the current error count. Exposed for test assertions.
     *
     * @return Integer count of records that failed processing.
     *
     * @calledBy    TestMigrationBatchJob
     * @testMethods test_execute_dmlException_incrementsErrorCount
     */
    public Integer getErrorCount() {
        return errorCount;
    }
}
