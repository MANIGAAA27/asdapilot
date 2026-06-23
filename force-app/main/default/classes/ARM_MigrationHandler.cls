/**
 * @file              ARM_MigrationHandler.cls
 * @description       @AuraEnabled LWC server-side controller for the migrationWizard
 *                    component. Provides start, pause, and status-query operations
 *                    on ARM migration jobs by delegating to ARM_MigrationService.
 *                    Wraps all exceptions in AuraHandledException so the LWC can
 *                    display user-friendly messages.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-23
 * @lastModified      2026-06-23
 * @group             MigrationProcessing
 *
 * @dependencies      ARM_MigrationService, ARM_MigrationAudit__c
 * @calledBy          migrationWizard (LWC)
 * @testClass         ARM_MigrationHandlerTest
 *
 * @see               HLD-CMP Advanced Record Migration Tool (ARMT)
 */

// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
/**
 * Aura-enabled controller bridging the migrationWizard LWC to ARM_MigrationService.
 *
 * Responsibilities:
 *   - startMigration: create an audit record for a CPQ source record and return its Id.
 *   - pauseMigration: update one audit record status to 'Failed' (pause/halt signal).
 *   - getMigrationStatus: retrieve a single audit record with status and timestamps.
 *
 * Threading: all methods are static; no instance state. Safe to call from multiple
 * LWC wires or user actions in the same transaction.
 *
 * @testClass ARM_MigrationHandlerTest
 */
public with sharing class ARM_MigrationHandler {

    // -------------------------------------------------------------------------
    // Start migration
    // -------------------------------------------------------------------------

    /**
     * Creates a new ARM_MigrationAudit__c record with Status = 'New' for the
     * given CPQ source record Id and returns the new audit record Id.
     * Delegates insert to ARM_MigrationService.createAuditRecord.
     *
     * @param  migrationRecordId  Id of the CPQ source record initiating this migration.
     * @return Id of the newly created ARM_MigrationAudit__c record.
     * @throws AuraHandledException when the Id is null or the DML fails.
     *
     * @calledBy    migrationWizard (LWC)
     * @testMethods test_startMigration_validId_returnsAuditId,
     *              test_startMigration_nullId_throwsAuraException
     */
    @AuraEnabled
    public static Id startMigration(Id migrationRecordId) {
        if (migrationRecordId == null) {
            throw new AuraHandledException('migrationRecordId is required to start a migration.');
        }
        try {
            ARM_MigrationAudit__c audit =
                ARM_MigrationService.createAuditRecord(migrationRecordId);
            return audit.Id;
        } catch (DmlException ex) {
            throw new AuraHandledException(
                'Failed to start migration: ' + ex.getMessage()
            );
        }
    }

    // -------------------------------------------------------------------------
    // Pause / halt migration
    // -------------------------------------------------------------------------

    /**
     * Transitions the given audit record to 'Failed' status to signal a pause
     * or halt of the running migration pipeline.
     * Delegates update to ARM_MigrationService.updateAuditStatus.
     *
     * @param  auditId  Id of the ARM_MigrationAudit__c record to pause.
     * @throws AuraHandledException when auditId is null.
     *
     * @calledBy    migrationWizard (LWC)
     * @testMethods test_pauseMigration_validId_updatesStatus,
     *              test_pauseMigration_nullId_throwsAuraException
     */
    @AuraEnabled
    public static void pauseMigration(Id auditId) {
        if (auditId == null) {
            throw new AuraHandledException('auditId is required to pause a migration.');
        }
        ARM_MigrationService.updateAuditStatus(new Set<Id>{ auditId }, 'Failed');
    }

    // -------------------------------------------------------------------------
    // Get migration status
    // -------------------------------------------------------------------------

    /**
     * Returns the ARM_MigrationAudit__c record for the given Id, including
     * Status__c, Migration_Start__c, Migration_End__c, Error_Message__c,
     * ErrorLog__c, and Detail__c.
     * Delegates query to ARM_MigrationService.getAuditRecord.
     *
     * @param  auditId  Id of the ARM_MigrationAudit__c record to retrieve.
     * @return The audit record, or null when no matching record is found.
     * @throws AuraHandledException when auditId is null.
     *
     * @calledBy    migrationWizard (LWC)
     * @testMethods test_getMigrationStatus_validId_returnsRecord,
     *              test_getMigrationStatus_nullId_throwsAuraException,
     *              test_getMigrationStatus_unknownId_returnsNull
     */
    @AuraEnabled(cacheable=false)
    public static ARM_MigrationAudit__c getMigrationStatus(Id auditId) {
        if (auditId == null) {
            throw new AuraHandledException('auditId is required to retrieve migration status.');
        }
        return ARM_MigrationService.getAuditRecord(auditId);
    }
}
