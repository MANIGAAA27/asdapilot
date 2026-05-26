/**
 * @file        CaseSummaryTransferServiceTest.cls
 * @description Tests CaseSummaryTransferService — verifies that
 *              initiateSummaryGeneration enqueues the queueable which in turn
 *              produces a Case_Transfer_Summary__c record when the LLM mock succeeds.
 * @testFor     CaseSummaryTransferService
 * @coverage    Target ≥ 90%.
 */
@isTest
private class CaseSummaryTransferServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acc = TestDataFactory.createAccount('Transfer Service Test Account');
        TestDataFactory.createCase('Transfer Service Test Case', acc.Id, null);
    }

    @isTest
    static void test_initiateSummaryGeneration_validCaseId_enqueuedSuccessfully() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new LLMCalloutServiceMock());

        Test.startTest();
        CaseSummaryTransferService.initiateSummaryGeneration(testCase.Id, System.now());
        Test.stopTest();

        // stopTest flushes the queueable synchronously
        List<Case_Transfer_Summary__c> summaries = [
            SELECT Id, Generation_Status__c
            FROM   Case_Transfer_Summary__c
            WHERE  Case__c = :testCase.Id
        ];
        System.assert(!summaries.isEmpty(),
            'initiateSummaryGeneration must result in a summary record being created');
        System.assertEquals('Success', summaries[0].Generation_Status__c,
            'Summary must have Success status when LLM mock returns a valid response');
    }

    @isTest
    static void test_initiateSummaryGeneration_whenLLMFails_createsSummaryWithFailedStatus() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new LLMCalloutServiceMockFailure());

        Test.startTest();
        CaseSummaryTransferService.initiateSummaryGeneration(testCase.Id, System.now());
        Test.stopTest();

        List<Case_Transfer_Summary__c> summaries = [
            SELECT Id, Generation_Status__c
            FROM   Case_Transfer_Summary__c
            WHERE  Case__c = :testCase.Id
        ];
        System.assertEquals(1, summaries.size(),
            'A summary record must be created even when the LLM service fails');
        System.assertEquals('Failed', summaries[0].Generation_Status__c,
            'Generation_Status__c must be Failed when the LLM endpoint returns an error');
    }
}