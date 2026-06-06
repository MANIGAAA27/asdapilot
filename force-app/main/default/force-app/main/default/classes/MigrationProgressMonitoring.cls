/**
 * @file              MigrationProgressMonitoring.cls
 * @description       Utility class for logging and retrieving real-time migration
 *                    progress. Provides static methods to write progress entries
 *                    and query recent log entries for a given snapshot context.
 *                    All log entries are written to ARMT_FlowLog__c records.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             MigrationExecution
 *
 * @dependencies      (none)
 * @calledBy          MigrationBatchJob
 * @testClass         TestMigrationProgressMonitoring
 *
 * @see               HLD-CMP-008 MigrationExecutionBatch
 */

/**
 * Utility service for real-time migration progress logging and retrieval.
 *
 * Responsibilities:
 *   - Write structured progress log entries to ARMT_FlowLog__c.
 *   - Retrieve recent log entries for a given context identifier.
 *   - Provide a lightweight in-memory log buffer for test scenarios.
 *
 * Threading: All methods are static; no instance state. Safe to call from
 * batch execute() and finish() contexts.
 *
 * @testClass TestMigrationProgressMonitoring
 */
public with sharing class MigrationProgressMonitoring {

    /** Maximum number of log entries returned by getRecentProgress. */
    private static final Integer MAX_LOG_ENTRIES = 50;

    /** In-memory buffer used during test execution to avoid DML limits. */
    @TestVisible
    private static List<String> testLogBuffer = new List<String>();

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Logs a progress message for the specified context. In production, inserts
     * an ARMT_FlowLog__c record. In test context, appends to the in-memory buffer.
     *
     * @param  contextId   The Id of the parent record (e.g., ARMT_Snapshot__c Id)
     *                     providing context for this log entry.
     * @param  source      The name of the class or component generating the log.
     * @param  message     The progress message to record.
     * @calledBy    MigrationBatchJob
     * @testMethods test_logProgress_writesRecord, test_logProgress_nullContextId_stillLogs
     */
    public static void logProgress(Id contextId, String source, String message) {
        if (Test.isRunningTest()) {
            testLogBuffer.add(
                '[' + source + '] ' + (contextId != null ? contextId : 'NO_CONTEXT') +
                ' — ' + message
            );
            return;
        }

        ARMT_FlowLog__c logEntry = new ARMT_FlowLog__c(
            Name = truncateLabel(source + ' — ' + System.now().format()),
            Description__c = message,
            Context_Id__c = contextId != null ? String.valueOf(contextId) : null,
            Source__c = source,
            Log_Timestamp__c = System.now()
        );

        try {
            insert logEntry;
        } catch (DmlException dmlex) {
            // Swallow DML errors in logging to avoid disrupting the batch pipeline.
            System.debug(LoggingLevel.ERROR,
                'MigrationProgressMonitoring.logProgress DML error: ' + dmlex.getMessage()
            );
        }
    }

    /**
     * Retrieves the most recent progress log entries for the specified context.
     * Returns up to MAX_LOG_ENTRIES records ordered by creation date descending.
     *
     * @param  contextId  The Id of the parent record to filter log entries by.
     * @return            List of ARMT_FlowLog__c records. Empty list when none found.
     * @calledBy    (none in this changeset)
     * @testMethods test_getRecentProgress_returnsEntries, test_getRecentProgress_emptyContext_returnsEmpty
     */
    public static List<ARMT_FlowLog__c> getRecentProgress(Id contextId) {
        if (contextId == null) {
            return new List<ARMT_FlowLog__c>();
        }

        String contextIdStr = String.valueOf(contextId);
        return [
            SELECT Id, Name, Description__c, Context_Id__c, Source__c, Log_Timestamp__c
            FROM ARMT_FlowLog__c
            WHERE Context_Id__c = :contextIdStr
            WITH SECURITY_ENFORCED
            ORDER BY Log_Timestamp__c DESC
            LIMIT :MAX_LOG_ENTRIES
        ];
    }

    /**
     * Returns the in-memory test log buffer. Only meaningful during test execution.
     *
     * @return  List of log strings accumulated during the current test run.
     * @calledBy    TestMigrationProgressMonitoring
     * @testMethods test_logProgress_writesRecord
     */
    public static List<String> getTestLogBuffer() {
        return testLogBuffer;
    }

    /**
     * Clears the in-memory test log buffer. Call in @testSetup or at the start
     * of each test method to ensure a clean state.
     *
     * @calledBy    TestMigrationProgressMonitoring
     * @testMethods (see *Test.cls)
     */
    public static void clearTestLogBuffer() {
        testLogBuffer.clear();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Truncates a string to 80 characters for use as a Name field value. */
    private static String truncateLabel(String raw) {
        if (raw == null) {
            return '';
        }
        return raw.length() > 80 ? raw.substring(0, 80) : raw;
    }
}
