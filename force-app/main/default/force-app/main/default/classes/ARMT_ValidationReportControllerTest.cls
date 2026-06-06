/**
 * @file        ARMT_ValidationReportControllerTest.cls
 * @description Tests ARMT_ValidationReportController — covers filtered and
 *              unfiltered retrieval of ARMT_ValidationReport__c records.
 * @testFor     ARMT_ValidationReportController
 * @coverage    Target ≥ 90%.
 */
@isTest
private class ARMT_ValidationReportControllerTest {

    @TestSetup
    static void makeData() {
        List<ARMT_ValidationReport__c> reports = new List<ARMT_ValidationReport__c>{
            new ARMT_ValidationReport__c(
                Report_Id__c         = 'CTRL-RPT-001',
                Summary__c           = 'First report summary',
                Validation_Status__c = 'INFO'
            ),
            new ARMT_ValidationReport__c(
                Report_Id__c         = 'CTRL-RPT-002',
                Summary__c           = 'Second report summary',
                Validation_Status__c = 'BLOCKER'
            )
        };
        insert reports;
    }

    /**
     * Validates that getValidationReports with no filter returns all records.
     */
    @isTest
    static void test_getValidationReports_noFilter_returnsAll() {
        Test.startTest();
        List<ARMT_ValidationReport__c> results =
            ARMT_ValidationReportController.getValidationReports(null);
        Test.stopTest();

        System.assert(results.size() >= 2, 'Expected at least 2 records with no filter.');
    }

    /**
     * Validates that getValidationReports with a specific ID returns only matching records.
     */
    @isTest
    static void test_getValidationReports_withFilter_returnsFiltered() {
        Test.startTest();
        List<ARMT_ValidationReport__c> results =
            ARMT_ValidationReportController.getValidationReports('CTRL-RPT-001');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly one record for CTRL-RPT-001.');
        System.assertEquals('CTRL-RPT-001', results[0].Report_Id__c, 'Report ID should match filter.');
    }

    /**
     * Validates that getValidationReports with an unknown ID returns an empty list.
     */
    @isTest
    static void test_getValidationReports_unknownId_returnsEmpty() {
        Test.startTest();
        List<ARMT_ValidationReport__c> results =
            ARMT_ValidationReportController.getValidationReports('DOES-NOT-EXIST-999');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected empty list for unknown report ID.');
    }

    /**
     * Validates that getValidationReports with an empty string returns all records.
     */
    @isTest
    static void test_getValidationReports_emptyString_returnsAll() {
        Test.startTest();
        List<ARMT_ValidationReport__c> results =
            ARMT_ValidationReportController.getValidationReports('');
        Test.stopTest();

        System.assert(results.size() >= 2, 'Expected at least 2 records for empty string filter.');
    }
}
