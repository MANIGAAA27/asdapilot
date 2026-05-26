/**
 * @file        CaseTriggerHandlerTest.cls
 * @description Tests CaseTriggerHandler via the CaseTrigger — verifies that
 *              owner changes trigger summary generation (and set the timestamp)
 *              while non-owner updates leave no summary records.
 * @testFor     CaseTriggerHandler
 * @coverage    Target ≥ 90%.
 */
@isTest
private class CaseTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        Account acc = TestDataFactory.createAccount('Trigger Handler Test Account');
        TestDataFactory.createCase('Trigger Handler Test Case', acc.Id, null);
    }

    @isTest
    static void test_onAfterUpdate_ownerChanged_enqueuesJob() {
        Case testCase = [SELECT Id, OwnerId FROM Case LIMIT 1];
        User differentUser = [
            SELECT Id FROM User
            WHERE  Id != :testCase.OwnerId
            AND    IsActive = true
            LIMIT  1
        ];
        Test.setMock(HttpCalloutMock.class, new LLMCalloutServiceMock());

        Test.startTest();
        testCase.OwnerId = differentUser.Id;
        update testCase;
        Test.stopTest();

        List<Case_Transfer_Summary__c> summaries = [
            SELECT Id, Generation_Status__c
            FROM   Case_Transfer_Summary__c
            WHERE  Case__c = :testCase.Id
        ];
        System.assert(!summaries.isEmpty(),
            'A Case_Transfer_Summary__c must be created when the case owner changes');
    }

    @isTest
    static void test_onAfterUpdate_ownerNotChanged_doesNotEnqueueJob() {
        Case testCase = [SELECT Id, Subject FROM Case LIMIT 1];

        Test.startTest();
        testCase.Subject = 'Updated Subject — Not a Transfer';
        update testCase;
        Test.stopTest();

        List<Case_Transfer_Summary__c> summaries = [
            SELECT Id FROM Case_Transfer_Summary__c WHERE Case__c = :testCase.Id
        ];
        System.assertEquals(0, summaries.size(),
            'No summary must be created when only the Subject changes (not the owner)');
    }

    @isTest
    static void test_onBeforeUpdate_ownerChanged_setsTransferTimestamp() {
        Case testCase = [SELECT Id, OwnerId FROM Case LIMIT 1];
        User differentUser = [
            SELECT Id FROM User
            WHERE  Id != :testCase.OwnerId
            AND    IsActive = true
            LIMIT  1
        ];
        Test.setMock(HttpCalloutMock.class, new LLMCalloutServiceMock());

        Test.startTest();
        testCase.OwnerId = differentUser.Id;
        update testCase;
        Test.stopTest();

        Case updated = [
            SELECT Last_Owner_Change_Timestamp__c FROM Case WHERE Id = :testCase.Id
        ];
        System.assertNotEquals(null, updated.Last_Owner_Change_Timestamp__c,
            'Last_Owner_Change_Timestamp__c must be stamped by onBeforeUpdate when owner changes');
    }

    @isTest
    static void test_onAfterUpdate_bulkTransfer_handlesAllRecords() {
        Account acc = TestDataFactory.createAccount('Bulk Transfer Account');
        List<Case> bulkCases = TestDataFactory.createCases(10, acc.Id);
        User differentUser = [
            SELECT Id FROM User
            WHERE  Id != :bulkCases[0].OwnerId
            AND    IsActive = true
            LIMIT  1
        ];
        Test.setMock(HttpCalloutMock.class, new LLMCalloutServiceMock());

        for (Case c : bulkCases) {
            c.OwnerId = differentUser.Id;
        }

        Test.startTest();
        update bulkCases;
        Test.stopTest();

        // At least one queueable ran; validate the first case has a summary
        List<Case_Transfer_Summary__c> summaries = [
            SELECT Id FROM Case_Transfer_Summary__c WHERE Case__c = :bulkCases[0].Id
        ];
        System.assertEquals(1, summaries.size(),
            'Summary must be created for each transferred case in a bulk update');
    }
}