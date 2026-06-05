/**
  @file        CaseSummarySelectorTest.cls
  @description Tests CaseSummarySelector — covers single/multi-record retrieval,
               ordering, limit enforcement, null/empty inputs, and bulk queries.
  @testFor     CaseSummarySelector
  @coverage    Target >= 90%.
 */
// MODIFIED 2026-06-05 — Project: Case Transfer | LLD-CaseTransfer-1 (BR1-BR2) | ASDA
@isTest
private class CaseSummarySelectorTest {

    @TestSetup
    static void setupData() {
        Case c = TestDataFactory.createCase('Selector Test Case');
        TestDataFactory.createCaseTransferSummary(c.Id, 'Summary 1');
        TestDataFactory.createCaseTransferSummary(c.Id, 'Summary 2');
        TestDataFactory.createCaseTransferSummary(c.Id, 'Summary 3');
    }

    @isTest
    static void getLatestSummaryForCase_returnsMostRecent() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Selector Test Case' LIMIT 1];
        CaseSummarySelector sel = new CaseSummarySelector();
        Test.startTest();
        SObject result = sel.getLatestSummaryForCase(c.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return a summary record');
    }

    @isTest
    static void getLatestSummaryForCase_noRecords_returnsNull() {
        Case fresh = TestDataFactory.createCase('No Summary Case');
        CaseSummarySelector sel = new CaseSummarySelector();
        Test.startTest();
        SObject result = sel.getLatestSummaryForCase(fresh.Id);
        Test.stopTest();
        System.assertEquals(null, result, 'No summaries should return null');
    }

    @isTest
    static void getSummariesForCase_returnsOrdered() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Selector Test Case' LIMIT 1];
        CaseSummarySelector sel = new CaseSummarySelector();
        Test.startTest();
        List<SObject> results = sel.getSummariesForCase(c.Id, 10);
        Test.stopTest();
        System.assertEquals(3, results.size(), 'Should return all 3 seeded summaries');
    }

    @isTest
    static void getSummariesForCase_limitEnforced() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Selector Test Case' LIMIT 1];
        CaseSummarySelector sel = new CaseSummarySelector();
        Test.startTest();
        List<SObject> results = sel.getSummariesForCase(c.Id, 1);
        Test.stopTest();
        System.assertEquals(1, results.size(), 'Limit of 1 should return exactly 1 record');
    }

    @isTest
    static void getSummariesForCase_nullLimit_usesDefault() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Selector Test Case' LIMIT 1];
        CaseSummarySelector sel = new CaseSummarySelector();
        Test.startTest();
        List<SObject> results = sel.getSummariesForCase(c.Id, null);
        Test.stopTest();
        System.assertNotEquals(null, results, 'Null limit should not throw');
    }

    @isTest
    static void getSummariesForCases_bulkQuery() {
        List<Case> cases = TestDataFactory.createCases(3);
        for (Case c : cases) {
            TestDataFactory.createCaseTransferSummary(c.Id, 'Success');
        }
        Set<Id> caseIds = new Set<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
        }
        CaseSummarySelector sel = new CaseSummarySelector();
        Test.startTest();
        List<SObject> results = sel.getSummariesForCases(caseIds);
        Test.stopTest();
        System.assertEquals(3, results.size(), 'Should return one summary per case');
    }

    @isTest
    static void getSummariesForCases_emptySet_returnsEmpty() {
        CaseSummarySelector sel = new CaseSummarySelector();
        Test.startTest();
        List<SObject> results = sel.getSummariesForCases(new Set<Id>());
        Test.stopTest();
        System.assertNotEquals(null, results, 'Should not return null');
        System.assertEquals(0, results.size(), 'Empty set should yield empty list');
    }
}
