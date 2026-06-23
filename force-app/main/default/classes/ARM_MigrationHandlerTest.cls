/**
 * @file        ARM_MigrationHandlerTest.cls
 * @description Tests ARM_MigrationHandler — covers startMigration (valid Id, null Id),
 *              pauseMigration (valid Id, null Id, status update), and getMigrationStatus
 *              (valid Id, null Id, unknown Id).
 * @testFor     ARM_MigrationHandler
 * @coverage    Target >= 90%.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-23
 */
// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
@isTest
private class ARM_MigrationHandlerTest {

    // -------------------------------------------------------------------------
    // Test: startMigration with a valid Id creates an audit record
    // -------------------------------------------------------------------------

    @isTest
    static void test_startMigration_validId_returnsAuditId() {
        Id sourceId = UserInfo.getUserId();

        Test.startTest();
        Id auditId = ARM_MigrationHandler.startMigration(sourceId);
        Test.stopTest();

        System.assertNotEquals(null, auditId, 'startMigration must return a non-null audit Id');
        ARM_MigrationAudit__c audit = [
            SELECT Id, Status__c FROM ARM_MigrationAudit__c WHERE Id = :auditId
        ];
        System.assertEquals('New', audit.Status__c, 'Audit record must be created with Status = New');
    }

    // -------------------------------------------------------------------------
    // Test: startMigration with null Id throws AuraHandledException
    // -------------------------------------------------------------------------

    @isTest
    static void test_startMigration_nullId_throwsAuraException() {
        Test.startTest();
        try {
            ARM_MigrationHandler.startMigration(null);
            System.assert(false, 'Expected AuraHandledException for null Id');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Exception message must be populated');
        }
        Test.stopTest();
    }

    // -------------------------------------------------------------------------
    // Test: pauseMigration with valid Id updates status to Failed
    // -------------------------------------------------------------------------

    @isTest
    static void test_pauseMigration_validId_updatesStatus() {
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'New',
            Migration_Start__c = DateTime.now()
        );
        insert audit;

        Test.startTest();
        ARM_MigrationHandler.pauseMigration(audit.Id);
        Test.stopTest();

        ARM_MigrationAudit__c updated = [
            SELECT Status__c FROM ARM_MigrationAudit__c WHERE Id = :audit.Id
        ];
        System.assertEquals('Failed', updated.Status__c, 'pauseMigration must set status to Failed');
    }

    // -------------------------------------------------------------------------
    // Test: pauseMigration with null Id throws AuraHandledException
    // -------------------------------------------------------------------------

    @isTest
    static void test_pauseMigration_nullId_throwsAuraException() {
        Test.startTest();
        try {
            ARM_MigrationHandler.pauseMigration(null);
            System.assert(false, 'Expected AuraHandledException for null auditId');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Exception message must be populated');
        }
        Test.stopTest();
    }

    // -------------------------------------------------------------------------
    // Test: getMigrationStatus with valid Id returns audit record
    // -------------------------------------------------------------------------

    @isTest
    static void test_getMigrationStatus_validId_returnsRecord() {
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'New',
            Migration_Start__c = DateTime.now()
        );
        insert audit;

        Test.startTest();
        ARM_MigrationAudit__c result = ARM_MigrationHandler.getMigrationStatus(audit.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'getMigrationStatus must return a record for valid Id');
        System.assertEquals(audit.Id, result.Id, 'Returned record Id must match');
        System.assertEquals('New', result.Status__c, 'Status must be New');
    }

    // -------------------------------------------------------------------------
    // Test: getMigrationStatus with null Id throws AuraHandledException
    // -------------------------------------------------------------------------

    @isTest
    static void test_getMigrationStatus_nullId_throwsAuraException() {
        Test.startTest();
        try {
            ARM_MigrationHandler.getMigrationStatus(null);
            System.assert(false, 'Expected AuraHandledException for null auditId');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Exception message must be populated');
        }
        Test.stopTest();
    }

    // -------------------------------------------------------------------------
    // Test: getMigrationStatus with unknown Id returns null
    // -------------------------------------------------------------------------

    @isTest
    static void test_getMigrationStatus_unknownId_returnsNull() {
        // Insert and delete a record to get a valid-format Id that no longer exists
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'New',
            Migration_Start__c = DateTime.now()
        );
        insert audit;
        Id deletedId = audit.Id;
        delete audit;

        Test.startTest();
        ARM_MigrationAudit__c result = ARM_MigrationHandler.getMigrationStatus(deletedId);
        Test.stopTest();

        System.assertEquals(null, result, 'getMigrationStatus must return null for a deleted record Id');
    }
}
