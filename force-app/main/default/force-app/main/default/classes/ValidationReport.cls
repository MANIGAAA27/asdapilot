/**
 * @file              ValidationReport.cls
 * @description       Generates validation reports from mapping validation results.
 *                    Aggregates ARMT_ValidationReport__c records, computes severity
 *                    summaries, and provides structured report data for LWC consumption
 *                    and PDF output generation.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             PreMigrationValidation
 *
 * @dependencies      (none)
 * @calledBy          (none in this changeset)
 * @testClass         ValidationReportTest
 *
 * @see               HLD-CMP-003 ValidationService
 */

/**
 * Service class for generating and retrieving validation reports.
 *
 * Responsibilities:
 *   - Create ARMT_ValidationReport__c records from validation input.
 *   - Aggregate severity counts (BLOCKER, WARNING, INFO) across a report set.
 *   - Retrieve existing reports by ID or context.
 *   - Provide a summary string suitable for PDF or UI rendering.
 *
 * Threading: Designed for synchronous invocation. Bulk-safe up to 200 records.
 *
 * @testClass ValidationReportTest
 */
public with sharing class ValidationReport {

    /** Severity constant for blocking issues. */
    public static final String SEVERITY_BLOCKER = 'BLOCKER';
    /** Severity constant for warning-level issues. */
    public static final String SEVERITY_WARNING = 'WARNING';
    /** Severity constant for informational entries. */
    public static final String SEVERITY_INFO = 'INFO';

    // ─────────────────────────────────────────────────────────────────────────
    // Inner types
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * DTO encapsulating the aggregated summary of a validation report set.
     */
    public class ReportSummary {
        /** Total number of BLOCKER-severity entries. */
        public Integer blockerCount;
        /** Total number of WARNING-severity entries. */
        public Integer warningCount;
        /** Total number of INFO-severity entries. */
        public Integer infoCount;
        /** Overall status: BLOCKER if any blockers exist, WARNING if warnings only, INFO otherwise. */
        public String overallStatus;
        /** Human-readable summary text. */
        public String summaryText;

        /** Default constructor initialising counts to zero. */
        public ReportSummary() {
            blockerCount = 0;
            warningCount = 0;
            infoCount = 0;
            overallStatus = SEVERITY_INFO;
            summaryText = '';
        }
    }

    /**
     * Input DTO for creating a single validation report entry.
     */
    public class ValidationReportInput {
        /** Unique identifier for this report (caller-assigned). */
        public String reportId;
        /** Severity level: BLOCKER, WARNING, or INFO. */
        public String validationStatus;
        /** Human-readable summary of the validation finding. */
        public String summary;

        /** Default constructor. */
        public ValidationReportInput() {}
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates ARMT_ValidationReport__c records from the provided input list.
     * Performs a bulk insert with partial success; callers should inspect
     * SaveResult.isSuccess() for each entry.
     *
     * @param  inputs  List of ValidationReportInput DTOs to persist.
     * @return         List of Database.SaveResult, one per input. Empty list
     *                 when inputs is null or empty.
     * @calledBy    (none in this changeset)
     * @testMethods test_createReports_insertsRecords, test_createReports_emptyInput_returnsEmpty
     */
    public List<Database.SaveResult> createReports(List<ValidationReportInput> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            return new List<Database.SaveResult>();
        }

        List<ARMT_ValidationReport__c> records = new List<ARMT_ValidationReport__c>();

        for (ValidationReportInput input : inputs) {
            ARMT_ValidationReport__c rec = new ARMT_ValidationReport__c(
                Name = truncateName(input.reportId),
                Report_Id__c = input.reportId,
                Validation_Status__c = input.validationStatus,
                Summary__c = input.summary
            );
            records.add(rec);
        }

        return Database.insert(records, false);
    }

    /**
     * Retrieves ARMT_ValidationReport__c records matching the provided report IDs.
     *
     * @param  reportIds  Set of Report_Id__c values to query.
     * @return            List of matching ARMT_ValidationReport__c records.
     *                    Empty list when reportIds is null or empty.
     * @calledBy    (none in this changeset)
     * @testMethods test_getReportsByIds_returnsMatchingRecords, test_getReportsByIds_emptySet_returnsEmpty
     */
    public List<ARMT_ValidationReport__c> getReportsByIds(Set<String> reportIds) {
        if (reportIds == null || reportIds.isEmpty()) {
            return new List<ARMT_ValidationReport__c>();
        }

        return [
            SELECT Id, Name, Report_Id__c, Validation_Status__c, Summary__c
            FROM ARMT_ValidationReport__c
            WHERE Report_Id__c IN :reportIds
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * Computes an aggregated ReportSummary from a list of ARMT_ValidationReport__c
     * records. Determines overall status based on the highest severity present.
     *
     * @param  reports  List of ARMT_ValidationReport__c records to summarise.
     * @return          ReportSummary DTO. Never returns null.
     * @calledBy    (none in this changeset)
     * @testMethods test_buildSummary_withBlockers_returnsBlockerStatus,
     *              test_buildSummary_noBlockers_returnsWarningOrInfo,
     *              test_buildSummary_emptyList_returnsInfoStatus
     */
    public ReportSummary buildSummary(List<ARMT_ValidationReport__c> reports) {
        ReportSummary summary = new ReportSummary();

        if (reports == null || reports.isEmpty()) {
            summary.summaryText = 'No validation results found.';
            return summary;
        }

        for (ARMT_ValidationReport__c rep : reports) {
            String status = rep.Validation_Status__c;
            if (SEVERITY_BLOCKER.equalsIgnoreCase(status)) {
                summary.blockerCount++;
            } else if (SEVERITY_WARNING.equalsIgnoreCase(status)) {
                summary.warningCount++;
            } else {
                summary.infoCount++;
            }
        }

        if (summary.blockerCount > 0) {
            summary.overallStatus = SEVERITY_BLOCKER;
        } else if (summary.warningCount > 0) {
            summary.overallStatus = SEVERITY_WARNING;
        } else {
            summary.overallStatus = SEVERITY_INFO;
        }

        summary.summaryText =
            'Validation complete. ' +
            'Blockers: ' + summary.blockerCount +
            ' | Warnings: ' + summary.warningCount +
            ' | Info: ' + summary.infoCount +
            ' | Overall: ' + summary.overallStatus;

        return summary;
    }

    /**
     * Generates a plain-text report string suitable for PDF rendering or
     * email delivery. Includes all report entries formatted with their
     * severity and summary.
     *
     * @param  reports  List of ARMT_ValidationReport__c records to include.
     * @return          Formatted report string. Returns a placeholder message
     *                  when the input list is empty.
     * @calledBy    (none in this changeset)
     * @testMethods test_generateTextReport_formatsCorrectly, test_generateTextReport_emptyList_returnsPlaceholder
     */
    public String generateTextReport(List<ARMT_ValidationReport__c> reports) {
        if (reports == null || reports.isEmpty()) {
            return 'No validation data available for report generation.';
        }

        List<String> lines = new List<String>();
        lines.add('=== ARMT Validation Report ===');
        lines.add('Generated: ' + System.now().format());
        lines.add('Total Entries: ' + reports.size());
        lines.add('');

        for (ARMT_ValidationReport__c rep : reports) {
            lines.add('[' + rep.Validation_Status__c + '] ' + rep.Report_Id__c);
            lines.add('  Summary: ' + rep.Summary__c);
            lines.add('');
        }

        return String.join(lines, '\n');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Truncates a string to 80 characters for use as a Name field value. */
    private static String truncateName(String raw) {
        if (raw == null) {
            return 'REPORT';
        }
        return raw.length() > 80 ? raw.substring(0, 80) : raw;
    }
}
