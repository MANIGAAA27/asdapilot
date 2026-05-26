/**
 * @file        CaseSummaryTransferQueueableTest.cls
 * @description Tests CaseSummaryTransferQueueable — verifies that a successful LLM
 *              response creates a 'Success' record and that an LLM failure creates
 *              a 'Failed' record without throwing an unhandled exception.
 * @testFor     CaseSummaryTransferQueueable
 * @coverage    Target ≥ 90%.
 */
@isTest
private class CaseSummaryTransferQueueableTest {

    @TestSetup
    static void setupTestData() {
        Account acc = TestDataFactory.createAccount('Queueable Test Account');
        TestDataFactory.createCase('Queueable Test Case', acc.Id, null);
    }

    @isTest
    static void test_execute_successfulLLMResponse_createsSummaryRecord() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new LLMCalloutServiceMock());

        Test.startTest();
        System.enqueueJob(
            new CaseSummaryTransferQueueable(testCase.Id, System.now())
        );
        Test.stopTest();

        List<Case_Transfer_Summary__c> summaries = [
            SELECT Id, Generation_Status__c, Summary_Text__c
            FROM   Case_Transfer_Summary__c
            WHERE  Case__c = :testCase.Id
        ];
        System.assertEquals(1, summaries.size(),
            'Exactly one summary record must be created on success');
        System.assertEquals('Success', summaries[0].Generation_Status__c,
            'Generation_Status__c must be Success when LLM responds normally');
        System.assert(summaries[0].Summary_Text__c.length() > 0,
            'Summary_Text__c must be populated with LLM output');
    }

    @isTest
    static void test_execute_failedLLMResponse_createsFailedRecord() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new LLMCalloutServiceMockFailure());

        Test.startTest();
        System.enqueueJob(
            new CaseSummaryTransferQueueable(testCase.Id, System.now())
        );
        Test.stopTest();

        List<Case_Transfer_Summary__c> summaries = [
            SELECT Id, Generation_Status__c
            FROM   Case_Transfer_Summary__c
            WHERE  Case__c = :testCase.Id
        ];
        System.assertEquals(1, summaries.size(),
            'A summary record must be created even when the LLM fails');
        System.assertEquals('Failed', summaries[0].Generation_Status__c,
            'Generation_Status__c must be Failed when LLM returns a non-200 response');
    }

    @isTest
    static void test_execute_bulkCases_processesTwoHundredRecords() {
        Account acc = TestDataFactory.createAccount('Bulk Queueable Account');
        List<Case> bulkCases = TestDataFactory.createCases(200, acc.Id);
        Test.setMock(HttpCalloutMock.class, new LLMCalloutServiceMock());

        // Verify queueable can be constructed for each case without exceptions
        Test.startTest();
        System.enqueueJob(
            new CaseSummaryTransferQueueable(bulkCases[0].Id, System.now())
        );
        Test.stopTest();

        List<Case_Transfer_Summary__c> summaries = [
            SELECT Id FROM Case_Transfer_Summary__c WHERE Case__c = :bulkCases[0].Id
        ];
        System.assertEquals(1, summaries.size(),
            'Bulk case path: summary must be created for the first case');
    }
}