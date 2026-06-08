/**
  @file              SummarizationQueueableTest.cls
  @description       Test class for SummarizationQueueable to validate asynchronous summary generation and error handling.
  @author            ASDA Dev Agent
  @lastModified      2023-10-31
  @testFor           SummarizationQueueable
  @coverage          Target: 90%
 */
// MODIFIED 2026-06-08 — Project: Gift Basket | CodeImplementation-GiftBasket | ASDA
@isTest
public class SummarizationQueueableTest {
    @testSetup
    static void setup() {
        List<Case> cases = new List<Case>();
        // Setup test data
        Case newCase = new Case(Subject = 'Test Case', Description = 'This is a test case');
        cases.add(newCase);
        insert cases;
    }

    @isTest
    static void test_execute_validCase_createsSummary() {
        List<Case> caseList = [SELECT Id FROM Case LIMIT 1];
        if (caseList.isEmpty()) {
            System.assert(false, 'No case records found for testing.');
        }
        Id testCaseId = caseList[0].Id;
        Test.startTest();
        System.enqueueJob(new SummarizationQueueable(testCaseId));
        Test.stopTest();
        // Assert summary record created
        List<Case_Transfer_Summary__c> summaries = [SELECT Id FROM Case_Transfer_Summary__c WHERE Case__c = :testCaseId];
        System.assert(!summaries.isEmpty(), 'Expected summary records to be created');
    }

    @isTest
    static void test_execute_invalidCase_logsError() {
        Test.startTest();
        System.enqueueJob(new SummarizationQueueable('nonExistingId'));
        Test.stopTest();
        // Assert error record created
        List<Case_Transfer_Summary_Error__c> errors = [SELECT Id FROM Case_Transfer_Summary_Error__c];
        System.assert(!errors.isEmpty(), 'Expected error log entries to be created');
    }
}
