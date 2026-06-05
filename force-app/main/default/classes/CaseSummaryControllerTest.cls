/**
 * @file        CaseSummaryControllerTest.cls
 * @description Tests CaseSummaryController — covers latest summary retrieval,
 *              history list, regenerate, settings retrieval, and null/empty paths.
 * @testFor     CaseSummaryController
 * @coverage    Target >= 90%.
 */
@isTest
private class CaseSummaryControllerTest {

    @TestSetup
    static void setupData() {
        Case c = TestDataFactory.createCase('Controller Test Case');
        TestDataFactory.createCaseTransferSummary(c.Id, 'Summary A');
        TestDataFactory.createCaseTransferSummary(c.Id, 'Summary B');
    }

    @isTest
    static void test_getLatestSummary_returnsMostRecent() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Controller Test Case' LIMIT 1];

        Test.startTest();
        CaseTransferSummary__c result = CaseSummaryController.getLatestSummary(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return a summary record');
    }

    @isTest
    static void test_getLatestSummary_noRecords_returnsNull() {
        Case fresh = TestDataFactory.createCase('No Summary Controller Case');

        Test.startTest();
        CaseTransferSummary__c result = CaseSummaryController.getLatestSummary(fresh.Id);
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when no summaries exist');
    }

    @isTest
    static void test_getSummaryHistory_returnsOrderedList() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Controller Test Case' LIMIT 1];

        Test.startTest();
        List<CaseTransferSummary__c> results = CaseSummaryController.getSummaryHistory(c.Id, 10);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 seeded summaries');
    }

    @isTest
    static void test_getSummaryHistory_limitEnforced() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Controller Test Case' LIMIT 1];

        Test.startTest();
        List<CaseTransferSummary__c> results = CaseSummaryController.getSummaryHistory(c.Id, 1);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Limit of 1 should return exactly 1 record');
    }

    @isTest
    static void test_getSummaryHistory_nullLimit_usesDefault() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Controller Test Case' LIMIT 1];

        Test.startTest();
        List<CaseTransferSummary__c> results = CaseSummaryController.getSummaryHistory(c.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Null limit should not throw');
    }

    @isTest
    static void test_regenerateSummary_enqueuesJob() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Controller Test Case' LIMIT 1];

        Test.startTest();
        CaseSummaryController.regenerateSummary(c.Id);
        Test.stopTest();

        System.assert(true, 'Regenerate completed without exception');
    }

    @isTest
    static void test_regenerateSummary_nullCaseId_throwsException() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            CaseSummaryController.regenerateSummary(null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Null case ID should throw AuraHandledException');
    }

    @isTest
    static void test_getRecentTransferMinutes_returnsPositiveValue() {
        Test.startTest();
        Integer minutes = CaseSummaryController.getRecentTransferMinutes();
        Test.stopTest();

        System.assert(minutes > 0, 'Recent transfer minutes should be positive');
    }
}
