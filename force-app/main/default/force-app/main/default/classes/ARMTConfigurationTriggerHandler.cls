/**
 * @file              ARMTConfigurationTriggerHandler.cls
 * @description       Trigger handler that processes new ARMT_Catalogue__c records and enforces
 *                    duplicate prevention by setting the ARMT_Duplicate_Check__c flag when a
 *                    record with the same Object_Type__c and Name already exists.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ARMT_TriggerHandlers
 *
 * @dependencies      DataAccessException, ScanException
 * @calledBy          ARMTConfigurationTrigger
 * @testClass         ARMT_ConfigurationScannerTest
 *
 * @see               HLD-ARMT-V1.0 Section 5.2, BR-013
 */

/**
 * Trigger handler for ARMT_Catalogue__c.
 *
 * Responsibilities:
 *   - Detect duplicate ARMT_Catalogue__c records by Object_Type__c + Name combination.
 *   - Set ARMT_Duplicate_Check__c = true on duplicates to trigger BR-013 validation rule.
 *   - Enforce bulkification — processes entire Trigger.new list in a single SOQL query.
 *
 * Threading: Designed for synchronous trigger context only.
 *
 * @testClass ARMT_ConfigurationScannerTest
 */
public with sharing class ARMTConfigurationTriggerHandler {

    /**
     * Handles before-insert events on ARMT_Catalogue__c.
     * Queries for existing records with the same Object_Type__c and Name,
     * and sets ARMT_Duplicate_Check__c = true on any incoming duplicates.
     *
     * @param  newRecords  List of new ARMT_Catalogue__c records from Trigger.new.
     *
     * @calledBy ARMTConfigurationTrigger
     * @testMethods test_handleBeforeInsert_noDuplicate_noFlagSet, test_handleBeforeInsert_duplicate_flagSet, test_handleBeforeInsert_bulk_200Records
     */
    public void handleBeforeInsert(List<ARMT_Catalogue__c> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        // Build a set of composite keys (ObjectType|Name) for incoming records
        Set<String> incomingKeys = new Set<String>();
        for (ARMT_Catalogue__c rec : newRecords) {
            if (String.isNotBlank(rec.Object_Type__c) && String.isNotBlank(rec.Name)) {
                incomingKeys.add(buildCompositeKey(rec.Object_Type__c, rec.Name));
            }
        }

        if (incomingKeys.isEmpty()) {
            return;
        }

        // Query existing records with matching Object_Type__c values (bulkified)
        Set<String> objectTypes = new Set<String>();
        Set<String> names = new Set<String>();
        for (ARMT_Catalogue__c rec : newRecords) {
            if (String.isNotBlank(rec.Object_Type__c)) {
                objectTypes.add(rec.Object_Type__c);
            }
            if (String.isNotBlank(rec.Name)) {
                names.add(rec.Name);
            }
        }

        Set<String> existingKeys = new Set<String>();
        try {
            List<ARMT_Catalogue__c> existingRecords = [
                SELECT Id, Object_Type__c, Name
                FROM ARMT_Catalogue__c
                WHERE Object_Type__c IN :objectTypes
                AND Name IN :names
                WITH SECURITY_ENFORCED
            ];
            for (ARMT_Catalogue__c existing : existingRecords) {
                existingKeys.add(buildCompositeKey(existing.Object_Type__c, existing.Name));
            }
        } catch (System.QueryException qe) {
            throw new DataAccessException('Failed to query existing ARMT_Catalogue__c records for duplicate check: ' + qe.getMessage());
        }

        // Flag duplicates
        for (ARMT_Catalogue__c rec : newRecords) {
            if (String.isNotBlank(rec.Object_Type__c) && String.isNotBlank(rec.Name)) {
                String key = buildCompositeKey(rec.Object_Type__c, rec.Name);
                if (existingKeys.contains(key)) {
                    rec.ARMT_Duplicate_Check__c = true;
                }
            }
        }
    }

    /**
     * Handles before-update events on ARMT_Catalogue__c.
     * Re-evaluates duplicate status when Object_Type__c or Name changes.
     *
     * @param  newRecords  List of updated ARMT_Catalogue__c records from Trigger.new.
     * @param  oldMap      Map of old ARMT_Catalogue__c records from Trigger.oldMap.
     *
     * @calledBy ARMTConfigurationTrigger
     * @testMethods test_handleBeforeUpdate_nameChange_duplicateDetected
     */
    public void handleBeforeUpdate(List<ARMT_Catalogue__c> newRecords, Map<Id, ARMT_Catalogue__c> oldMap) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        // Only process records where Object_Type__c or Name changed
        List<ARMT_Catalogue__c> changedRecords = new List<ARMT_Catalogue__c>();
        for (ARMT_Catalogue__c rec : newRecords) {
            ARMT_Catalogue__c oldRec = oldMap.get(rec.Id);
            if (oldRec != null && (rec.Object_Type__c != oldRec.Object_Type__c || rec.Name != oldRec.Name)) {
                changedRecords.add(rec);
            }
        }

        if (changedRecords.isEmpty()) {
            return;
        }

        Set<String> objectTypes = new Set<String>();
        Set<String> names = new Set<String>();
        for (ARMT_Catalogue__c rec : changedRecords) {
            if (String.isNotBlank(rec.Object_Type__c)) {
                objectTypes.add(rec.Object_Type__c);
            }
            if (String.isNotBlank(rec.Name)) {
                names.add(rec.Name);
            }
        }

        Set<String> existingKeys = new Set<String>();
        try {
            List<ARMT_Catalogue__c> existingRecords = [
                SELECT Id, Object_Type__c, Name
                FROM ARMT_Catalogue__c
                WHERE Object_Type__c IN :objectTypes
                AND Name IN :names
                AND Id NOT IN :changedRecords
                WITH SECURITY_ENFORCED
            ];
            for (ARMT_Catalogue__c existing : existingRecords) {
                existingKeys.add(buildCompositeKey(existing.Object_Type__c, existing.Name));
            }
        } catch (System.QueryException qe) {
            throw new DataAccessException('Failed to query existing ARMT_Catalogue__c records for duplicate check on update: ' + qe.getMessage());
        }

        for (ARMT_Catalogue__c rec : changedRecords) {
            if (String.isNotBlank(rec.Object_Type__c) && String.isNotBlank(rec.Name)) {
                String key = buildCompositeKey(rec.Object_Type__c, rec.Name);
                rec.ARMT_Duplicate_Check__c = existingKeys.contains(key);
            }
        }
    }

    /** Builds a composite key from object type and name for duplicate detection. */
    private String buildCompositeKey(String objectType, String name) {
        return objectType + '|' + name;
    }
}
