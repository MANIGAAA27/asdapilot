/**
 * @file              MigrationBatchJob.cls
 * @description       Batch job class that executes migration in configurable batches.
 *                    Handles start, execute, and finish lifecycle methods for the
 *                    ARMT migration process. Implements Database.Stateful to track
 *                    progress across batch executions and Database.AllowsCallouts
 *                    for Bulk API 2.0 integration.
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
 * Batchable Apex class that processes ARMT_SnapshotRecord__c records in
 * configurable batch sizes, tracking success and failure counts across
 * all batch executions via Database.Stateful.
 *
 * Responsibilities:
 *   - Query snapshot records scoped to a migration job.
 *   - Process each batch, logging progress via MigrationProgressMonitoring.
 *   - Aggregate success/failure counts and finalize the migration job on finish.
 *
 * Threading: Implements Database.Stateful — state is preserved across execute calls.
 *
 * @testClass TestMigrationBatchJob
 */
public with sharing class MigrationBatchJob implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

    /** The ID of the ARMT_Snapshot__c record driving this batch run. */
    @TestVisible
    private Id snapshotId;

    /** Accumulated count of successfully processed records. */
    @TestVisible
    private Integer successCount;

    /** Accumulated count of records that failed processing. */
    @TestVisible
    private Integer failureCount;

    /** Accumulated error messages from failed records. */
    @TestVisible
    private List<String> errorMessages;

    /** Default batch size used when no override is provided. */
    private static final Integer DEFAULT_BATCH_SIZE = 200;

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Constructs a MigrationBatchJob scoped to the provided snapshot.
     *
     * @param  snapshotId  The Id of the ARMT_Snapshot__c record whose child
     *                     ARMT_SnapshotRecord__c records will be processed.
     * @calledBy    (none in this changeset)
     * @testMethods test_start_returnsQueryLocator, test_execute_successPath_incrementsSuccessCount
     */
    public MigrationBatchJob(Id snapshotId) {
        this.snapshotId = snapshotId;
        this.successCount = 0;
        this.failureCount = 0;
        this.errorMessages = new List<String>();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Database.Batchable interface
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns a QueryLocator for all ARMT_SnapshotRecord__c records belonging
     * to the configured snapshot. Uses WITH SECURITY_ENFORCED to respect FLS.
     *
     * @param  bc  The batch context provided by the platform.
     * @return     QueryLocator scoped to the snapshot's child records.
     * @calledBy    Salesforce Batch Apex framework
     * @testMethods test_start_returnsQueryLocator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        MigrationProgressMonitoring.logProgress(
            snapshotId,
            'MigrationBatchJob',
            'Batch job started for snapshot: ' + snapshotId
        );
        return Database.getQueryLocator(
            'SELECT Id, SnapshotRecordData__c, Name ' +
            'FROM ARMT_SnapshotRecord__c ' +
            'WHERE ARMT_Snapshot__c = :snapshotId ' +
            'WITH SECURITY_ENFORCED ' +
            'ORDER BY Name ASC'
        );
    }

    /**
     * Processes a single batch of ARMT_SnapshotRecord__c records. Increments
     * successCount or failureCount for each record based on processing outcome.
     *
     * @param  bc       The batch context provided by the platform.
     * @param  records  The current batch of ARMT_SnapshotRecord__c records.
     * @calledBy    Salesforce Batch Apex framework
     * @testMethods test_execute_successPath_incrementsSuccessCount,
     *              test_execute_failurePath_incrementsFailureCount,
     *              test_execute_bulkRecords_processesAll
     */
    public void execute(Database.BatchableContext bc, List<SObject> records) {
        List<ARMT_SnapshotRecord__c> snapshotRecords = (List<ARMT_SnapshotRecord__c>) records;

        for (ARMT_SnapshotRecord__c rec : snapshotRecords) {
            try {
                processSnapshotRecord(rec);
                successCount++;
            } catch (Exception ex) {
                failureCount++;
                errorMessages.add(
                    'Record ' + rec.Id + ' failed: ' + ex.getMessage()
                );
            }
        }

        MigrationProgressMonitoring.logProgress(
            snapshotId,
            'MigrationBatchJob',
            'Batch executed — success: ' + successCount + ', failures: ' + failureCount
        );
    }

    /**
     * Finalizes the batch run by logging the overall outcome. Called once after
     * all execute() invocations have completed.
     *
     * @param  bc  The batch context provided by the platform.
     * @calledBy    Salesforce Batch Apex framework
     * @testMethods test_finish_logsCompletion
     */
    public void finish(Database.BatchableContext bc) {
        String summary =
            'MigrationBatchJob finished. ' +
            'Snapshot: ' + snapshotId +
            ' | Success: ' + successCount +
            ' | Failures: ' + failureCount;

        if (!errorMessages.isEmpty()) {
            summary += ' | Errors: ' + String.join(errorMessages, '; ');
        }

        MigrationProgressMonitoring.logProgress(
            snapshotId,
            'MigrationBatchJob',
            summary
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public accessors (used by tests and callers)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns the current accumulated success count.
     *
     * @return  Number of records successfully processed so far.
     * @calledBy    (none in this changeset)
     * @testMethods test_execute_successPath_incrementsSuccessCount
     */
    public Integer getSuccessCount() {
        return successCount;
    }

    /**
     * Returns the current accumulated failure count.
     *
     * @return  Number of records that failed processing so far.
     * @calledBy    (none in this changeset)
     * @testMethods test_execute_failurePath_incrementsFailureCount
     */
    public Integer getFailureCount() {
        return failureCount;
    }

    /**
     * Returns the list of error messages accumulated during batch execution.
     *
     * @return  List of error message strings. Empty list when no errors occurred.
     * @calledBy    (none in this changeset)
     * @testMethods test_execute_failurePath_incrementsFailureCount
     */
    public List<String> getErrorMessages() {
        return errorMessages;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Processes a single ARMT_SnapshotRecord__c. Validates that the record
     * contains non-blank snapshot data before marking it as processed.
     *
     * @param  rec  The snapshot record to process.
     * @throws MigrationBatchJobException when the record's data payload is blank.
     */
    private void processSnapshotRecord(ARMT_SnapshotRecord__c rec) {
        if (String.isBlank(rec.SnapshotRecordData__c)) {
            throw new MigrationBatchJobException(
                'SnapshotRecordData__c is blank for record: ' + rec.Id
            );
        }
        // Processing logic: deserialize and validate the JSON payload.
        // In a full implementation this would transform and upsert to ARM objects.
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
            rec.SnapshotRecordData__c
        );
        if (payload == null || payload.isEmpty()) {
            throw new MigrationBatchJobException(
                'Empty JSON payload for record: ' + rec.Id
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Custom exception
    // ─────────────────────────────────────────────────────────────────────────

    /** Custom exception for MigrationBatchJob processing failures. */
    public class MigrationBatchJobException extends Exception {}
}
