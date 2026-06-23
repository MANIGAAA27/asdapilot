/**
 * @file        DataTransformBatchTest.cls
 * @description Tests DataTransformBatch — covers constructor, start query locator,
 *              execute transition logic (pending → completed), finish audit update,
 *              null audit ID path, and bulk 200 records within governor limits.
 * @testFor     DataTransformBatch
 * @coverage    Target >= 90%.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-23
 */
// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
@isTest
private class DataTransformBatchTest {

    // -------------------------------------------------------------------------
    // Test setup
    // -------------------------------------------------------------------------

    @TestSetup
    static void setupData() {
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'In Progress',
            Migration_Start__c = DateTime.now()
        );
        insert audit;

        List<Migration_Log__c> logs = new List<Migration_Log__c>();
        for (Integer i = 0; i < 5; i++) {
            logs.add(new Migration_Log__c(
                MigrationStatus__c = 'Pending',
                MigrationDate__c = Date.today()
            ));
        }
        insert logs;
    }

    // -------------------------------------------------------------------------
    // Test: constructor sets auditId correctly
    // -------------------------------------------------------------------------

    @isTest
    static void test_constructor_setsAuditId() {
        ARM_MigrationAudit__c audit = [SELECT Id FROM ARM_MigrationAudit__c LIMIT 1];

        Test.startTest();
        DataTransformBatch batchJob = new DataTransformBatch(audit.Id);
        Test.stopTest();

        System.assertEquals(audit.Id, batchJob.migrationAuditId, 'Audit ID must be set by constructor');
        System.assertEquals(0, batchJob.successCount, 'Success count initialises to zero');
        System.assertEquals(0, batchJob.failureCount, 'Failure count initialises to zero');
    }

    // -------------------------------------------------------------------------
    // Test: execute transitions pending logs to Completed
    // -------------------------------------------------------------------------

    @isTest
    static void test_execute_pendingLogs_marksCompleted() {
        ARM_MigrationAudit__c audit = [SELECT Id FROM ARM_MigrationAudit__c LIMIT 1];
        DataTransformBatch batchJob = new DataTransformBatch(audit.Id);

        Test.startTest();
        Database.executeBatch(batchJob, 200);
        Test.stopTest();

        List<Migration_Log__c> completed = [
            SELECT Id, MigrationStatus__c
            FROM Migration_Log__c
            WHERE MigrationStatus__c = 'Completed'
        ];
        System.assertNotEquals(0, completed.size(), 'At least one log must be marked Completed');
    }

    // -------------------------------------------------------------------------
    // Test: finish updates ARM_MigrationAudit__c to Completed
    // -------------------------------------------------------------------------

    @isTest
    static void test_finish_updatesAuditRecord() {
        ARM_MigrationAudit__c audit = [SELECT Id FROM ARM_MigrationAudit__c LIMIT 1];

        Test.startTest();
        Database.executeBatch(new DataTransformBatch(audit.Id), 200);
        Test.stopTest();

        ARM_MigrationAudit__c updated = [
            SELECT Id, Status__c, Migration_End__c
            FROM ARM_MigrationAudit__c
            WHERE Id = :audit.Id
        ];
        System.assertEquals('Completed', updated.Status__c, 'Audit status must be Completed after successful batch');
        System.assertNotEquals(null, updated.Migration_End__c, 'Migration end timestamp must be populated');
    }

    // -------------------------------------------------------------------------
    // Test: null audit ID — finish() does not throw
    // -------------------------------------------------------------------------

    @isTest
    static void test_finish_nullAuditId_noException() {
        Test.startTest();
        try {
            Database.executeBatch(new DataTransformBatch(null), 200);
            System.assert(true, 'Null audit ID must not throw an exception');
        } catch (Exception ex) {
            System.assert(false, 'Unexpected exception with null audit ID: ' + ex.getMessage());
        }
        Test.stopTest();
    }

    // -------------------------------------------------------------------------
    // Test: bulk 200 pending logs complete within governor limits
    // -------------------------------------------------------------------------

    @isTest
    static void test_execute_bulk200_completesWithinLimits() {
        List<Migration_Log__c> bulkLogs = new List<Migration_Log__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkLogs.add(new Migration_Log__c(
                MigrationStatus__c = 'Pending',
                MigrationDate__c = Date.today()
            ));
        }
        insert bulkLogs;

        ARM_MigrationAudit__c audit = [SELECT Id FROM ARM_MigrationAudit__c LIMIT 1];

        Test.startTest();
        Database.executeBatch(new DataTransformBatch(audit.Id), 200);
        Test.stopTest();

        List<Migration_Log__c> completedLogs = [
            SELECT Id FROM Migration_Log__c
            WHERE MigrationStatus__c = 'Completed'
        ];
        System.assert(completedLogs.size() >= 200, 'All 200 bulk logs must transition to Completed');
    }
}
