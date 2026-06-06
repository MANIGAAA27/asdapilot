/**
 * @file        ARMT_PreMigrationValidatorTest.cls
 * @description Tests ARMT_PreMigrationValidator — covers invocable validation,
 *              single-record validation, severity derivation, summary building,
 *              finding gathering, and error-path handling.
 * @testFor     ARMT_PreMigrationValidator
 * @coverage    Target ≥ 90%.
 */
@isTest
private class ARMT_PreMigrationValidatorTest {

    // ─── Test Data Setup ──────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        // No shared DML needed; each test creates its own data.
    }

    // ─── runValidation (InvocableMethod) ─────────────────────────────────────

    /**
     * Validates that a request with no source objects produces an INFO-status report.
     */
    @isTest
    static void test_runValidation_noSourceObjects_returnsInfoStatus() {
        ARMT_PreMigrationValidator.ValidationRequest req =
            new ARMT_PreMigrationValidator.ValidationRequest();
        req.reportId = 'RPT-001';
        req.summaryPrefix = null;
        req.sourceObjectNames = null;

        Test.startTest();
        List<ARMT_PreMigrationValidator.ValidationResult> results =
            ARMT_PreMigrationValidator.runValidation(
                new List<ARMT_PreMigrationValidator.ValidationRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly one result.');
        ARMT_PreMigrationValidator.ValidationResult res = results[0];
        System.assertEquals(
            ARMT_PreMigrationValidator.STATUS_PASS,
            res.overallStatus,
            'Expected INFO status when no source objects provided.'
        );
        System.assertEquals(0, res.blockerCount, 'Expected 0 blockers.');
        System.assertNotEquals(null, res.validationReportId, 'Expected a report Id to be set.');

        // Verify the record was actually inserted
        List<ARMT_ValidationReport__c> reports = [
            SELECT Id, Report_Id__c, Validation_Status__c
            FROM   ARMT_ValidationReport__c
            WHERE  Report_Id__c = 'RPT-001'
        ];
        System.assertEquals(1, reports.size(), 'Expected one ARMT_ValidationReport__c record.');
        System.assertEquals('INFO', reports[0].Validation_Status__c, 'Expected INFO status on record.');
    }

    /**
     * Validates that a request with a valid standard object produces an INFO finding.
     */
    @isTest
    static void test_runValidation_validStandardObject_returnsInfoStatus() {
        ARMT_PreMigrationValidator.ValidationRequest req =
            new ARMT_PreMigrationValidator.ValidationRequest();
        req.reportId = 'RPT-002';
        req.sourceObjectNames = new List<String>{ 'Account' };

        Test.startTest();
        List<ARMT_PreMigrationValidator.ValidationResult> results =
            ARMT_PreMigrationValidator.runValidation(
                new List<ARMT_PreMigrationValidator.ValidationRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one result.');
        System.assertEquals(
            ARMT_PreMigrationValidator.STATUS_PASS,
            results[0].overallStatus,
            'Account is a valid object; expected INFO status.'
        );
        System.assertEquals(0, results[0].blockerCount, 'Expected 0 blockers for Account.');
    }

    /**
     * Validates that a non-existent object name produces a BLOCKER finding.
     */
    @isTest
    static void test_runValidation_nonExistentObject_returnsBlockerStatus() {
        ARMT_PreMigrationValidator.ValidationRequest req =
            new ARMT_PreMigrationValidator.ValidationRequest();
        req.reportId = 'RPT-003';
        req.sourceObjectNames = new List<String>{ 'NonExistentObject__xyz' };

        Test.startTest();
        List<ARMT_PreMigrationValidator.ValidationResult> results =
            ARMT_PreMigrationValidator.runValidation(
                new List<ARMT_PreMigrationValidator.ValidationRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one result.');
        System.assertEquals(
            ARMT_PreMigrationValidator.STATUS_BLOCKER,
            results[0].overallStatus,
            'Non-existent object should produce BLOCKER status.'
        );
        System.assertEquals(1, results[0].blockerCount, 'Expected 1 blocker.');
    }

    /**
     * Validates bulk processing: two requests in one invocation both produce reports.
     */
    @isTest
    static void test_runValidation_bulkRequests_allReportsCreated() {
        List<ARMT_PreMigrationValidator.ValidationRequest> requests =
            new List<ARMT_PreMigrationValidator.ValidationRequest>();

        for (Integer i = 0; i < 5; i++) {
            ARMT_PreMigrationValidator.ValidationRequest req =
                new ARMT_PreMigrationValidator.ValidationRequest();
            req.reportId = 'BULK-RPT-' + i;
            req.sourceObjectNames = new List<String>{ 'Account' };
            requests.add(req);
        }

        Test.startTest();
        List<ARMT_PreMigrationValidator.ValidationResult> results =
            ARMT_PreMigrationValidator.runValidation(requests);
        Test.stopTest();

        System.assertEquals(5, results.size(), 'Expected 5 results for 5 requests.');
        for (ARMT_PreMigrationValidator.ValidationResult res : results) {
            System.assertNotEquals(null, res.validationReportId, 'Each result must have a report Id.');
        }

        Integer reportCount = [
            SELECT COUNT()
            FROM   ARMT_ValidationReport__c
            WHERE  Report_Id__c LIKE 'BULK-RPT-%'
        ];
        System.assertEquals(5, reportCount, 'Expected 5 ARMT_ValidationReport__c records inserted.');
    }

    /**
     * Validates that a summary prefix is prepended to the generated summary.
     */
    @isTest
    static void test_runValidation_withSummaryPrefix_prefixAppearsInSummary() {
        ARMT_PreMigrationValidator.ValidationRequest req =
            new ARMT_PreMigrationValidator.ValidationRequest();
        req.reportId = 'RPT-PREFIX-001';
        req.summaryPrefix = 'Migration Job MJ-00001:';
        req.sourceObjectNames = new List<String>{ 'Account' };

        Test.startTest();
        List<ARMT_PreMigrationValidator.ValidationResult> results =
            ARMT_PreMigrationValidator.runValidation(
                new List<ARMT_PreMigrationValidator.ValidationRequest>{ req }
            );
        Test.stopTest();

        System.assert(
            results[0].summary.startsWith('Migration Job MJ-00001:'),
            'Summary should start with the provided prefix.'
        );
    }

    // ─── validateSingle ───────────────────────────────────────────────────────

    /**
     * Validates that validateSingle creates a report and returns a result.
     */
    @isTest
    static void test_validateSingle_validRequest_createsReport() {
        ARMT_PreMigrationValidator.ValidationRequest req =
            new ARMT_PreMigrationValidator.ValidationRequest();
        req.reportId = 'SINGLE-RPT-001';
        req.sourceObjectNames = new List<String>{ 'Contact' };

        Test.startTest();
        ARMT_PreMigrationValidator.ValidationResult res =
            ARMT_PreMigrationValidator.validateSingle(req);
        Test.stopTest();

        System.assertNotEquals(null, res.validationReportId, 'Expected a report Id.');
        System.assertEquals(
            ARMT_PreMigrationValidator.STATUS_PASS,
            res.overallStatus,
            'Contact is valid; expected INFO status.'
        );
    }

    /**
     * Validates that validateSingle throws an exception when reportId is blank.
     */
    @isTest
    static void test_validateSingle_blankReportId_throwsException() {
        ARMT_PreMigrationValidator.ValidationRequest req =
            new ARMT_PreMigrationValidator.ValidationRequest();
        req.reportId = '';
        req.sourceObjectNames = new List<String>{ 'Account' };

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ARMT_PreMigrationValidator.validateSingle(req);
        } catch (ARMT_PreMigrationValidator.ARMT_PreMigrationValidatorException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected ARMT_PreMigrationValidatorException for blank reportId.');
    }

    // ─── getReportsByReportId ─────────────────────────────────────────────────

    /**
     * Validates that getReportsByReportId returns records for a known report ID.
     */
    @isTest
    static void test_getReportsByReportId_existingId_returnsRecords() {
        ARMT_ValidationReport__c report = new ARMT_ValidationReport__c(
            Report_Id__c         = 'QUERY-RPT-001',
            Summary__c           = 'Test summary',
            Validation_Status__c = 'INFO'
        );
        insert report;

        Test.startTest();
        List<ARMT_ValidationReport__c> results =
            ARMT_PreMigrationValidator.getReportsByReportId('QUERY-RPT-001');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one record for known report ID.');
        System.assertEquals('QUERY-RPT-001', results[0].Report_Id__c, 'Report ID should match.');
    }

    /**
     * Validates that getReportsByReportId returns an empty list for an unknown ID.
     */
    @isTest
    static void test_getReportsByReportId_unknownId_returnsEmpty() {
        Test.startTest();
        List<ARMT_ValidationReport__c> results =
            ARMT_PreMigrationValidator.getReportsByReportId('DOES-NOT-EXIST-XYZ');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected empty list for unknown report ID.');
    }

    // ─── Private helper coverage via @TestVisible ─────────────────────────────

    /**
     * Validates deriveOverallStatus returns BLOCKER when a blocker finding exists.
     */
    @isTest
    static void test_deriveOverallStatus_withBlocker_returnsBlocker() {
        List<ARMT_PreMigrationValidator.ValidationFinding> findings =
            new List<ARMT_PreMigrationValidator.ValidationFinding>{
                new ARMT_PreMigrationValidator.ValidationFinding('BLOCKER', 'Blocker msg', 'Obj1'),
                new ARMT_PreMigrationValidator.ValidationFinding('INFO', 'Info msg', null)
            };

        Test.startTest();
        String status = ARMT_PreMigrationValidator.deriveOverallStatus(findings);
        Test.stopTest();

        System.assertEquals('BLOCKER', status, 'Expected BLOCKER when a blocker finding is present.');
    }

    /**
     * Validates deriveOverallStatus returns WARNING when only warnings exist.
     */
    @isTest
    static void test_deriveOverallStatus_warningOnly_returnsWarning() {
        List<ARMT_PreMigrationValidator.ValidationFinding> findings =
            new List<ARMT_PreMigrationValidator.ValidationFinding>{
                new ARMT_PreMigrationValidator.ValidationFinding('WARNING', 'Warning msg', 'Obj2')
            };

        Test.startTest();
        String status = ARMT_PreMigrationValidator.deriveOverallStatus(findings);
        Test.stopTest();

        System.assertEquals('WARNING', status, 'Expected WARNING when only warning findings present.');
    }

    /**
     * Validates deriveOverallStatus returns INFO when only info findings exist.
     */
    @isTest
    static void test_deriveOverallStatus_infoOnly_returnsInfo() {
        List<ARMT_PreMigrationValidator.ValidationFinding> findings =
            new List<ARMT_PreMigrationValidator.ValidationFinding>{
                new ARMT_PreMigrationValidator.ValidationFinding('INFO', 'Info msg', null)
            };

        Test.startTest();
        String status = ARMT_PreMigrationValidator.deriveOverallStatus(findings);
        Test.stopTest();

        System.assertEquals('INFO', status, 'Expected INFO when only info findings present.');
    }

    /**
     * Validates gatherFindings returns INFO for a valid standard object.
     */
    @isTest
    static void test_gatherFindings_validObject_returnsInfoFinding() {
        Test.startTest();
        List<ARMT_PreMigrationValidator.ValidationFinding> findings =
            ARMT_PreMigrationValidator.gatherFindings(new List<String>{ 'Account' });
        Test.stopTest();

        System.assertEquals(1, findings.size(), 'Expected one finding for Account.');
        System.assertEquals('INFO', findings[0].severity, 'Expected INFO severity for Account.');
    }

    /**
     * Validates gatherFindings returns BLOCKER for a non-existent object.
     */
    @isTest
    static void test_gatherFindings_nonExistentObject_returnsBlockerFinding() {
        Test.startTest();
        List<ARMT_PreMigrationValidator.ValidationFinding> findings =
            ARMT_PreMigrationValidator.gatherFindings(
                new List<String>{ 'CompletelyFakeObject__zzz' }
            );
        Test.stopTest();

        System.assertEquals(1, findings.size(), 'Expected one finding.');
        System.assertEquals('BLOCKER', findings[0].severity, 'Expected BLOCKER for non-existent object.');
    }

    /**
     * Validates buildSummary includes prefix and finding counts.
     */
    @isTest
    static void test_buildSummary_withPrefixAndFindings_formatsCorrectly() {
        List<ARMT_PreMigrationValidator.ValidationFinding> findings =
            new List<ARMT_PreMigrationValidator.ValidationFinding>{
                new ARMT_PreMigrationValidator.ValidationFinding('BLOCKER', 'B1', null),
                new ARMT_PreMigrationValidator.ValidationFinding('WARNING', 'W1', null),
                new ARMT_PreMigrationValidator.ValidationFinding('INFO', 'I1', null)
            };

        Test.startTest();
        String summary = ARMT_PreMigrationValidator.buildSummary('PREFIX:', findings);
        Test.stopTest();

        System.assert(summary.startsWith('PREFIX:'), 'Summary should start with prefix.');
        System.assert(summary.contains('Blockers: 1'), 'Summary should contain blocker count.');
        System.assert(summary.contains('Warnings: 1'), 'Summary should contain warning count.');
        System.assert(summary.contains('Info: 1'), 'Summary should contain info count.');
    }
}
