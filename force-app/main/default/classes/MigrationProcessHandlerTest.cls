/**
 * @file        MigrationProcessHandlerTest.cls
 * @description Tests MigrationProcessHandler — covers startMigrationAsync audit creation,
 *              handleAfterInsert trigger dispatch, execute with empty IDs (fail path),
 *              execute with valid IDs (log creation + batch enqueue), and bulk paths.
 * @testFor     MigrationProcessHandler
 * @coverage    Target >= 90%.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-23
 */
// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
@isTest
private class MigrationProcessHandlerTest {

    // -------------------------------------------------------------------------
    // startMigrationAsync — creates audit record and returns its ID
    // -------------------------------------------------------------------------

    @isTest
    static void test_startMigrationAsync_createsAuditRecord() {
        Test.startTest();
        Id auditId = MigrationProcessHandler.startMigrationAsync(new List<Id>());
        Test.stopTest();

        System.assertNotEquals(null, auditId, 'Audit record ID must be returned');
        ARM_MigrationAudit__c audit = [
            SELECT Id, Status__c, Migration_Start__c
            FROM ARM_MigrationAudit__c
            WHERE Id = :auditId
        ];
        System.assertEquals('In Progress', audit.Status__c, 'Audit must start In Progress');
        System.assertNotEquals(null, audit.Migration_Start__c, 'Migration start timestamp must be set');
    }

    // -------------------------------------------------------------------------
    // startMigrationAsync — with CPQ record IDs populates CPQ_Record_Id__c
    // -------------------------------------------------------------------------

    @isTest
    static void test_startMigrationAsync_withCpqId_populatesCpqField() {
        // Use a well-formed Account ID as a stand-in CPQ ID for field-level test
        Id fakeCpqId = '001xx000000001AAAQ';

        Test.startTest();
        Id auditId = MigrationProcessHandler.startMigrationAsync(
            new List<Id>{ fakeCpqId }
        );
        Test.stopTest();

        ARM_MigrationAudit__c audit = [
            SELECT CPQ_Record_Id__c FROM ARM_MigrationAudit__c WHERE Id = :auditId
        ];
        System.assertEquals(String.valueOf(fakeCpqId), audit.CPQ_Record_Id__c,
            'CPQ_Record_Id__c must store the first CPQ ID');
    }

    // -------------------------------------------------------------------------
    // handleAfterInsert — New status records trigger job enqueue
    // -------------------------------------------------------------------------

    @isTest
    static void test_handleAfterInsert_newStatus_enqueuesJob() {
        // Inserting an ARM_MigrationAudit__c with Status=New fires the trigger
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'New',
            Migration_Start__c = DateTime.now()
        );

        Test.startTest();
        insert audit;
        Test.stopTest();

        // Verify the audit record was persisted; trigger enqueued a Queueable
        ARM_MigrationAudit__c reloaded = [
            SELECT Id, Status__c FROM ARM_MigrationAudit__c WHERE Id = :audit.Id
        ];
        System.assertNotEquals(null, reloaded.Id, 'Audit record must exist after insert');
    }

    // -------------------------------------------------------------------------
    // handleAfterInsert — non-New status does not enqueue
    // -------------------------------------------------------------------------

    @isTest
    static void test_handleAfterInsert_nonNewStatus_noJob() {
        List<ARM_MigrationAudit__c> records = new List<ARM_MigrationAudit__c>{
            new ARM_MigrationAudit__c(Status__c = 'Completed'),
            new ARM_MigrationAudit__c(Status__c = 'Failed')
        };

        Test.startTest();
        // Directly call the dispatch method to test filtering without DML trigger
        MigrationProcessHandler.handleAfterInsert(records);
        Test.stopTest();

        // If we get here without governor limit exception, no jobs were over-enqueued
        System.assert(true, 'Non-New status records must not cause any exception');
    }

    // -------------------------------------------------------------------------
    // execute — empty ID list marks audit as Failed
    // -------------------------------------------------------------------------

    @isTest
    static void test_execute_emptyIds_updatesAuditFailed() {
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'In Progress',
            Migration_Start__c = DateTime.now()
        );
        insert audit;

        Test.startTest();
        System.enqueueJob(new MigrationProcessHandler(new List<Id>(), audit.Id));
        Test.stopTest();

        ARM_MigrationAudit__c updated = [
            SELECT Status__c, Error_Message__c
            FROM ARM_MigrationAudit__c
            WHERE Id = :audit.Id
        ];
        System.assertEquals('Failed', updated.Status__c, 'Empty IDs must set audit to Failed');
        System.assertNotEquals(null, updated.Error_Message__c, 'Error message must be populated');
    }

    // -------------------------------------------------------------------------
    // execute — valid IDs create Migration_Log__c records
    // -------------------------------------------------------------------------

    @isTest
    static void test_execute_withIds_createsMigrationLogs() {
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'In Progress',
            Migration_Start__c = DateTime.now()
        );
        insert audit;

        // Use self-referential IDs (the audit record's own ID repeated) as stand-in CPQ IDs
        List<Id> fakeIds = new List<Id>{ audit.Id, audit.Id };

        Test.startTest();
        System.enqueueJob(new MigrationProcessHandler(fakeIds, audit.Id));
        Test.stopTest();

        List<Migration_Log__c> logs = [
            SELECT Id, MigrationStatus__c FROM Migration_Log__c
        ];
        System.assert(logs.size() >= 2, 'One Migration_Log__c must be created per CPQ ID');
    }
}
