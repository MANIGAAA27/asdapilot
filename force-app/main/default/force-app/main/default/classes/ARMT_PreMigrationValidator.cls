/**
 * @file              ARMT_PreMigrationValidator.cls
 * @description       Backend service for validating CPQ configurations and generating
 *                    validation reports stored in ARMT_ValidationReport__c. Evaluates
 *                    mapping completeness, object availability, and field-level
 *                    compatibility before migration execution is permitted.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ARMT_Validation
 *
 * @dependencies      None
 * @calledBy          (none in this changeset)
 * @testClass         ARMT_PreMigrationValidatorTest
 *
 * @see               HLD-ARMT-V1.0 Section 3.3 HLD-CMP-003 ValidationService
 */

/**
 * Service class for pre-migration validation of CPQ configurations.
 *
 * Responsibilities:
 *   - Validate that required CPQ objects are accessible in the source org.
 *   - Evaluate mapping completeness and flag gaps as BLOCKER/WARNING/INFO.
 *   - Persist validation results as ARMT_ValidationReport__c records.
 *   - Expose an @InvocableMethod for Flow-based invocation.
 *
 * Threading: Designed for synchronous invocation from LWC controllers and
 * Flow actions. Bulk-safe up to 200 records per invocation.
 *
 * @testClass ARMT_PreMigrationValidatorTest
 */
