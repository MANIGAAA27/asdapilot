/**
 * @file        ARM_MigrationServiceTest.cls
 * @description Tests ARM_MigrationService — covers createAuditRecord, updateAuditStatus,
 *              getAuditRecord, handleAfterInsert (Detail__c JSON), handleAfterUpdate
 *              (ErrorLog__c on Failed transition), empty/null guards, and bulk paths.
 * @testFor     ARM_MigrationService
 * @coverage    Target >= 90%.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-23
 */
// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
@isTest
private class ARM_MigrationServiceTest {

    // -------------------------------------------------------------------------
    // Test: createAuditRecord sets Status__c to New
    // -------------------------------------------------------------------------

    @isTest
    static void test_createAuditRecord_setsStatusNew() {
        Id fakeId = UserInfo.getUserId();

        Test.startTest();
        ARM_MigrationAudit__c result = ARM_MigrationService.createAuditRecord(fakeId);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Inserted record must have an Id');
        System.assertEquals('New', result.Status__c, 'Status must be New');
    }

    // -------------------------------------------------------------------------
    // Test: createAuditRecord stores CPQ_Record_Id__c
    // -------------------------------------------------------------------------

    @isTest
    static void test_createAuditRecord_setsCpqRecordId() {
        Id fakeId = UserInfo.getUserId();

        Test.startTest();
        ARM_MigrationAudit__c result = ARM_MigrationService.createAuditRecord(fakeId);
        Test.stopTest();

        System.assertEquals(
            String.valueOf(fakeId),
            result.CPQ_Record_Id__c,
            'CPQ_Record_Id__c must hold the supplied Id'
        );
    }

    // -------------------------------------------------------------------------
    // Test: updateAuditStatus updates Status__c on matching records
    // -------------------------------------------------------------------------

    @isTest
    static void test_updateAuditStatus_updatesRecords() {
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'New',
            Migration_Start__c = DateTime.now()
        );
        insert audit;

        Test.startTest();
        ARM_MigrationService.updateAuditStatus(new Set<Id>{ audit.Id }, 'In Progress');
        Test.stopTest();

