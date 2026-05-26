/**
 * @file        CaseSummaryControllerTest.cls
 * @description Tests CaseSummaryController — verifies that getLatestSummary
 *              returns the correct record when one exists and returns null when
 *              the case has no successful summary.
 * @testFor     CaseSummaryController
 * @coverage    Target ≥ 90%.
 */
@isTest
private class CaseSummaryControllerTest {

    @TestSetup
    static void setupTestData() {
        Account acc = TestDataFactory.createAccount('Controller Test Account');
        Case testCase = TestDataFactory.createCase('Controller Test Case', acc.Id, null);
        TestDataFactory.createCaseTransferSummary(
            testCase.Id,
            'Customer reported login failure. Agent reset credentials. Awaiting confirmation.'
        );
    }

    @isTest
    static void test_getLatestSummary_existingSummary_returnsSummary() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Controller Test Case' LIMIT 1];

        Test.startTest();
        Case_Transfer_Summary__c result = CaseSummaryController.getLatestSummary(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,
            'getLatestSummary must return a record when a successful summary exists');
        System.assert(result.Summary_Text__c.length() > 0,
            'Summary_Text__c must be populated');
        System.assertEquals('Success', result.Generation_Status__c,
            'Only Success records should be returned');
    }

    @isTest
    static void test_getLatestSummary_noSummaryExists_returnsNull() {
        Account acc = TestDataFactory.createAccount('Empty Summary Account');
        Case emptyCase = TestDataFactory.createCase('No Summary Case', acc.Id, null);

        Test.startTest();
        Case_Transfer_Summary__c result = CaseSummaryController.getLatestSummary(emptyCase.Id);
        Test.stopTest();

        System.assertEquals(null, result,
            'getLatestSummary must return null when no successful summary exists for the Case');
    }

    @isTest
    static void test_getLatestSummary_multipleRecords_returnsLatest() {
        Account acc = TestDataFactory.createAccount('Multi Summary Account');
        Case testCase = TestDataFactory.createCase('Multi Summary Case', acc.Id, null);

        // Insert an older summary
        Case_Transfer_Summary__c older = new Case_Transfer_Summary__c(
            Case__c               = testCase.Id,
            Summary_Text__c       = 'Older summary text',
            Transfer_Timestamp__c = System.now().addHours(-2),
            Model_Name__c         = 'gpt-4',
            Model_Version__c      = '1.0',
            Generation_Status__c  = 'Success'
        );
        insert older;

        // Insert a newer summary
        Case_Transfer_Summary__c newer = new Case_Transfer_Summary__c(
            Case__c               = testCase.Id,
            Summary_Text__c       = 'Newer summary text',
            Transfer_Timestamp__c = System.now(),
            Model_Name__c         = 'gpt-4',
            Model_Version__c      = '1.0',
            Generation_Status__c  = 'Success'
        );
        insert newer;

        Test.startTest();
        Case_Transfer_Summary__c result = CaseSummaryController.getLatestSummary(testCase.Id);
        Test.stopTest();

        System.assertEquals('Newer summary text', result.Summary_Text__c,
            'getLatestSummary must return the most recent record when multiple summaries exist');
    }
}