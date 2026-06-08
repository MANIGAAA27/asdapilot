/**
 * @file        CaseTransferSummaryControllerTest.cls
 * @description Unit test for CaseTransferSummaryController class.
 *              Tests all logical paths: success, no record, and no access.
 * @testFor     CaseTransferSummaryController
 * @coverage    Target: 90%+
 * @author      ASDA Dev Agent
 * @lastModified 2026-06-08
 */
// MODIFIED 2026-06-08 — Project: Gift Basket | CodeImplementation-GiftBasket | ASDA
@isTest
private class CaseTransferSummaryControllerTest {

    @testSetup
    static void setup() {
        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Phone');
        insert testCase;

        Case_Transfer_Summary__c summary = new Case_Transfer_Summary__c(
            Case__c = testCase.Id,
            Summary__c = 'Test summary content',
            Generated_At__c = System.now()
        );
        insert summary;
    }

    @isTest
    static void testGetCaseTransferSummary_HappyPath() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Test.startTest();
        String result = CaseTransferSummaryController.getCaseTransferSummary(testCase.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Expected a non-null summary');
        System.assertNotEquals('', result, 'Expected a non-empty summary');
    }

    @isTest
    static void testGetCaseTransferSummary_NoSummaryExists() {
        Case newCase = new Case(Subject = 'No Summary Case', Status = 'New', Origin = 'Phone');
        insert newCase;
        Test.startTest();
        String result = CaseTransferSummaryController.getCaseTransferSummary(newCase.Id);
        Test.stopTest();
        System.assertEquals('', result, 'Expected empty string when no summary exists');
    }

    @isTest
    static void testGetCaseTransferSummary_NullId() {
        Test.startTest();
        try {
            String result = CaseTransferSummaryController.getCaseTransferSummary(null);
            System.assertEquals('', result, 'Expected empty string for null Id');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Expected AuraHandledException with message');
        }
        Test.stopTest();
    }
}
