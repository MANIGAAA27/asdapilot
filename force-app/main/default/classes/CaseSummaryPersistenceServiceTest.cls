/**
 * @file        CaseSummaryPersistenceServiceTest.cls
 * @description Tests CaseSummaryPersistenceService — verifies that success and
 *              failure summary records are correctly created with the right field values.
 * @testFor     CaseSummaryPersistenceService
 * @coverage    Target ≥ 90%.
 */
@isTest
private class CaseSummaryPersistenceServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acc = TestDataFactory.createAccount('Persistence Test Account');
        TestDataFactory.createCase('Persistence Test Case', acc.Id, null);
    }

    @isTest
    static void test_createSummaryRecord_validInputs_createsRecord() {
        Case testCase         = [SELECT Id FROM Case LIMIT 1];
        DateTime transferTime = System.now();

        Test.startTest();
        Case_Transfer_Summary__c result = CaseSummaryPersistenceService.createSummaryRecord(
            testCase.Id,
            'Customer had login issues. Agent reset password. Awaiting confirmation.',
            transferTime,
            'gpt-4',
            '1.0',
            'Success'
        );
        Test.stopTest();

        System.assertNotEquals(null, result.Id,
            'Returned record must have an Id after insert');

        Case_Transfer_Summary__c persisted = [
            SELECT Case__c, Summary_Text__c, Generation_Status__c,
                   Model_Name__c, Model_Version__c, Transfer_Timestamp__c
            FROM   Case_Transfer_Summary__c
            WHERE  Id = :result.Id
        ];
        System.assertEquals(testCase.Id, persisted.Case__c,
            'Case__c must reference the parent case');
        System.assertEquals('Success', persisted.Generation_Status__c,
            'Generation_Status__c must be Success');
        System.assertEquals('gpt-4', persisted.Model_Name__c,
            'Model_Name__c must match the passed model name');
        System.assertEquals('1.0', persisted.Model_Version__c,
            'Model_Version__c must match the passed version');
        System.assertNotEquals(null, persisted.Transfer_Timestamp__c,
            'Transfer_Timestamp__c must be populated');
    }

    @isTest
    static void test_createSummaryRecord_failedStatus_persistsErrorRecord() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Case_Transfer_Summary__c result = CaseSummaryPersistenceService.createSummaryRecord(
            testCase.Id,
            'Summary generation failed: LLM API returned HTTP 503',
            System.now(),
            'gpt-4',
            '1.0',
            'Failed'
        );
        Test.stopTest();

        Case_Transfer_Summary__c persisted = [
            SELECT Generation_Status__c, Summary_Text__c
            FROM   Case_Transfer_Summary__c
            WHERE  Id = :result.Id
        ];
        System.assertEquals('Failed', persisted.Generation_Status__c,
            'Generation_Status__c must be Failed for error records');
        System.assert(persisted.Summary_Text__c.contains('503'),
            'Summary_Text__c must contain the error detail');
    }
}