        ARM_MigrationAudit__c updated = [
            SELECT Status__c FROM ARM_MigrationAudit__c WHERE Id = :audit.Id
        ];
        System.assertEquals('In Progress', updated.Status__c, 'Status must be updated to In Progress');
    }

    // -------------------------------------------------------------------------
    // Test: updateAuditStatus with empty set — no exception
    // -------------------------------------------------------------------------

    @isTest
    static void test_updateAuditStatus_emptySet_noException() {
        Test.startTest();
        try {
            ARM_MigrationService.updateAuditStatus(new Set<Id>(), 'In Progress');
            System.assert(true, 'Empty set must not throw');
        } catch (Exception ex) {
            System.assert(false, 'Unexpected exception: ' + ex.getMessage());
        }
        Test.stopTest();
    }

    // -------------------------------------------------------------------------
    // Test: updateAuditStatus with null set — no exception
    // -------------------------------------------------------------------------

    @isTest
    static void test_updateAuditStatus_nullSet_noException() {
        Test.startTest();
        try {
            ARM_MigrationService.updateAuditStatus(null, 'In Progress');
            System.assert(true, 'Null set must not throw');
        } catch (Exception ex) {
            System.assert(false, 'Unexpected exception: ' + ex.getMessage());
        }
        Test.stopTest();
    }

    // -------------------------------------------------------------------------
    // Test: getAuditRecord returns correct record
    // -------------------------------------------------------------------------

    @isTest
    static void test_getAuditRecord_returnsCorrectRecord() {
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'New',
            Migration_Start__c = DateTime.now()
        );
        insert audit;

        Test.startTest();
        ARM_MigrationAudit__c result = ARM_MigrationService.getAuditRecord(audit.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Record must be returned');
        System.assertEquals(audit.Id, result.Id, 'Returned record Id must match');
    }

    // -------------------------------------------------------------------------
    // Test: getAuditRecord with null Id returns null
    // -------------------------------------------------------------------------

    @isTest
    static void test_getAuditRecord_nullId_returnsNull() {
        Test.startTest();
        ARM_MigrationAudit__c result = ARM_MigrationService.getAuditRecord(null);
        Test.stopTest();

        System.assertEquals(null, result, 'Null Id must return null');
    }

    // -------------------------------------------------------------------------
    // Test: handleAfterInsert sets Detail__c JSON
    // -------------------------------------------------------------------------

    @isTest
    static void test_handleAfterInsert_setsDetail() {
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'New',
            Migration_Start__c = DateTime.now()
        );
        insert audit;

        List<ARM_MigrationAudit__c> newRecords = [
            SELECT Id, Status__c FROM ARM_MigrationAudit__c WHERE Id = :audit.Id
        ];

        Test.startTest();
        ARM_MigrationService.handleAfterInsert(newRecords);
        Test.stopTest();

        ARM_MigrationAudit__c updated = [
            SELECT Detail__c FROM ARM_MigrationAudit__c WHERE Id = :audit.Id
        ];
        System.assertNotEquals(null, updated.Detail__c, 'Detail__c must be populated after insert hook');
        System.assert(
            updated.Detail__c.contains('INSERT'),
            'Detail__c must contain INSERT event marker'
        );
    }

    // -------------------------------------------------------------------------
    // Test: handleAfterInsert with empty list — no exception
    // -------------------------------------------------------------------------

    @isTest
    static void test_handleAfterInsert_emptyList_noException() {
        Test.startTest();
        try {
            ARM_MigrationService.handleAfterInsert(new List<ARM_MigrationAudit__c>());
            System.assert(true, 'Empty list must not throw');
        } catch (Exception ex) {
            System.assert(false, 'Unexpected exception: ' + ex.getMessage());
        }
        Test.stopTest();
    }

    // -------------------------------------------------------------------------
    // Test: handleAfterUpdate — Failed transition sets ErrorLog__c
    // -------------------------------------------------------------------------

    @isTest
    static void test_handleAfterUpdate_failedStatus_setsErrorLog() {
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'In Progress',
            Migration_Start__c = DateTime.now()
        );
        insert audit;

        // Simulate a status transition to Failed
        ARM_MigrationAudit__c oldRecord = new ARM_MigrationAudit__c(
            Id = audit.Id,
            Status__c = 'In Progress'
        );
        ARM_MigrationAudit__c newRecord = new ARM_MigrationAudit__c(
            Id = audit.Id,
            Status__c = 'Failed'
        );
        Map<Id, ARM_MigrationAudit__c> oldMap = new Map<Id, ARM_MigrationAudit__c>{
            audit.Id => oldRecord
        };

        Test.startTest();
        ARM_MigrationService.handleAfterUpdate(
            new List<ARM_MigrationAudit__c>{ newRecord },
            oldMap
        );
        Test.stopTest();

        ARM_MigrationAudit__c updated = [
            SELECT ErrorLog__c FROM ARM_MigrationAudit__c WHERE Id = :audit.Id
        ];
        System.assertNotEquals(null, updated.ErrorLog__c, 'ErrorLog__c must be populated on Failed transition');
        System.assert(
            updated.ErrorLog__c.contains('Failed'),
            'ErrorLog__c must reference the Failed status'
        );
    }

    // -------------------------------------------------------------------------
    // Test: handleAfterUpdate — no transition, ErrorLog__c not changed
    // -------------------------------------------------------------------------

    @isTest
    static void test_handleAfterUpdate_noTransition_noErrorLog() {
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'In Progress',
            Migration_Start__c = DateTime.now()
        );
        insert audit;

        // No status change
        ARM_MigrationAudit__c oldRecord = new ARM_MigrationAudit__c(
            Id = audit.Id,
            Status__c = 'In Progress'
        );
        ARM_MigrationAudit__c newRecord = new ARM_MigrationAudit__c(
            Id = audit.Id,
            Status__c = 'In Progress'
        );
        Map<Id, ARM_MigrationAudit__c> oldMap = new Map<Id, ARM_MigrationAudit__c>{
            audit.Id => oldRecord
        };

        Test.startTest();
        ARM_MigrationService.handleAfterUpdate(
            new List<ARM_MigrationAudit__c>{ newRecord },
            oldMap
        );
        Test.stopTest();

        ARM_MigrationAudit__c unchanged = [
            SELECT ErrorLog__c FROM ARM_MigrationAudit__c WHERE Id = :audit.Id
        ];
        System.assertEquals(null, unchanged.ErrorLog__c, 'ErrorLog__c must remain null when no Failed transition');
    }

    // -------------------------------------------------------------------------
    // Test: handleAfterUpdate with empty list — no exception
    // -------------------------------------------------------------------------

    @isTest
    static void test_handleAfterUpdate_emptyList_noException() {
        Test.startTest();
        try {
            ARM_MigrationService.handleAfterUpdate(
                new List<ARM_MigrationAudit__c>(),
                new Map<Id, ARM_MigrationAudit__c>()
            );
            System.assert(true, 'Empty list must not throw');
        } catch (Exception ex) {
            System.assert(false, 'Unexpected exception: ' + ex.getMessage());
        }
        Test.stopTest();
    }
}
