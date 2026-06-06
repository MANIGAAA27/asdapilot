/**
 * @file        ARMT_ValidationReportTest.cls
 * @description Tests ARMT_ValidationReportController — covers validation report generation,
 *              filtering by status, retrieval by ID, and empty org behavior.
 * @testFor     ARMT_ValidationReportController
 * @coverage    Target ≥ 90%.
 */
@isTest
private class ARMT_ValidationReportTest {

    /**
     * Tests that getValidationReports with no filter returns all records.
     */
    @isTest
    static void test_getValidationReports_noFilter_returnsAll() {
        ARMT_TestDataFactory.createValidationReport('RPT-001', 'BLOCKER', 'Blocker summary');
        ARMT_TestDataFactory.createValidationReport('RPT-002', 'WARNING', 'Warning summary');
        ARMT_TestDataFactory.createValidationReport('RPT-003', 'INFO', 'Info summary');

        Test.startTest();
        List<ARMT_ValidationReport__c> results = ARMT_ValidationReportController.getValidationReports(null);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Expected 3 validation reports with no filter');
    }

    /**
     * Tests that getValidationReports with BLOCKER filter returns only BLOCKER records.
     */
    @isTest
    static void test_getValidationReports_blockerFilter_returnsBlockers() {
        ARMT_TestDataFactory.createValidationReport('RPT-B01', 'BLOCKER', 'Blocker 1');
        ARMT_TestDataFactory.createValidationReport('RPT-B02', 'BLOCKER', 'Blocker 2');
        ARMT_TestDataFactory.createValidationReport('RPT-W01', 'WARNING', 'Warning 1');

        Test.startTest();
        List<ARMT_ValidationReport__c> results = ARMT_ValidationReportController.getValidationReports('BLOCKER');
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Expected 2 BLOCKER validation reports');
        for (ARMT_ValidationReport__c r : results) {
            System.assertEquals('BLOCKER', r.Validation_Status__c, 'Expected all results to be BLOCKER');
        }
    }

    /**
     * Tests that getValidationReports with WARNING filter returns only WARNING records.
     */
    @isTest
    static void test_getValidationReports_warningFilter_returnsWarnings() {
        ARMT_TestDataFactory.createValidationReport('RPT-W02', 'WARNING', 'Warning only');
        ARMT_TestDataFactory.createValidationReport('RPT-I01', 'INFO', 'Info only');

        Test.startTest();
        List<ARMT_ValidationReport__c> results = ARMT_ValidationReportController.getValidationReports('WARNING');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected 1 WARNING validation report');
        System.assertEquals('WARNING', results[0].Validation_Status__c, 'Expected WARNING status');
    }

    /**
     * Tests that getValidationReports returns empty list when no records exist.
     */
    @isTest
    static void test_getValidationReports_emptyOrg_returnsEmpty() {
        Test.startTest();
        List<ARMT_ValidationReport__c> results = ARMT_ValidationReportController.getValidationReports(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected empty list when no validation reports exist');
    }

    /**
     * Tests that getReportById returns the correct record for a valid Report_Id__c.
     */
    @isTest
    static void test_getReportById_validId_returnsRecord() {
        ARMT_TestDataFactory.createValidationReport('RPT-FIND-001', 'INFO', 'Find me by ID');

        Test.startTest();
        ARMT_ValidationReport__c result = ARMT_ValidationReportController.getReportById('RPT-FIND-001');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Expected a non-null result for valid Report_Id__c');
        System.assertEquals('RPT-FIND-001', result.Report_Id__c, 'Expected matching Report_Id__c');
        System.assertEquals('INFO', result.Validation_Status__c, 'Expected INFO status');
    }

    /**
     * Tests that getReportById returns null for a non-existent Report_Id__c.
     */
    @isTest
    static void test_getReportById_invalidId_returnsNull() {
        Test.startTest();
        ARMT_ValidationReport__c result = ARMT_ValidationReportController.getReportById('RPT-NONEXISTENT');
        Test.stopTest();

        System.assertEquals(null, result, 'Expected null for non-existent Report_Id__c');
    }

    /**
     * Tests that getReportById with blank ID returns null without error.
     */
    @isTest
    static void test_getReportById_blankId_returnsNull() {
        Test.startTest();
        ARMT_ValidationReport__c result = ARMT_ValidationReportController.getReportById('');
        Test.stopTest();

        System.assertEquals(null, result, 'Expected null for blank Report_Id__c');
    }

    /**
     * Tests bulk retrieval of 200 validation reports.
     */
    @isTest
    static void test_getValidationReports_bulk200_returnsAll() {
        ARMT_TestDataFactory.createValidationReports(200, 'INFO');

        Test.startTest();
        List<ARMT_ValidationReport__c> results = ARMT_ValidationReportController.getValidationReports(null);
        Test.stopTest();

        System.assertEquals(200, results.size(), 'Expected 200 validation reports in bulk retrieval');
    }

    /**
     * Tests that getValidationReports with empty string filter returns all records.
     */
    @isTest
    static void test_getValidationReports_emptyStringFilter_returnsAll() {
        ARMT_TestDataFactory.createValidationReport('RPT-ES-001', 'BLOCKER', 'Empty string filter test');

        Test.startTest();
        List<ARMT_ValidationReport__c> results = ARMT_ValidationReportController.getValidationReports('');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected 1 record with empty string filter');
    }
}
