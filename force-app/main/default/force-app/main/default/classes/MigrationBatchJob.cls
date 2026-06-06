/**
 * @file              MigrationBatchJob.cls
 * @description       Batch job class that executes migration in configurable batches and handles
 *                    start, execute, and finish phases. Processes ARMT_SnapshotRecord__c records
 *                    in bulk, logs progress via MigrationProgressMonitoring, and handles errors
 *                    gracefully with audit logging.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ARMT_Batch
 *
 * @dependencies      MigrationProgressMonitoring, DataAccessException, ScanException
 * @calledBy          (none in this changeset — invoked from LWC Apex controller in future sprint)
 * @testClass         TestMigrationBatchJob
 *
 * @see               HLD-ARMT-V1.0 Section 5.3, HLD-CMP-008
 */

/**
 * Batchable Apex class for executing migration in configurable batches.
 *
 * Responsibilities:
 *   - Query ARMT_SnapshotRecord__c records in the start() method.
 *   - Process each batch in execute(), logging progress and errors.
 *   - Finalize migration status in finish(), logging completion.
 *   - Implement Database.Stateful to track cumulative success/error counts.
 *   - Enforce bulkification — no SOQL or DML inside loops.
 *
 * Threading: Asynchronous batch context. Implements Database.Stateful for
 * cross-batch state tracking.
 *
 * @testClass TestMigrationBatchJob
 */
public with sharing class MigrationBatchJob implements Database.Batchable<SObject>, Database.Stateful {

    /** Snapshot Id to scope the batch query. */
    @TestVisible
    private Id snapshotId;

    /** Cumulative count of successfully processed records. */
    @TestVisible
    private Integer successCount;

    /** Cumulative count of records that failed processing. */
    @TestVisible
    private Integer errorCount;

    /** List of error messages accumulated across batches. */
    @TestVisible
    private List<String> errorMessages;

    /** Progress monitoring utility instance. */
    @TestVisible
    private MigrationProgressMonitoring progressMonitor;

    /**
     * Constructs a MigrationBatchJob scoped to a specific snapshot.
     *
     * @param  snapshotId  The Id of the ARMT_Snapshot__c record to process.
     */
    public MigrationBatchJob(Id snapshotId) {
        this.snapshotId = snapshotId;
        this.successCount = 0;
        this.errorCount = 0;
        this.errorMessages = new List<String>();
        this.progressMonitor = new MigrationProgressMonitoring();
    }

    /**
     * Returns the query locator for ARMT_SnapshotRecord__c records scoped to the snapshot.
     *
     * @param  bc  The batch context provided by the platform.
     * @return Database.QueryLocator for ARMT_SnapshotRecord__c records.
     *
     * @calledBy Salesforce Batch Framework
     * @testMethods test_start_validSnapshotId_returnsQueryLocator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        progressMonitor.logProgress('Migration Started', 'Batch job started for snapshot: ' + snapshotId);
        return Database.getQueryLocator([
            SELECT Id, Record_Id__c, Record_JSON__c, Sequence__c, Snapshot__c
            FROM ARMT_SnapshotRecord__c
            WHERE Snapshot__c = :snapshotId
            ORDER BY Sequence__c ASC
        ]);
    }

    /**
     * Processes a batch of ARMT_SnapshotRecord__c records.
     * Validates each record and increments success or error counters.
     *
     * @param  bc      The batch context provided by the platform.
     * @param  scope   List of ARMT_SnapshotRecord__c records in this batch.
     *
     * @calledBy Salesforce Batch Framework
     * @testMethods test_execute_validRecords_incrementsSuccessCount, test_execute_invalidRecords_incrementsErrorCount
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<ARMT_SnapshotRecord__c> records = (List<ARMT_SnapshotRecord__c>) scope;
        List<String> batchErrors = new List<String>();

        for (ARMT_SnapshotRecord__c rec : records) {
            try {
                if (String.isBlank(rec.Record_JSON__c)) {
                    batchErrors.add('Record ' + rec.Record_Id__c + ' has blank JSON payload.');
                    errorCount++;
                    continue;
                }
                // Validate JSON is parseable
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(rec.Record_JSON__c);
                if (parsed == null) {
                    batchErrors.add('Record ' + rec.Record_Id__c + ' has unparseable JSON.');
                    errorCount++;
                    continue;
                }
                successCount++;
            } catch (Exception ex) {
                batchErrors.add('Error processing record ' + rec.Record_Id__c + ': ' + ex.getMessage());
                errorCount++;
            }
        }

        if (!batchErrors.isEmpty()) {
            errorMessages.addAll(batchErrors);
            String batchErrorDetail = String.join(batchErrors, '; ');
            try {
                progressMonitor.logProgress('Migration Paused', 'Batch errors: ' + batchErrorDetail.abbreviate(32000));
            } catch (Exception logEx) {
                // Do not rethrow — logging failure should not abort the batch
            }
        }
    }

    /**
     * Finalizes the batch job by logging completion status and updating the snapshot record.
     *
     * @param  bc  The batch context provided by the platform.
     *
     * @calledBy Salesforce Batch Framework
     * @testMethods test_finish_allSuccess_logsCompletion, test_finish_withErrors_logsErrors
     */
    public void finish(Database.BatchableContext bc) {
        String finishDetails = 'Batch completed. Success: ' + successCount + ', Errors: ' + errorCount;
        if (!errorMessages.isEmpty()) {
            finishDetails += '. First error: ' + errorMessages[0].abbreviate(500);
        }

        try {
            progressMonitor.logProgress('Migration Resumed', finishDetails);
        } catch (Exception logEx) {
            // Do not rethrow — logging failure should not abort finish
        }

        // Update snapshot status
        try {
            ARMT_Snapshot__c snap = new ARMT_Snapshot__c(
                Id = snapshotId,
                Status__c = (errorCount == 0) ? 'Complete' : 'In Progress',
                Record_Count__c = successCount
            );
            update snap;
        } catch (DmlException de) {
            // Log but do not rethrow — snapshot update failure is non-fatal
            try {
                progressMonitor.logProgress('Migration Paused', 'Failed to update snapshot status: ' + de.getMessage());
            } catch (Exception logEx) {
                // Swallow nested logging failure
            }
        }
    }

    /**
     * Returns the cumulative success count across all executed batches.
     *
     * @return Integer count of successfully processed records.
     *
     * @calledBy TestMigrationBatchJob
     * @testMethods test_getSuccessCount_afterExecution_returnsCorrectCount
     */
    public Integer getSuccessCount() {
        return this.successCount;
    }

    /**
     * Returns the cumulative error count across all executed batches.
     *
     * @return Integer count of records that failed processing.
     *
     * @calledBy TestMigrationBatchJob
     * @testMethods test_getErrorCount_afterExecution_returnsCorrectCount
     */
    public Integer getErrorCount() {
        return this.errorCount;
    }

    /**
     * Returns the list of error messages accumulated across all batches.
     *
     * @return List of error message strings.
     *
     * @calledBy TestMigrationBatchJob
     * @testMethods test_getErrorMessages_afterExecution_returnsMessages
     */
    public List<String> getErrorMessages() {
        return this.errorMessages;
    }
}
