/**
 * @file              MigrationProgressMonitoring.cls
 * @description       Utility class for logging and retrieving real-time migration
 *                    progress. Provides static methods for writing progress entries
 *                    to a structured in-memory log and retrieving them for UI
 *                    consumption or test assertions.
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
 * Utility for logging and retrieving migration progress entries.
 *
 * Responsibilities:
 *   - Accept structured log entries from batch and service classes.
 *   - Store entries in a static list for retrieval within the same transaction.
 *   - Provide retrieval methods for test assertions and UI polling.
 *
 * Threading: Static state is transaction-scoped; not safe across async boundaries.
 *
 * @testClass TestMigrationProgressMonitoring
 */
public with sharing class MigrationProgressMonitoring {

    /** In-memory log of progress entries for the current transaction. */
    @TestVisible
    private static List<ProgressEntry> progressLog = new List<ProgressEntry>();

    // ─────────────────────────────────────────────────────────────────────────
    // Inner Types
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Represents a single progress log entry with correlation context,
     * source class, event type, and descriptive message.
     */
    public class ProgressEntry {
        /** Correlation identifier linking this entry to a migration job. */
        public String correlationId { get; private set; }
        /** Name of the class that generated this entry. */
        public String sourceClass   { get; private set; }
        /** Short event type label (e.g. START, EXECUTE_ERRORS, FINISH). */
        public String eventType     { get; private set; }
        /** Human-readable message describing the event. */
        public String message       { get; private set; }
        /** Timestamp when the entry was created. */
        public DateTime loggedAt    { get; private set; }

        /** Constructs a ProgressEntry with all required fields. */
        public ProgressEntry(String correlationId, String sourceClass, String eventType, String message) {
            this.correlationId = correlationId;
            this.sourceClass   = sourceClass;
            this.eventType     = eventType;
            this.message       = message;
            this.loggedAt      = System.now();
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Appends a progress entry to the in-memory log.
     *
     * @param  correlationId  Identifier linking this entry to a migration job.
     * @param  sourceClass    Name of the calling class.
     * @param  eventType      Short label for the event (e.g. 'START', 'FINISH').
     * @param  message        Descriptive message for the event.
     *
     * @calledBy    MigrationBatchJob
     * @testMethods test_logProgress_validEntry_addsToLog,
     *              test_logProgress_nullMessage_handledGracefully
     */
    public static void logProgress(String correlationId, String sourceClass, String eventType, String message) {
        String safeMessage = String.isBlank(message) ? '(no message)' : message;
        progressLog.add(new ProgressEntry(correlationId, sourceClass, eventType, safeMessage));
    }

    /**
     * Returns all progress entries recorded in the current transaction.
     *
     * @return Unmodifiable list of ProgressEntry records. Never null; may be empty.
     *
     * @calledBy    TestMigrationProgressMonitoring
     * @testMethods test_getProgressLog_afterLogging_returnsEntries
     */
    public static List<ProgressEntry> getProgressLog() {
        return progressLog.clone();
    }

    /**
     * Returns progress entries filtered by correlation identifier.
     *
     * @param  correlationId  The identifier to filter by.
     * @return List of ProgressEntry records matching the given correlationId.
     *         Never null; may be empty.
     *
     * @calledBy    TestMigrationProgressMonitoring
     * @testMethods test_getProgressByCorrelationId_matchingId_returnsFiltered,
     *              test_getProgressByCorrelationId_noMatch_returnsEmpty
     */
    public static List<ProgressEntry> getProgressByCorrelationId(String correlationId) {
        List<ProgressEntry> filtered = new List<ProgressEntry>();
        for (ProgressEntry entry : progressLog) {
            if (entry.correlationId == correlationId) {
                filtered.add(entry);
            }
        }
        return filtered;
    }

    /**
     * Clears the in-memory progress log. Intended for use in test setup/teardown.
     *
     * @calledBy    TestMigrationProgressMonitoring
     * @testMethods test_clearLog_afterLogging_logIsEmpty
     */
    public static void clearLog() {
        progressLog.clear();
    }

    /**
     * Returns the total number of entries currently in the log.
     *
     * @return Integer count of log entries.
     *
     * @calledBy    TestMigrationProgressMonitoring
     * @testMethods test_getLogSize_afterMultipleEntries_returnsCorrectCount
     */
    public static Integer getLogSize() {
        return progressLog.size();
    }
}
