/**
 * @file        ValidationReportTest.cls
 * @description Tests ValidationReport — covers report creation, retrieval,
 *              summary aggregation, text generation, and edge cases.
 * @testFor     ValidationReport
 * @coverage    Target ≥ 90%.
 */
@isTest
private class ValidationReportTest {

    @testSetup
    static void setupData() {
        List<ARMT_ValidationReport__c> reports = new List<ARMT_ValidationReport__c>{
            new ARMT_ValidationReport__c(
                Name = 'RPT-001',
                Report_Id__c = 'RPT-001',
                Validation_Status__c = 'BLOCKER',
                Summary__c = 'Missing required field mapping.'
            ),
            new ARMT_ValidationReport__c(
                Name = 'RPT-002',
                Report_Id__c = 'RPT-002',
                Validation_Status__c = 'WARNING',
                Summary__c = 'Confidence score below threshold.'
            ),
            new ARMT_ValidationReport__c(
                Name = 'RPT-003',
                Report_Id__c = 'RPT-003',
                Validation_Status__c = 'INFO',
                Summary__c = 'Optional field not mapped.'
            )
        };
        insert reports;
    }

    @isTest
    static void test_createReports_insertsRecords() {
        ValidationReport svc = new ValidationReport();

        ValidationReport.ValidationReportInput input = new ValidationReport.ValidationReportInput();
        input.reportId = 'RPT-NEW-001';
        input.validationStatus = 'INFO';
        input.summary = 'Test report entry.';

        Test.startTest();
        List<Database.SaveResult> results = svc.createReports(
            new List<ValidationReport.ValidationReportInput>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should have one save result');
        System.assert(results[0].isSuccess(), 'Insert should succeed: ' +
            (results[0].getErrors().isEmpty() ? '' : results[0].getErrors()[0].getMessage()));
    }

    @isTest
    static void test_createReports_emptyInput_returnsEmpty() {
        ValidationReport svc = new ValidationReport();

        Test.startTest();
        List<Database.SaveResult> results = svc.createReports(
            new List<ValidationReport.ValidationReportInput>()
        );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty input should return empty results');
    }

    @isTest
    static void test_createReports_nullInput_returnsEmpty() {
        ValidationReport svc = new ValidationReport();

        Test.startTest();
        List<Database.SaveResult> results = svc.createReports(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Null input should return empty results');
    }

    @isTest
    static void test_getReportsByIds_returnsMatchingRecords() {
        ValidationReport svc = new ValidationReport();

        Test.startTest();
        List<ARMT_ValidationReport__c> reports = svc.getReportsByIds(
            new Set<String>{ 'RPT-001', 'RPT-002' }
        );
        Test.stopTest();

        System.assertEquals(2, reports.size(), 'Should return 2 matching reports');
    }

    @isTest
    static void test_getReportsByIds_emptySet_returnsEmpty() {
        ValidationReport svc = new ValidationReport();

        Test.startTest();
        List<ARMT_ValidationReport__c> reports = svc.getReportsByIds(new Set<String>());
        Test.stopTest();

        System.assertEquals(0, reports.size(), 'Empty set should return empty list');
    }

    @isTest
    static void test_getReportsByIds_nullSet_returnsEmpty() {
        ValidationReport svc = new ValidationReport();

        Test.startTest();
        List<ARMT_ValidationReport__c> reports = svc.getReportsByIds(null);
        Test.stopTest();

        System.assertEquals(0, reports.size(), 'Null set should return empty list');
    }

    @isTest
    static void test_buildSummary_withBlockers_returnsBlockerStatus() {
        ValidationReport svc = new ValidationReport();
        List<ARMT_ValidationReport__c> reports = [
            SELECT Id, Validation_Status__c, Report_Id__c, Summary__c
            FROM ARMT_ValidationReport__c
        ];

        Test.startTest();
        ValidationReport.ReportSummary summary = svc.buildSummary(reports);
        Test.stopTest();

        System.assertEquals('BLOCKER', summary.overallStatus,
            'Overall status should be BLOCKER when blockers exist');
        System.assertEquals(1, summary.blockerCount, 'Should count 1 blocker');
        System.assertEquals(1, summary.warningCount, 'Should count 1 warning');
        System.assertEquals(1, summary.infoCount, 'Should count 1 info');
    }

    @isTest
    static void test_buildSummary_emptyList_returnsInfoStatus() {
        ValidationReport svc = new ValidationReport();

        Test.startTest();
        ValidationReport.ReportSummary summary = svc.buildSummary(
            new List<ARMT_ValidationReport__c>()
        );
        Test.stopTest();

        System.assertEquals('INFO', summary.overallStatus,
            'Empty list should default to INFO status');
        System.assertEquals(0, summary.blockerCount, 'Blocker count should be 0');
    }

    @isTest
    static void test_buildSummary_noBlockers_returnsWarningOrInfo() {
        ValidationReport svc = new ValidationReport();
        List<ARMT_ValidationReport__c> reports = new List<ARMT_ValidationReport__c>{
            new ARMT_ValidationReport__c(
                Name = 'W1',
                Report_Id__c = 'W1',
                Validation_Status__c = 'WARNING',
                Summary__c = 'Warning only.'
            )
        };
        insert reports;

        List<ARMT_ValidationReport__c> queried = [
            SELECT Id, Validation_Status__c, Report_Id__c, Summary__c
            FROM ARMT_ValidationReport__c
            WHERE Report_Id__c = 'W1'
        ];

        Test.startTest();
        ValidationReport.ReportSummary summary = svc.buildSummary(queried);
        Test.stopTest();

        System.assertEquals('WARNING', summary.overallStatus,
            'Status should be WARNING when no blockers exist');
    }

    @isTest
    static void test_generateTextReport_formatsCorrectly() {
        ValidationReport svc = new ValidationReport();
        List<ARMT_ValidationReport__c> reports = [
            SELECT Id, Validation_Status__c, Report_Id__c, Summary__c
            FROM ARMT_ValidationReport__c
            WHERE Report_Id__c = 'RPT-001'
        ];

        Test.startTest();
        String reportText = svc.generateTextReport(reports);
        Test.stopTest();

        System.assert(reportText.contains('ARMT Validation Report'),
            'Report should contain header');
        System.assert(reportText.contains('BLOCKER'),
            'Report should contain severity');
        System.assert(reportText.contains('RPT-001'),
            'Report should contain report ID');
    }

    @isTest
    static void test_generateTextReport_emptyList_returnsPlaceholder() {
        ValidationReport svc = new ValidationReport();

        Test.startTest();
        String reportText = svc.generateTextReport(new List<ARMT_ValidationReport__c>());
        Test.stopTest();

        System.assert(reportText.contains('No validation data'),
            'Empty list should return placeholder message');
    }
}
