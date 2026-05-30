/**
 * @file              DealRegistrationHandler.cls
 * @description       Handler class encapsulating core logic for processing Deal
 *                    Registration records and synchronizing corresponding
 *                    Opportunity records. Implements the single-trigger,
 *                    handler-class pattern for DealRegistrationTrigger.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             PartnerRegistrationAutomation
 *
 * @dependencies      Deal_Registration_Field_Mapping__mdt (Custom Metadata Type)
 * @calledBy          DealRegistrationTrigger
 * @testClass         DealRegistrationHandlerTest
 *
 * @see               LLD - Sr Developer creates combined technical design (draft)
 */

/**
 * Handler for Deal Registration trigger events.
 *
 * Responsibilities:
 *   - Create Opportunity records from new Deal Registration records.
 *   - Establish bi-directional lookup links between Deal Registration and Opportunity.
 *   - Synchronize mapped fields from Deal Registration to Opportunity on updates
 *     (ceases once Deal Registration Status equals Approved).
 *   - Retrieve active field mappings dynamically from Deal_Registration_Field_Mapping__mdt.
 *
 * Threading: uses a static recursion guard (isRunning) to prevent infinite loops
 * caused by the internal DML update on Deal_Registration__c that sets Opportunity__c.
 *
 * @testClass DealRegistrationHandlerTest
 */
