/**
 * @file              ARM_MigrationDomain.cls
 * @description       Domain layer for ARM_MigrationAudit__c. Enforces field-level
 *                    validation before insert and update DML events. Validates required
 *                    fields, allowed status transitions, and field length constraints.
 *                    Called exclusively from MigrationProcessHandler (trigger handler).
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-23
 * @lastModified      2026-06-23
 * @group             MigrationProcessing
 *
 * @dependencies      ARM_MigrationAudit__c
 * @calledBy          MigrationProcessHandler
 * @testClass         ARM_MigrationDomainTest
 *
 * @see               HLD-CMP Advanced Record Migration Tool (ARMT)
 */

// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
/**
 * Domain validation class for ARM_MigrationAudit__c records.
 *
 * Responsibilities:
 *   - Validate required fields before insert (Status__c non-blank).
 *   - Validate allowed status transitions before update.
 *   - Add field-level errors to records using SObject.addError().
 *   - Never perform DML or SOQL — pure in-memory validation.
 *
 * Threading: all public methods are static and operate on List<SObject>; safe
 * to call from bulkified trigger handlers.
 *
 * @testClass ARM_MigrationDomainTest
 */
public with sharing class ARM_MigrationDomain {

    // -------------------------------------------------------------------------
    // Allowed status transitions: key = old status, value = allowed new statuses
    // -------------------------------------------------------------------------

    @TestVisible
    private static final Map<String, Set<String>> ALLOWED_TRANSITIONS =
        new Map<String, Set<String>>{
            'New'         => new Set<String>{ 'In Progress', 'Failed' },
            'In Progress' => new Set<String>{ 'Completed', 'Failed' },
            'Completed'   => new Set<String>{ 'Rolled Back' },
            'Failed'      => new Set<String>{ 'New' },
            'Rolled Back' => new Set<String>{ 'New' }
        };

    // -------------------------------------------------------------------------
    // Before-insert validation
    // -------------------------------------------------------------------------

    /**
     * Validates ARM_MigrationAudit__c records before insert. Adds field errors
     * to records that fail validation so the trigger framework can roll back
     * individual rows without aborting the entire batch.
     *
     * Validations:
     *   - Status__c must be non-blank (defaults to 'New' in practice).
     *   - CPQ_Record_Id__c, when supplied, must be 15 or 18 characters long.
     *
     * @param  newRecords  Trigger.new list of ARM_MigrationAudit__c records.
     *
     * @calledBy    MigrationProcessHandler.onBeforeInsert
     * @testMethods test_validateBeforeInsert_blankStatus_addsError,
     *              test_validateBeforeInsert_validRecord_noError,
     *              test_validateBeforeInsert_invalidIdLength_addsError
     */
    public static void validateBeforeInsert(List<ARM_MigrationAudit__c> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }
        for (ARM_MigrationAudit__c record : newRecords) {
            if (String.isBlank(record.Status__c)) {
                record.Status__c.addError('Status is required.');
            }
            if (record.CPQ_Record_Id__c != null) {
                Integer idLen = record.CPQ_Record_Id__c.trim().length();
                if (idLen != 15 && idLen != 18) {
                    record.CPQ_Record_Id__c.addError(
                        'CPQ Record Id must be a valid 15- or 18-character Salesforce Id.'
                    );
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Before-update validation
    // -------------------------------------------------------------------------

    /**
     * Validates ARM_MigrationAudit__c records before update. Enforces the
     * allowed status transition matrix (see ALLOWED_TRANSITIONS). Adds a
     * Status__c field error on records attempting an illegal transition.
     *
     * @param  newRecords  Trigger.new list of updated records.
     * @param  oldMap      Trigger.oldMap keyed by record Id.
     *
     * @calledBy    MigrationProcessHandler.onBeforeUpdate
     * @testMethods test_validateBeforeUpdate_allowedTransition_noError,
     *              test_validateBeforeUpdate_illegalTransition_addsError,
     *              test_validateBeforeUpdate_noStatusChange_noError,
     *              test_validateBeforeUpdate_emptyList_noException
     */
    public static void validateBeforeUpdate(
        List<ARM_MigrationAudit__c> newRecords,
        Map<Id, ARM_MigrationAudit__c> oldMap
    ) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }
        for (ARM_MigrationAudit__c record : newRecords) {
            ARM_MigrationAudit__c oldRecord = oldMap.get(record.Id);
            if (oldRecord == null) {
                continue;
            }
            String oldStatus = oldRecord.Status__c;
            String newStatus = record.Status__c;

            if (oldStatus == newStatus) {
                continue;
            }

            Set<String> allowed = ALLOWED_TRANSITIONS.get(oldStatus);
            if (allowed == null || !allowed.contains(newStatus)) {
                record.Status__c.addError(
                    'Invalid status transition from \'' + oldStatus
                    + '\' to \'' + newStatus + '\'.'
                );
            }
        }
    }
}