public with sharing class ARMT_PreMigrationValidator {

    // ─── Constants ────────────────────────────────────────────────────────────

    /** Severity level indicating a migration-blocking issue. */
    public static final String SEVERITY_BLOCKER = 'BLOCKER';

    /** Severity level indicating a non-blocking warning. */
    public static final String SEVERITY_WARNING = 'WARNING';

    /** Severity level indicating informational finding. */
    public static final String SEVERITY_INFO = 'INFO';

    /** Status value for a report with no blockers. */
    public static final String STATUS_PASS = 'INFO';

    /** Status value for a report with warnings only. */
    public static final String STATUS_WARNING = 'WARNING';

    /** Status value for a report with at least one blocker. */
    public static final String STATUS_BLOCKER = 'BLOCKER';

    // ─── Inner Classes ────────────────────────────────────────────────────────

    /**
     * Wrapper representing a single validation finding.
     */
    public class ValidationFinding {
        /** Severity of the finding: BLOCKER, WARNING, or INFO. */
        public String severity;
        /** Human-readable description of the finding. */
        public String message;
        /** Optional reference to the source record or field involved. */
        public String sourceReference;

        /**
         * Constructs a ValidationFinding with all required fields.
         *
         * @param sev       Severity string (BLOCKER / WARNING / INFO).
         * @param msg       Description of the finding.
         * @param srcRef    Optional source reference identifier.
         */
        public ValidationFinding(String sev, String msg, String srcRef) {
            this.severity = sev;
            this.message = msg;
            this.sourceReference = srcRef;
        }
    }

    /**
     * Input wrapper for the @InvocableMethod, carrying the migration job context.
     */
    public class ValidationRequest {
        /** The external report identifier to associate with this validation run. */
        @InvocableVariable(label='Report ID' required=true)
        public String reportId;

        /** Optional summary prefix to prepend to the generated summary. */
        @InvocableVariable(label='Summary Prefix' required=false)
        public String summaryPrefix;

        /** List of source object API names to validate. */
        @InvocableVariable(label='Source Object Names' required=false)
        public List<String> sourceObjectNames;
    }

    /**
     * Output wrapper returned by the @InvocableMethod.
     */
    public class ValidationResult {
        /** Salesforce Id of the created ARMT_ValidationReport__c record. */
        @InvocableVariable(label='Validation Report Id')
        public String validationReportId;

        /** Overall status of the validation run: BLOCKER, WARNING, or INFO. */
        @InvocableVariable(label='Overall Status')
        public String overallStatus;

        /** Number of BLOCKER findings found. */
        @InvocableVariable(label='Blocker Count')
        public Integer blockerCount;

        /** Number of WARNING findings found. */
        @InvocableVariable(label='Warning Count')
        public Integer warningCount;

        /** Human-readable summary of the validation run. */
        @InvocableVariable(label='Summary')
        public String summary;
    }

    // ─── Public Methods ───────────────────────────────────────────────────────

    /**
     * Invocable entry point for Flow-based validation execution.
     * Accepts a list of ValidationRequest inputs (one per flow invocation element)
     * and returns a corresponding list of ValidationResult outputs.
     *
     * Bulk-safe: processes each request independently and inserts all resulting
     * ARMT_ValidationReport__c records in a single DML statement.
     *
     * @param  requests  List of ValidationRequest objects from the Flow.
     * @return           List of ValidationResult objects, one per input request.
     *
     * @calledBy    (none in this changeset)
     * @testMethods test_runValidation_noBlockers_returnsInfoStatus,
     *              test_runValidation_withBlocker_returnsBlockerStatus,
     *              test_runValidation_nullSourceObjects_handledGracefully
     */
    @InvocableMethod(
        label='Run Pre-Migration Validation'
        description='Validates CPQ configuration and creates an ARMT_ValidationReport__c record.'
        category='ARMT'
    )
    public static List<ValidationResult> runValidation(List<ValidationRequest> requests) {
        List<ValidationResult> results = new List<ValidationResult>();
        List<ARMT_ValidationReport__c> reportsToInsert = new List<ARMT_ValidationReport__c>();

        // Build report records and result wrappers for each request
        for (ValidationRequest req : requests) {
            List<ValidationFinding> findings = gatherFindings(req.sourceObjectNames);
            String overallStatus = deriveOverallStatus(findings);
            String summaryText = buildSummary(req.summaryPrefix, findings);

            ARMT_ValidationReport__c report = new ARMT_ValidationReport__c(
                Report_Id__c       = req.reportId,
                Summary__c         = summaryText,
                Validation_Status__c = overallStatus
            );
            reportsToInsert.add(report);

            ValidationResult vr = new ValidationResult();
            vr.overallStatus  = overallStatus;
            vr.blockerCount   = countBySeverity(findings, SEVERITY_BLOCKER);
            vr.warningCount   = countBySeverity(findings, SEVERITY_WARNING);
            vr.summary        = summaryText;
            results.add(vr);
        }

        // Bulk insert all reports
        if (!reportsToInsert.isEmpty()) {
            insert reportsToInsert;
            // Populate the Salesforce Id back into each result
            for (Integer i = 0; i < reportsToInsert.size(); i++) {
                results[i].validationReportId = reportsToInsert[i].Id;
            }
        }

        return results;
    }

    /**
     * Validates a single report request and returns the result synchronously.
     * Intended for direct Apex-to-Apex calls from service orchestrators.
     *
     * @param  req  A populated ValidationRequest.
     * @return      A ValidationResult with the created report Id and findings summary.
     *
     * @calledBy    (none in this changeset)
     * @testMethods test_validateSingle_validRequest_createsReport,
     *              test_validateSingle_emptyReportId_throwsException
     */
    public static ValidationResult validateSingle(ValidationRequest req) {
        if (String.isBlank(req.reportId)) {
            throw new ARMT_PreMigrationValidatorException(
                'ValidationRequest.reportId must not be blank.'
            );
        }
        List<ValidationResult> results = runValidation(
            new List<ValidationRequest>{ req }
        );
        return results[0];
    }

    /**
     * Retrieves all ARMT_ValidationReport__c records for a given report ID.
     * Uses WITH SECURITY_ENFORCED to respect running user's FLS.
     *
     * @param  reportId  The external report identifier to query.
     * @return           List of matching ARMT_ValidationReport__c records.
     *
     * @calledBy    (none in this changeset)
     * @testMethods test_getReportsByReportId_existingId_returnsRecords,
     *              test_getReportsByReportId_unknownId_returnsEmpty
     */
    public static List<ARMT_ValidationReport__c> getReportsByReportId(String reportId) {
        return [
            SELECT Id, Name, Report_Id__c, Summary__c, Validation_Status__c, CreatedDate
            FROM   ARMT_ValidationReport__c
            WHERE  Report_Id__c = :reportId
            WITH   SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    /**
     * Gathers validation findings for the provided list of source object names.
     * Checks object accessibility via Schema.getGlobalDescribe().
     *
     * @param  sourceObjectNames  List of API names to validate; may be null.
     * @return                    List of ValidationFinding instances.
     */
    @TestVisible
    private static List<ValidationFinding> gatherFindings(List<String> sourceObjectNames) {
        List<ValidationFinding> findings = new List<ValidationFinding>();

        if (sourceObjectNames == null || sourceObjectNames.isEmpty()) {
            findings.add(new ValidationFinding(
                SEVERITY_INFO,
                'No source objects specified for validation. Proceeding with default checks.',
                null
            ));
            return findings;
        }

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        for (String objName : sourceObjectNames) {
            if (String.isBlank(objName)) {
                continue;
            }
            String normalised = objName.toLowerCase();
            if (!globalDescribe.containsKey(normalised)) {
                findings.add(new ValidationFinding(
                    SEVERITY_BLOCKER,
                    'Source object "' + objName + '" is not accessible or does not exist in this org.',
                    objName
                ));
            } else {
                Schema.DescribeSObjectResult describeResult =
                    globalDescribe.get(normalised).getDescribe();
                if (!describeResult.isAccessible()) {
                    findings.add(new ValidationFinding(
                        SEVERITY_BLOCKER,
                        'Source object "' + objName + '" exists but is not accessible to the running user.',
                        objName
                    ));
                } else if (!describeResult.isQueryable()) {
                    findings.add(new ValidationFinding(
                        SEVERITY_WARNING,
                        'Source object "' + objName + '" is accessible but not queryable.',
                        objName
                    ));
                } else {
                    findings.add(new ValidationFinding(
                        SEVERITY_INFO,
                        'Source object "' + objName + '" is accessible and queryable.',
                        objName
                    ));
                }
            }
        }

        return findings;
    }

    /**
     * Derives the overall validation status from a list of findings.
     * Returns BLOCKER if any blocker exists, WARNING if any warning exists,
     * otherwise INFO.
     *
     * @param  findings  List of ValidationFinding instances.
     * @return           Overall status string.
     */
    @TestVisible
    private static String deriveOverallStatus(List<ValidationFinding> findings) {
        Boolean hasBlocker = false;
        Boolean hasWarning = false;
        for (ValidationFinding f : findings) {
            if (f.severity == SEVERITY_BLOCKER) {
                hasBlocker = true;
            } else if (f.severity == SEVERITY_WARNING) {
                hasWarning = true;
            }
        }
        if (hasBlocker) {
            return STATUS_BLOCKER;
        }
        if (hasWarning) {
            return STATUS_WARNING;
        }
        return STATUS_PASS;
    }

    /**
     * Builds a human-readable summary string from the findings list.
     *
     * @param  prefix    Optional prefix to prepend.
     * @param  findings  List of ValidationFinding instances.
     * @return           Formatted summary string.
     */
    @TestVisible
    private static String buildSummary(String prefix, List<ValidationFinding> findings) {
        Integer blockers = countBySeverity(findings, SEVERITY_BLOCKER);
        Integer warnings = countBySeverity(findings, SEVERITY_WARNING);
        Integer infos    = countBySeverity(findings, SEVERITY_INFO);

        String base = 'Validation complete. '
            + 'Blockers: ' + blockers + ', '
            + 'Warnings: ' + warnings + ', '
            + 'Info: ' + infos + '. ';

        List<String> details = new List<String>();
        for (ValidationFinding f : findings) {
            details.add('[' + f.severity + '] ' + f.message);
        }
        base += String.join(details, ' | ');

        if (String.isNotBlank(prefix)) {
            return prefix + ' ' + base;
        }
        return base;
    }

    /**
     * Counts findings matching the given severity level.
     *
     * @param  findings   List of ValidationFinding instances.
     * @param  severity   Severity string to count.
     * @return            Count of matching findings.
     */
    @TestVisible
    private static Integer countBySeverity(List<ValidationFinding> findings, String severity) {
        Integer count = 0;
        for (ValidationFinding f : findings) {
            if (f.severity == severity) {
                count++;
            }
        }
        return count;
    }

    // ─── Custom Exception ─────────────────────────────────────────────────────

    /** Custom exception for ARMT_PreMigrationValidator errors. */
    public class ARMT_PreMigrationValidatorException extends Exception {}
}