public with sharing class DealRegistrationHandler {

    private static final String APPROVED_STATUS = 'Approved';
    private static final String DEFAULT_STAGE   = 'Qualification';

    /** Recursion guard — prevents re-entry when the handler updates Deal_Registration__c internally. */
    @TestVisible
    private static Boolean isRunning = false;

    /**
     * Handles after-insert events. Creates a linked Opportunity for each new
     * Deal Registration and establishes bi-directional lookup fields on both
     * the Opportunity (Deal_Registration__c) and the Deal Registration (Opportunity__c).
     *
     * @param dealRegistrations  Trigger.new list of newly inserted Deal Registrations.
     *
     * @calledBy  DealRegistrationTrigger
     * @testMethods test_processAfterInsert_singleRecord_createsLinkedOpportunity,
     *              test_processAfterInsert_bulk_createsOpportunitiesForAllRecords
     */
    public void processAfterInsert(List<Deal_Registration__c> dealRegistrations) {
        if (isRunning) {
            return;
        }
        isRunning = true;
        try {
            List<Deal_Registration_Field_Mapping__mdt> mappings = getActiveMappings();
            if (mappings.isEmpty()) {
                return;
            }

            List<Opportunity> oppsToInsert = new List<Opportunity>();
            for (Deal_Registration__c dr : dealRegistrations) {
                oppsToInsert.add(buildOpportunity(dr, mappings));
            }

            insert oppsToInsert;

            // Establish bi-directional links after Opportunity Ids are generated
            List<Opportunity> oppsToUpdate = new List<Opportunity>();
            List<Deal_Registration__c> drsToUpdate = new List<Deal_Registration__c>();
            for (Integer i = 0; i < dealRegistrations.size(); i++) {
                oppsToInsert[i].Deal_Registration__c = dealRegistrations[i].Id;
                oppsToUpdate.add(oppsToInsert[i]);
                drsToUpdate.add(new Deal_Registration__c(
                    Id = dealRegistrations[i].Id,
                    Opportunity__c = oppsToInsert[i].Id
                ));
            }
            update oppsToUpdate;
            update drsToUpdate;

        } catch (DmlException ex) {
            System.debug(LoggingLevel.ERROR,
                'DealRegistrationHandler.processAfterInsert DML error: ' + ex.getMessage());
            for (Deal_Registration__c dr : dealRegistrations) {
                dr.addError('Failed to create linked Opportunity: ' + ex.getMessage());
            }
        } finally {
            isRunning = false;
        }
    }

    /**
     * Handles after-update events. Synchronizes mapped fields from Deal Registration
     * to the linked Opportunity, provided Status is not Approved. If the Status is
     * Approved, synchronization ceases permanently for that record.
     *
     * @param newRecords  Trigger.new list of updated Deal Registrations.
     * @param oldMap      Trigger.oldMap keyed by Deal Registration Id.
     *
     * @calledBy  DealRegistrationTrigger
     * @testMethods test_processAfterUpdate_notApproved_syncsFields,
     *              test_processAfterUpdate_approved_doesNotSync
     */
    public void processAfterUpdate(List<Deal_Registration__c> newRecords,
                                   Map<Id, Deal_Registration__c> oldMap) {
        if (isRunning) {
            return;
        }
        isRunning = true;
        try {
            List<Deal_Registration_Field_Mapping__mdt> mappings = getActiveMappings();
            if (mappings.isEmpty()) {
                return;
            }

            Set<Id> oppIds = new Set<Id>();
            for (Deal_Registration__c dr : newRecords) {
                if (dr.Opportunity__c != null && dr.Status__c != APPROVED_STATUS) {
                    oppIds.add(dr.Opportunity__c);
                }
            }

            if (oppIds.isEmpty()) {
                return;
            }

            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
                [SELECT Id, Name, AccountId, Amount, CloseDate, Description,
                        Primary_Contact__c
                 FROM Opportunity
                 WHERE Id IN :oppIds
                 WITH SECURITY_ENFORCED]
            );

            List<Opportunity> oppsToUpdate = new List<Opportunity>();
            Set<Id> processedOppIds = new Set<Id>();
            for (Deal_Registration__c dr : newRecords) {
                if (dr.Opportunity__c == null || dr.Status__c == APPROVED_STATUS) {
                    continue;
                }
                if (processedOppIds.contains(dr.Opportunity__c)) {
                    continue;
                }
                Opportunity opp = oppMap.get(dr.Opportunity__c);
                if (opp == null) {
                    continue;
                }
                applyMappings(dr, opp, mappings);
                oppsToUpdate.add(opp);
                processedOppIds.add(dr.Opportunity__c);
            }

            if (!oppsToUpdate.isEmpty()) {
                update oppsToUpdate;
            }

        } catch (DmlException ex) {
            System.debug(LoggingLevel.ERROR,
                'DealRegistrationHandler.processAfterUpdate DML error: ' + ex.getMessage());
            for (Deal_Registration__c dr : newRecords) {
                dr.addError('Failed to synchronize linked Opportunity: ' + ex.getMessage());
            }
        } finally {
            isRunning = false;
        }
    }

    /**
     * Queries all active field mapping records from the Custom Metadata Type.
     * CMT records are always accessible regardless of running-user FLS.
     *
     * @return List of active Deal_Registration_Field_Mapping__mdt records.
     */
    private List<Deal_Registration_Field_Mapping__mdt> getActiveMappings() {
        return [
            SELECT Id, Source_Field_API_Name__c, Target_Field_API_Name__c
            FROM Deal_Registration_Field_Mapping__mdt
            WHERE Is_Active__c = true
        ];
    }

    /**
     * Constructs a new Opportunity with default required-field values, then
     * overlays the metadata-driven field mappings from the source Deal Registration.
     *
     * @param dr        Source Deal Registration record.
     * @param mappings  Active field-mapping configuration records.
     * @return          Unsaved Opportunity ready for insert.
     */
    private Opportunity buildOpportunity(Deal_Registration__c dr,
                                          List<Deal_Registration_Field_Mapping__mdt> mappings) {
        Opportunity opp = new Opportunity();
        opp.Name      = dr.Name + ' - Opportunity';
        opp.StageName = DEFAULT_STAGE;
        opp.CloseDate = Date.today().addDays(90);
        applyMappings(dr, opp, mappings);
        return opp;
    }

    /**
     * Dynamically copies non-null field values from a Deal Registration to an
     * Opportunity using the active metadata-driven mapping configuration.
     * Uses SObject.get() / SObject.put() for configuration-driven field access
     * without code changes when mappings are added or modified.
     *
     * @param dr        Source Deal Registration record (fully populated from trigger).
     * @param opp       Target Opportunity record to update in memory.
     * @param mappings  Active field-mapping configuration records.
     */
    private void applyMappings(Deal_Registration__c dr, Opportunity opp,
                                List<Deal_Registration_Field_Mapping__mdt> mappings) {
        for (Deal_Registration_Field_Mapping__mdt mapping : mappings) {
            Object fieldValue = dr.get(mapping.Source_Field_API_Name__c);
            if (fieldValue != null) {
                opp.put(mapping.Target_Field_API_Name__c, fieldValue);
            }
        }
    }
}
