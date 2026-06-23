/**
 * @file              ARM_MigrationService.cls
 * @description       Encapsulates business logic related to the ARM migration
 *                    lifecycle. Creates and updates ARM_MigrationAudit__c
 *                    records, provides post-trigger hooks for MigrationProcessHandler,
 *                    and exposes utility methods consumed by ARM_MigrationHandler.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-23
 * @lastModified      2026-06-23
 * @group             MigrationProcessing
 *
 * @dependencies      ARM_MigrationAudit__c
 * @calledBy          MigrationProcessHandler, ARM_MigrationHandler
 * @testClass         ARM_MigrationServiceTest
 *
 * @see               HLD-CMP Advanced Record Migration Tool (ARMT)
 */

// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
/**
 * Service layer for ARM migration audit record management.
 *
 * Responsibilities:
 *   - Create ARM_MigrationAudit__c records for new migration runs.
 *   - Update audit record status on state transitions.
 *   - Provide after-insert and after-update hooks called from the trigger handler.
 *
 * Threading: all public methods are static and bulkified.
 *
 * @testClass ARM_MigrationServiceTest
 */
public with sharing class ARM_MigrationService {

    // -------------------------------------------------------------------------
    // Audit record creation
    // -------------------------------------------------------------------------

    /**
     * Creates a single ARM_MigrationAudit__c record initialised with
     * 'New' status and the provided CPQ source record ID.
     *
     * @param  cpqRecordId   The 18-digit Id of the source CPQ record driving
     *                       this migration audit. May be any valid Salesforce Id.
     * @return The inserted ARM_MigrationAudit__c record with Id populated.
     * @throws DmlException if the insert fails.
     *
     * @calledBy    ARM_MigrationHandler.startMigration
     * @testMethods test_createAuditRecord_setsStatusNew,
     *              test_createAuditRecord_setsCpqRecordId
     */
    public static ARM_MigrationAudit__c createAuditRecord(Id cpqRecordId) {
        ARM_MigrationAudit__c auditRecord = new ARM_MigrationAudit__c(
            Status__c       = 'New',
            CPQ_Record_Id__c = String.valueOf(cpqRecordId),
            Migration_Start__c = DateTime.now()
        );
        insert auditRecord;
        return auditRecord;
    }

    // -------------------------------------------------------------------------
    // Status management
    // -------------------------------------------------------------------------

    /**
     * Updates the Status__c field on one or more ARM_MigrationAudit__c records.
     * Uses partial-success DML to avoid aborting on individual row failures.
     *
     * @param  auditIds   Set of ARM_MigrationAudit__c record Ids to update.
     * @param  newStatus  The target status value (must match the picklist).
     *
     * @calledBy    ARM_MigrationHandler.pauseMigration
     * @testMethods test_updateAuditStatus_updatesRecords,
     *              test_updateAuditStatus_emptySet_noException
     */
    public static void updateAuditStatus(Set<Id> auditIds, String newStatus) {
        if (auditIds == null || auditIds.isEmpty()) {
            return;
        }

        List<ARM_MigrationAudit__c> audits = [
            SELECT Id, Status__c
            FROM ARM_MigrationAudit__c
            WHERE Id IN :auditIds
            WITH SECURITY_ENFORCED
        ];

        for (ARM_MigrationAudit__c audit : audits) {
            audit.Status__c = newStatus;
        }

        Database.update(audits, false);
    }

    /**
     * Retrieves a single ARM_MigrationAudit__c record with its key fields.
     *
     * @param  auditId  The Id of the audit record to retrieve.
     * @return The audit record, or null if no record matches the Id.
     *
     * @calledBy    ARM_MigrationHandler.getMigrationStatus
     * @testMethods test_getAuditRecord_returnsCorrectRecord,
     *              test_getAuditRecord_unknownId_returnsNull
     */
    public static ARM_MigrationAudit__c getAuditRecord(Id auditId) {
        if (auditId == null) {
            return null;
        }
        List<ARM_MigrationAudit__c> records = [
            SELECT Id, Status__c, CPQ_Record_Id__c,
                   Migration_Start__c, Migration_End__c,
                   Error_Message__c, ErrorLog__c, Detail__c
            FROM ARM_MigrationAudit__c
            WHERE Id = :auditId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }

    // -------------------------------------------------------------------------
    // Trigger hook methods (called from MigrationProcessHandler)
    // -------------------------------------------------------------------------

    /**
     * Post-insert hook. Persists the Detail__c JSON snapshot for each new
     * audit record to capture the insertion context.
     * V1 implementation: stores minimal event data.
     *
     * @param  newRecords  List of newly inserted ARM_MigrationAudit__c records.
     *
     * @calledBy    MigrationProcessHandler.onAfterInsert
     * @testMethods test_handleAfterInsert_setsDetail
     */
    public static void handleAfterInsert(List<ARM_MigrationAudit__c> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        List<ARM_MigrationAudit__c> auditsToUpdate = new List<ARM_MigrationAudit__c>();
        for (ARM_MigrationAudit__c record : newRecords) {
            String detail = JSON.serialize(new Map<String, Object>{
                'event'    => 'INSERT',
                'recordId' => record.Id,
                'status'   => record.Status__c,
                'inserted' => String.valueOf(DateTime.now())
            });
            auditsToUpdate.add(new ARM_MigrationAudit__c(
                Id       = record.Id,
                Detail__c = detail
            ));
        }

        Database.update(auditsToUpdate, false);
    }

    /**
     * Post-update hook. Logs status transition details to ErrorLog__c when
     * the status transitions to 'Failed'.
     *
     * @param  newRecords  Updated ARM_MigrationAudit__c records (Trigger.new).
     * @param  oldMap      Previous state of the records (Trigger.oldMap).
     *
     * @calledBy    MigrationProcessHandler.onAfterUpdate
     * @testMethods test_handleAfterUpdate_failedStatus_setsErrorLog
     */
    public static void handleAfterUpdate(
        List<ARM_MigrationAudit__c> newRecords,
        Map<Id, ARM_MigrationAudit__c> oldMap
    ) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        List<ARM_MigrationAudit__c> auditsToUpdate = new List<ARM_MigrationAudit__c>();
        for (ARM_MigrationAudit__c record : newRecords) {
            ARM_MigrationAudit__c oldRecord = oldMap.get(record.Id);
            if (oldRecord != null
                && record.Status__c == 'Failed'
                && oldRecord.Status__c != 'Failed') {
                auditsToUpdate.add(new ARM_MigrationAudit__c(
                    Id       = record.Id,
                    ErrorLog__c = 'Status transitioned to Failed from '
                                  + oldRecord.Status__c + ' at ' + DateTime.now()
                ));
            }
        }

        if (!auditsToUpdate.isEmpty()) {
            Database.update(auditsToUpdate, false);
        }
    }
}
