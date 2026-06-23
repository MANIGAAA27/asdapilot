/**
 * @file              MigrationProcessHandler.cls
 * @description       Handles the migration process asynchronously for specified CPQ record IDs.
 *                    Implements Queueable for async execution and Database.AllowsCallouts
 *                    to support cross-org REST callouts. Provides:
 *                      - handleAfterInsert() — called by ARM_MigrationTrigger to enqueue
 *                        a job when new audit records are created with Status = 'New'.
 *                      - startMigrationAsync() — @AuraEnabled entry point for migrationWizard.
 *                      - execute() — creates Migration_Log__c stubs and launches DataTransformBatch.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-23
 * @lastModified      2026-06-23
 * @group             MigrationProcessing
 *
 * @dependencies      ARM_MigrationAudit__c, Migration_Log__c, DataTransformBatch
 * @calledBy          ARM_MigrationTrigger (trigger dispatch), migrationWizard (LWC)
 * @testClass         MigrationProcessHandlerTest
 *
 * @see               HLD-CMP-001 ARMT_JobManagerService sequence diagram
 */

// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
/**
 * Queueable Apex handler that orchestrates the CPQ-to-ARM migration pipeline for
 * a set of CPQ record IDs.
 *
 * Responsibilities:
 *   - Create pending Migration_Log__c records for each CPQ record ID in scope.
 *   - Enqueue DataTransformBatch to process those logs asynchronously.
 *   - Provide a static trigger dispatch method and an @AuraEnabled LWC entry point.
 *   - Update ARM_MigrationAudit__c to 'Failed' when pre-conditions are not met.
 *
 * Threading: Queueable — called via System.enqueueJob(). Safe for up to 50 chained
 * jobs per transaction. AllowsCallouts to support cross-org API calls in future sprints.
 *
 * @testClass MigrationProcessHandlerTest
 */
public with sharing class MigrationProcessHandler implements Queueable, Database.AllowsCallouts {

    @TestVisible private List<Id> cpqRecordIds;
    @TestVisible private Id migrationAuditId;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * Constructs a MigrationProcessHandler bound to specific CPQ IDs and audit record.
     *
     * @param  cpqIds   List of CPQ source record IDs to process.
     * @param  auditId  The ARM_MigrationAudit__c record that tracks this job.
     *
     * @calledBy    handleAfterInsert, startMigrationAsync
     * @testMethods test_execute_emptyIds_updatesAuditFailed,
     *              test_execute_withIds_createsMigrationLogs
     */
    public MigrationProcessHandler(List<Id> cpqIds, Id auditId) {
        this.cpqRecordIds = cpqIds;
        this.migrationAuditId = auditId;
    }

    // -------------------------------------------------------------------------
    // Trigger dispatch — called by ARM_MigrationTrigger
    // -------------------------------------------------------------------------

    /**
     * Static dispatch method invoked by ARM_MigrationTrigger after insert of
     * ARM_MigrationAudit__c records. Collects CPQ record IDs from new audit
     * records with Status = 'New' and enqueues one job per audit record.
     * Bulkified — handles multiple Trigger.new records in a single transaction.
     *
     * @param  newAuditRecords  Trigger.new list from ARM_MigrationTrigger.
     *
     * @calledBy    ARM_MigrationTrigger (after insert)
     * @testMethods test_handleAfterInsert_newStatus_enqueuesJob,
     *              test_handleAfterInsert_nonNewStatus_noJob
     */
    public static void handleAfterInsert(List<ARM_MigrationAudit__c> newAuditRecords) {
        for (ARM_MigrationAudit__c auditRecord : newAuditRecords) {
            if (auditRecord.Status__c == 'New') {
                List<Id> cpqIds = new List<Id>();
                if (auditRecord.CPQ_Record_Id__c != null) {
                    cpqIds.add((Id) auditRecord.CPQ_Record_Id__c);
                }
                System.enqueueJob(new MigrationProcessHandler(cpqIds, auditRecord.Id));
            }
        }
    }

    // -------------------------------------------------------------------------
    // @AuraEnabled entry point — called by migrationWizard LWC
    // -------------------------------------------------------------------------

    /**
     * Creates an ARM_MigrationAudit__c record, sets initial status to 'In Progress',
     * and enqueues this handler to process the provided CPQ record IDs.
     * Returns the new audit record Id for the LWC to display.
     *
     * @param  cpqRecordIds  List of CPQ source record IDs to migrate.
     * @return Id of the newly created ARM_MigrationAudit__c record.
     * @throws AuraHandledException when the insert or enqueue fails.
     *
     * @calledBy    migrationWizard (LWC)
     * @testMethods test_startMigrationAsync_createsAuditRecord,
     *              test_startMigrationAsync_enqueuesJob
     */
    @AuraEnabled
    public static Id startMigrationAsync(List<Id> cpqRecordIds) {
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Status__c = 'In Progress',
            CPQ_Record_Id__c = (cpqRecordIds != null && !cpqRecordIds.isEmpty())
                ? String.valueOf(cpqRecordIds[0])
                : null,
            Migration_Start__c = DateTime.now()
        );

        try {
            insert audit;
        } catch (DmlException ex) {
            throw new AuraHandledException('Failed to create migration audit record: ' + ex.getMessage());
        }

        System.enqueueJob(new MigrationProcessHandler(cpqRecordIds, audit.Id));
        return audit.Id;
    }

    // -------------------------------------------------------------------------
    // Queueable execute
    // -------------------------------------------------------------------------

    /**
     * Main async execution: creates pending Migration_Log__c records for each
     * CPQ record ID and then enqueues DataTransformBatch. If the ID list is
     * empty, marks the audit record as Failed immediately.
     *
     * @param  qc  QueueableContext provided by the platform.
     *
     * @calledBy    (Salesforce platform — async execution)
     * @testMethods test_execute_emptyIds_updatesAuditFailed,
     *              test_execute_withIds_createsMigrationLogs
     */
    public void execute(QueueableContext qc) {
        if (cpqRecordIds == null || cpqRecordIds.isEmpty()) {
            setAuditStatus(migrationAuditId, 'Failed', 'No CPQ record IDs provided for migration.');
            return;
        }

        List<Migration_Log__c> logsToInsert = new List<Migration_Log__c>();
        for (Integer i = 0; i < cpqRecordIds.size(); i++) {
            logsToInsert.add(new Migration_Log__c(
                MigrationStatus__c = 'Pending',
                MigrationDate__c = Date.today()
            ));
        }

        Database.insert(logsToInsert, false);
        Database.executeBatch(new DataTransformBatch(migrationAuditId), 100);
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /** Updates Status__c, Error_Message__c, and Migration_End__c on the audit record. */
    private static void setAuditStatus(Id auditId, String status, String errorMsg) {
        if (auditId == null) {
            return;
        }
        ARM_MigrationAudit__c audit = new ARM_MigrationAudit__c(
            Id = auditId,
            Status__c = status,
            Error_Message__c = errorMsg,
            Migration_End__c = DateTime.now()
        );
        update audit;
    }
}
