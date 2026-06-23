/**
 * @file        ProcessQuoteTemplatesTest.cls
 * @description Tests ProcessQuoteTemplates — covers null-ID guard, empty
 *              request list, successful log creation for valid IDs, and
 *              bulk 200+ paths. CPQ package is NOT required for these tests.
 * @testFor     ProcessQuoteTemplates
 * @coverage    Target >= 90%.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-23
 */
// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
@isTest
private class ProcessQuoteTemplatesTest {

    // -------------------------------------------------------------------------
    // Test: null quoteTemplateId returns failure result without exception
    // -------------------------------------------------------------------------

    @isTest
    static void test_transformTemplates_nullId_returnsFailure() {
        ProcessQuoteTemplates.TemplateTransformRequest req =
            new ProcessQuoteTemplates.TemplateTransformRequest();
        req.quoteTemplateId = null;

        Test.startTest();
        List<ProcessQuoteTemplates.TemplateTransformResult> results =
            ProcessQuoteTemplates.transformTemplates(
                new List<ProcessQuoteTemplates.TemplateTransformRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one result for one request');
        System.assertEquals(false, results[0].success, 'Null ID should return failure');
        System.assertNotEquals(null, results[0].errorMessage, 'Error message must be populated');
    }

    // -------------------------------------------------------------------------
    // Test: empty request list returns empty result list
    // -------------------------------------------------------------------------

    @isTest
    static void test_transformTemplates_emptyList_returnsEmpty() {
        Test.startTest();
        List<ProcessQuoteTemplates.TemplateTransformResult> results =
            ProcessQuoteTemplates.transformTemplates(
                new List<ProcessQuoteTemplates.TemplateTransformRequest>()
            );
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result list must not be null');
        System.assertEquals(0, results.size(), 'Empty request list yields empty results');
    }

    // -------------------------------------------------------------------------
    // Test: non-null ID creates a Migration_Log__c record and returns success
    // -------------------------------------------------------------------------

    @isTest
    static void test_transformTemplates_nonNullId_returnsSuccess() {
        // Any non-null Id — the service writes a log without querying the
        // source object, so any valid 18-char Id is acceptable.
        Id anyId = UserInfo.getUserId(); // always valid in test context

        ProcessQuoteTemplates.TemplateTransformRequest req =
            new ProcessQuoteTemplates.TemplateTransformRequest();
        req.quoteTemplateId = anyId;

        Test.startTest();
        List<ProcessQuoteTemplates.TemplateTransformResult> results =
            ProcessQuoteTemplates.transformTemplates(
                new List<ProcessQuoteTemplates.TemplateTransformRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one result');
        System.assertEquals(true, results[0].success, 'Non-null ID should succeed');
        System.assertNotEquals(null, results[0].migrationLogId,
            'Migration log Id must be populated on success');
    }

    // -------------------------------------------------------------------------
    // Test: success path writes Migration_Log__c record with Completed status
    // -------------------------------------------------------------------------

    @isTest
    static void test_transformTemplates_logRecord_hasCorrectStatus() {
        Id anyId = UserInfo.getUserId();

        ProcessQuoteTemplates.TemplateTransformRequest req =
            new ProcessQuoteTemplates.TemplateTransformRequest();
        req.quoteTemplateId = anyId;

        Test.startTest();
        List<ProcessQuoteTemplates.TemplateTransformResult> results =
            ProcessQuoteTemplates.transformTemplates(
                new List<ProcessQuoteTemplates.TemplateTransformRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Expect success');
        Migration_Log__c logRecord = [
            SELECT MigrationStatus__c, MigrationDate__c
            FROM Migration_Log__c
            WHERE Id = :results[0].migrationLogId
        ];
        System.assertEquals('Completed', logRecord.MigrationStatus__c,
            'Log status must be Completed on success path');
        System.assertEquals(Date.today(), logRecord.MigrationDate__c,
            'Log date must be today');
    }

    // -------------------------------------------------------------------------
    // Test: bulk 200 null-ID requests all return failure without hitting limits
    // -------------------------------------------------------------------------

    @isTest
    static void test_transformTemplates_bulk200_nullIds_completesWithinLimits() {
        List<ProcessQuoteTemplates.TemplateTransformRequest> requests =
            new List<ProcessQuoteTemplates.TemplateTransformRequest>();
        for (Integer i = 0; i < 200; i++) {
            ProcessQuoteTemplates.TemplateTransformRequest req =
                new ProcessQuoteTemplates.TemplateTransformRequest();
            req.quoteTemplateId = null;
            requests.add(req);
        }

        Test.startTest();
        List<ProcessQuoteTemplates.TemplateTransformResult> results =
            ProcessQuoteTemplates.transformTemplates(requests);
        Test.stopTest();

        System.assertEquals(200, results.size(), 'All 200 requests must yield a result');
        for (ProcessQuoteTemplates.TemplateTransformResult res : results) {
            System.assertEquals(false, res.success, 'Each null-ID result must be a failure');
        }
    }
}
