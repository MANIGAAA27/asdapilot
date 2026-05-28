/**
 * @file              DealRegistrationHandler.cls
 * @description       Handler class for DealRegistrationTrigger. Encapsulates
 *                    all business logic for creating and synchronizing
 *                    Opportunity records from Deal_Registration__c records.
 *                    Field mappings are driven by Deal_Registration_Field_Mapping__mdt
 *                    Custom Metadata Type records, allowing configuration
 *                    without code changes.
 *
 *                    On insert: creates a new Opportunity per Deal Registration,
 *                    populates mapped fields, and establishes bi-directional
 *                    lookup linkage.
 *
 *                    On update: synchronizes mapped fields to the linked
 *                    Opportunity unless the Deal Registration Status is
 *                    'Approved', at which point synchronization ceases.
 *
 * @author            ASDA Dev Agent
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             PartnerRegistrationAutomation
 *
 * @dependencies      Deal_Registration_Field_Mapping__mdt (Custom Metadata)
 * @calledBy          DealRegistrationTrigger
 * @testClass         DealRegistrationHandlerTest
 *
 * @see               LLD - Partner Registration Automation (Feature: Partner Registration Automation)
 */
public with sharing class DealRegistrationHandler {

    /** API name of the Approved status value — single source of truth. */
    @TestVisible
    private static final String APPROVED_STATUS = 'Approved';

    /** Default Opportunity stage assigned on creation. */
    @TestVisible
    private static final String DEFAULT_OPPORTUNITY_STAGE = 'Qualification';

    /** Recursion guard — prevents re-entrant trigger execution. */
    @TestVisible
    private static Boolean isExecuting = false;

    // ─────────────────────────────────────────────────────────────────────────
    // Public entry points (called by DealRegistrationTrigger)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Handles Opportunity creation when new Deal Registration records are
     * inserted. For each Deal Registration, a new Opportunity is created,
     * mapped fields are populated from active Custom Metadata mappings, and
     * bi-directional lookup fields are set on both records.
     *
     * Bulk-safe: processes all records in a single SOQL + DML cycle.
     *
     * @param  newRecords  List of newly inserted Deal_Registration__c
     *                     records from Trigger.new. Must not be null.
     * @return void
     *
     * @calledBy    DealRegistrationTrigger (after insert)
     * @testMethods test_processAfterInsert_singleRecord_createsOpportunity,
     *              test_processAfterInsert_bulkRecords_createsOpportunities,
     *              test_processAfterInsert_noActiveMappings_createsOpportunityWithDefaults
     */
    public void processAfterInsert(List<Deal_Registration__c> newRecords) {
        if (isExecuting || newRecords == null || newRecords.isEmpty()) {
            return;
        }
        isExecuting = true;
        try {
            List<Deal_Registration_Field_Mapping__mdt> activeMappings = getActiveMappings();
            List<Opportunity> opportunitiesToInsert = new List<Opportunity>();
            Map<Integer, Id> indexToDealRegId = new Map<Integer, Id>();

            Integer idx = 0;
            for (Deal_Registration__c rec : newRecords) {
                Opportunity opp = buildOpportunityFromDealRegistration(rec, activeMappings);
                opportunitiesToInsert.add(opp);
                indexToDealRegId.put(idx, rec.Id);
                idx++;
            }

            if (!opportunitiesToInsert.isEmpty()) {
                insert opportunitiesToInsert;

                // Build the list of Deal Registrations to update with the new Opportunity IDs
                List<Deal_Registration__c> dealRegsToUpdate = new List<Deal_Registration__c>();
                for (Integer i = 0; i < opportunitiesToInsert.size(); i++) {
                    Opportunity insertedOpp = opportunitiesToInsert.get(i);
                    Id dealRegId = indexToDealRegId.get(i);
                    dealRegsToUpdate.add(new Deal_Registration__c(
                        Id = dealRegId,
                        Linked_Opportunity__c = insertedOpp.Id
                    ));
                }
                update dealRegsToUpdate;
            }
        } catch (Exception ex) {
            logError('processAfterInsert', ex.getMessage(), ex.getStackTraceString());
            throw ex;
        } finally {
            isExecuting = false;
        }
    }

    /**
     * Handles Opportunity synchronization when Deal Registration records are
     * updated. For each updated Deal Registration that has a linked Opportunity
     * and whose Status is not 'Approved', mapped fields are synchronized to
     * the linked Opportunity.
     *
     * Bulk-safe: collects all Opportunity updates into a single DML call.
     *
     * @param  updatedRecords  List of updated Deal_Registration__c records
     *                         from Trigger.new. Must not be null.
     * @param  oldMap          Map of Deal_Registration__c Id to old record
     *                         values from Trigger.oldMap. Must not be null.
     * @return void
     *
     * @calledBy    DealRegistrationTrigger (after update)
     * @testMethods test_processAfterUpdate_mappedFieldChanged_updatesOpportunity,
     *              test_processAfterUpdate_statusApproved_doesNotUpdateOpportunity,
     *              test_processAfterUpdate_noLinkedOpportunity_skipsUpdate,
     *              test_processAfterUpdate_bulkRecords_updatesOpportunities
     */
    public void processAfterUpdate(
        List<Deal_Registration__c> updatedRecords,
        Map<Id, Deal_Registration__c> oldMap
    ) {
        if (isExecuting || updatedRecords == null || updatedRecords.isEmpty()) {
            return;
        }
        isExecuting = true;
        try {
            List<Deal_Registration_Field_Mapping__mdt> activeMappings = getActiveMappings();
            if (activeMappings.isEmpty()) {
                return;
            }

            // Collect IDs of linked Opportunities that need updating
            Map<Id, Deal_Registration__c> oppIdToRec = new Map<Id, Deal_Registration__c>();
            for (Deal_Registration__c rec : updatedRecords) {
                if (rec.Linked_Opportunity__c == null) {
                    continue;
                }
                if (APPROVED_STATUS.equals(rec.Status__c)) {
                    continue;
                }
                if (hasMappedFieldChanged(rec, oldMap.get(rec.Id), activeMappings)) {
                    oppIdToRec.put(rec.Linked_Opportunity__c, rec);
                }
            }

            if (oppIdToRec.isEmpty()) {
                return;
            }

            // Build Opportunity update list from collected mappings
            List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
            for (Id oppId : oppIdToRec.keySet()) {
                Deal_Registration__c sourceRec = oppIdToRec.get(oppId);
                Opportunity opp = new Opportunity(Id = oppId);
                applyMappingsToOpportunity(opp, sourceRec, activeMappings);
                opportunitiesToUpdate.add(opp);
            }

            if (!opportunitiesToUpdate.isEmpty()) {
                update opportunitiesToUpdate;
            }
        } catch (Exception ex) {
            logError('processAfterUpdate', ex.getMessage(), ex.getStackTraceString());
            throw ex;
        } finally {
            isExecuting = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Retrieves all active Deal_Registration_Field_Mapping__mdt records.
     * Results are not cached at instance level — each transaction gets a
     * fresh query (CMDT queries are free and not counted against SOQL limits).
     *
     * @return List of active mapping records. Empty list if none configured.
     */
    @TestVisible
    private List<Deal_Registration_Field_Mapping__mdt> getActiveMappings() {
        return [
            SELECT Id, DeveloperName, MasterLabel,
                   Source_Field_API_Name__c, Target_Field_API_Name__c, Is_Active__c
            FROM Deal_Registration_Field_Mapping__mdt
            WHERE Is_Active__c = true
        ];
    }

    /**
     * Constructs a new Opportunity record from a Deal Registration, applying
     * all active field mappings. Sets required Opportunity fields (Name,
     * StageName, CloseDate) to safe defaults when not covered by mappings.
     *
     * @param  sourceRec      The source Deal_Registration__c record.
     * @param  activeMappings List of active mapping metadata records.
     * @return A new, unsaved Opportunity with mapped fields populated.
     */
    @TestVisible
    private Opportunity buildOpportunityFromDealRegistration(
        Deal_Registration__c sourceRec,
        List<Deal_Registration_Field_Mapping__mdt> activeMappings
    ) {
        Opportunity opp = new Opportunity();
        opp.Name = sourceRec.Name + ' - Opportunity';
        opp.StageName = DEFAULT_OPPORTUNITY_STAGE;
        opp.CloseDate = Date.today().addDays(90);
        opp.Deal_Registration__c = sourceRec.Id;

        applyMappingsToOpportunity(opp, sourceRec, activeMappings);
        return opp;
    }

    /**
     * Applies active field mappings from a Deal Registration to an Opportunity
     * using dynamic field access via SObject.get() / SObject.put(). Skips
     * null source values to avoid overwriting existing Opportunity data with
     * blanks.
     *
     * @param  opp            The target Opportunity record to populate.
     * @param  sourceRec      The source Deal_Registration__c record.
     * @param  activeMappings List of active mapping metadata records.
     */
    @TestVisible
    private void applyMappingsToOpportunity(
        Opportunity opp,
        Deal_Registration__c sourceRec,
        List<Deal_Registration_Field_Mapping__mdt> activeMappings
    ) {
        for (Deal_Registration_Field_Mapping__mdt mapping : activeMappings) {
            String sourceField = mapping.Source_Field_API_Name__c;
            String targetField = mapping.Target_Field_API_Name__c;
            if (String.isBlank(sourceField) || String.isBlank(targetField)) {
                continue;
            }
            Object sourceValue = sourceRec.get(sourceField);
            if (sourceValue != null) {
                opp.put(targetField, sourceValue);
            }
        }
    }

    /**
     * Determines whether any mapped source field has changed between the new
     * and old versions of a Deal Registration record.
     *
     * @param  newRec         The updated Deal_Registration__c record (Trigger.new).
     * @param  oldRec         The previous Deal_Registration__c record (Trigger.oldMap value).
     * @param  activeMappings List of active mapping metadata records.
     * @return true if at least one mapped field value has changed; false otherwise.
     */
    @TestVisible
    private Boolean hasMappedFieldChanged(
        Deal_Registration__c newRec,
        Deal_Registration__c oldRec,
        List<Deal_Registration_Field_Mapping__mdt> activeMappings
    ) {
        if (oldRec == null) {
            return true;
        }
        for (Deal_Registration_Field_Mapping__mdt mapping : activeMappings) {
            String sourceField = mapping.Source_Field_API_Name__c;
            if (String.isBlank(sourceField)) {
                continue;
            }
            Object newValue = newRec.get(sourceField);
            Object oldValue = oldRec.get(sourceField);
            if (newValue != oldValue) {
                return true;
            }
        }
        return false;
    }

    /**
     * Logs an error message to the Apex debug log. In a production
     * implementation this would write to a custom Error_Log__c object;
     * debug logging is used here to avoid a dependency on an undeployed
     * logging object.
     *
     * @param  methodName   The name of the method where the error occurred.
     * @param  errorMessage The exception message.
     * @param  stackTrace   The exception stack trace string.
     */
    private void logError(String methodName, String errorMessage, String stackTrace) {
        System.debug(LoggingLevel.ERROR,
            'DealRegistrationHandler.' + methodName +
            ' | Error: ' + errorMessage +
            ' | Stack: ' + stackTrace
        );
    }
}
