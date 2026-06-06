/**
 * @file              MigrationProgressMonitoring.cls
 * @description       Utility class for logging and retrieving real-time migration progress.
 *                    Provides methods to log progress entries to ARMT_AuditLog__c and retrieve
 *                    current progress metrics for display in the migration dashboard.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ARMT_Utilities
 *
 * @dependencies      DataAccessException
 * @calledBy          MigrationBatchJob
 * @testClass         TestMigrationProgressMonitoring
 *
 * @see               HLD-ARMT-V1.0 Section 3.3, HLD-CMP-008
 */

/**
 * Utility class for logging and retrieving real-time migration progress.
 *
 * Responsibilities:
 *   - Log progress entries to ARMT_AuditLog__c with action, details, and timestamp.
 *   - Retrieve recent audit log entries for a given context.
 *   - Provide progress summary metrics (total logged, latest action).
 *   - Enforce FLS via WITH SECURITY_ENFORCED on all queries.
 *
 * Threading: Safe for use in both synchronous and asynchronous (batch) contexts.
 *
 * @testClass TestMigrationProgressMonitoring
 */
public with sharing class MigrationProgressMonitoring {

    /** Maximum number of audit log entries to retrieve per query. */
    @TestVisible
    private static final Integer MAX_LOG_RETRIEVAL = 200;

    /**
     * Logs a progress entry to ARMT_AuditLog__c.
     *
     * @param  action   The action picklist value (e.g., 'Migration Started').
     * @param  details  The detailed description of the progress event.
     * @return The Id of the inserted ARMT_AuditLog__c record.
     * @throws DataAccessException when the DML insert fails.
     *
     * @calledBy MigrationBatchJob
     * @testMethods test_logProgress_validInput_insertsAuditLog, test_logProgress_nullDetails_insertsWithNullDetails
     */
    public Id logProgress(String action, String details) {
        if (String.isBlank(action)) {
            throw new DataAccessException('Action is required to log migration progress.');
        }

        ARMT_AuditLog__c logEntry = new ARMT_AuditLog__c(
            Action__c = action,
            Details__c = details,
            Timestamp__c = System.now(),
            User__c = UserInfo.getUserId()
        );

        try {
            insert logEntry;
            return logEntry.Id;
        } catch (DmlException de) {
            throw new DataAccessException('Failed to insert audit log entry: ' + de.getMessage());
        }
    }

    /**
     * Retrieves recent ARMT_AuditLog__c entries ordered by timestamp descending.
     *
     * @param  limitCount  Maximum number of entries to retrieve (capped at MAX_LOG_RETRIEVAL).
     * @return List of ARMT_AuditLog__c records ordered by Timestamp__c descending.
     * @throws DataAccessException when the SOQL query fails.
     *
     * @calledBy (none in this changeset)
     * @testMethods test_getRecentLogs_returnsOrderedEntries, test_getRecentLogs_emptyOrg_returnsEmpty
     */
    public List<ARMT_AuditLog__c> getRecentLogs(Integer limitCount) {
        Integer safeLimit = (limitCount == null || limitCount <= 0 || limitCount > MAX_LOG_RETRIEVAL)
            ? MAX_LOG_RETRIEVAL
            : limitCount;

        try {
            return [
                SELECT Id, Action__c, Details__c, Timestamp__c, User__c
                FROM ARMT_AuditLog__c
                WITH SECURITY_ENFORCED
                ORDER BY Timestamp__c DESC
                LIMIT :safeLimit
            ];
        } catch (System.QueryException qe) {
            throw new DataAccessException('Failed to retrieve audit log entries: ' + qe.getMessage());
        }
    }

    /**
     * Returns a progress summary containing the count of log entries and the latest action.
     *
     * @return ProgressSummary wrapper with totalEntries and latestAction fields.
     * @throws DataAccessException when the SOQL query fails.
     *
     * @calledBy (none in this changeset)
     * @testMethods test_getProgressSummary_withLogs_returnsCorrectSummary, test_getProgressSummary_noLogs_returnsZeroCount
     */
    public ProgressSummary getProgressSummary() {
        ProgressSummary summary = new ProgressSummary();
        try {
            List<AggregateResult> countResult = [
                SELECT COUNT(Id) totalCount
                FROM ARMT_AuditLog__c
                WITH SECURITY_ENFORCED
            ];
            if (!countResult.isEmpty()) {
                summary.totalEntries = (Integer) countResult[0].get('totalCount');
            }

            List<ARMT_AuditLog__c> latestEntry = [
                SELECT Action__c, Timestamp__c
                FROM ARMT_AuditLog__c
                WITH SECURITY_ENFORCED
                ORDER BY Timestamp__c DESC
                LIMIT 1
            ];
            if (!latestEntry.isEmpty()) {
                summary.latestAction = latestEntry[0].Action__c;
                summary.latestTimestamp = latestEntry[0].Timestamp__c;
            }
        } catch (System.QueryException qe) {
            throw new DataAccessException('Failed to retrieve progress summary: ' + qe.getMessage());
        }
        return summary;
    }

    // ─── Inner Classes ────────────────────────────────────────────────────────

    /**
     * Wrapper class summarizing migration progress metrics.
     */
    public class ProgressSummary {
        /** Total number of audit log entries. */
        public Integer totalEntries;
        /** The action from the most recent audit log entry. */
        public String latestAction;
        /** The timestamp of the most recent audit log entry. */
        public Datetime latestTimestamp;

        /** Constructs an empty ProgressSummary. */
        public ProgressSummary() {
            this.totalEntries = 0;
            this.latestAction = null;
            this.latestTimestamp = null;
        }
    }
}
