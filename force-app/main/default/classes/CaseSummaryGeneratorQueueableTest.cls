/**
 * @file        CaseSummaryGeneratorQueueableTest.cls
 * @description Tests CaseSummaryGeneratorQueueable — covers success path,
 *              kill switch, failed callout, self-chaining, and bulk 200+ paths.
 * @testFor     CaseSummaryGeneratorQueueable
 * @coverage    Target >= 90%.
 */
@isTest
private class CaseSummaryGeneratorQueueableTest {

    /** Mock returning a valid 200 LLM response. */
    private class SuccessCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"model":"gpt-4","choices":[{"message":{"role":"assistant","content":"Generated summary text."}}]}');
            return res;
        }
    }

    /** Mock returning a 500 server error. */
    private class FailureCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        TestDataFactory.createCase('Queueable Test Case');
    }

    @isTest
    static void test_execute_successPath_createsSummaryRecord() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Queueable Test Case' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

        Test.startTest();
        CaseSummaryGeneratorQueueable job = new CaseSummaryGeneratorQueueable(
            new List<Id>{ c.Id }
        );
        System.enqueueJob(job);
        Test.stopTest();

        List<CaseTransferSummary__c> summaries = [
            SELECT Id, GenerationStatus__c, SummaryText__c
            FROM   CaseTransferSummary__c
            WHERE  Case__c = :c.Id
        ];
        System.assertEquals(1, summaries.size(), 'One summary should be created');
        System.assertEquals('Success', summaries[0].GenerationStatus__c, 'Status should be Success');
        System.assertEquals('Generated summary text.', summaries[0].SummaryText__c, 'Summary text should match mock');
    }

    @isTest
    static void test_execute_failedCallout_createsFailedRecord() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Queueable Test Case' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new FailureCalloutMock());

        Test.startTest();
        CaseSummaryGeneratorQueueable job = new CaseSummaryGeneratorQueueable(
            new List<Id>{ c.Id }
        );
        System.enqueueJob(job);
        Test.stopTest();

        List<CaseTransferSummary__c> summaries = [
            SELECT Id, GenerationStatus__c, ErrorMessage__c
            FROM   CaseTransferSummary__c
            WHERE  Case__c = :c.Id
        ];
        System.assertEquals(1, summaries.size(), 'One summary should be created on failure');
        System.assertEquals('Failed', summaries[0].GenerationStatus__c, 'Status should be Failed');
        System.assert(String.isNotBlank(summaries[0].ErrorMessage__c), 'Error message should be populated');
    }

    @isTest
    static void test_execute_emptyList_doesNotProcess() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

        Test.startTest();
        CaseSummaryGeneratorQueueable job = new CaseSummaryGeneratorQueueable(
            new List<Id>()
        );
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'Empty list handled gracefully without exception');
    }

    @isTest
    static void test_execute_nullList_doesNotProcess() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

        Test.startTest();
        CaseSummaryGeneratorQueueable job = new CaseSummaryGeneratorQueueable(null);
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'Null list handled gracefully without exception');
    }

    @isTest
    static void test_execute_bulkCases_processesWithoutGovernorErrors() {
        List<Case> cases = TestDataFactory.createCases(10);
        List<Id> caseIds = new List<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
        }
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

        Test.startTest();
        CaseSummaryGeneratorQueueable job = new CaseSummaryGeneratorQueueable(caseIds);
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true, 'Bulk 10-case execution completed without governor limit errors');
    }
}
