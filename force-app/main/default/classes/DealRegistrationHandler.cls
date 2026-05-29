/**
 * @file              DealRegistrationHandler.cls
 * @description       Handler class for DealRegistrationTrigger. Orchestrates
 *                    Opportunity creation on Deal Registration insert, establishes
 *                    bi-directional ID linkage, and synchronizes mapped fields on
 *                    update until Deal Registration status reaches Approved.
 *                    Field mappings are driven by Deal_Field_Mapping__mdt records,
 *                    enabling configuration without code changes.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-29
 * @lastModified      2026-05-29
 * @group             PartnerRegistrationAutomation
 *
 * @dependencies      Deal_Field_Mapping__mdt (Custom Metadata Type),
 *                    Deal_Registration__c (Custom Object),
 *                    Opportunity (Standard Object)
 * @calledBy          DealRegistrationTrigger
 * @testClass         DealRegistrationHandlerTest
 *
 * @see               LLD - Partner Registration Automation (May 28, 2026)
 */
public with sharing class DealRegistrationHandler {

    /**
     * Handler for Deal Registration triggers.
     *
     * Responsibilities:
     *   - Create one Opportunity per inserted Deal Registration.
     *   - Populate Opportunity fields via CMT-driven dynamic field mappings.
     *   - Set Opportunity.Deal_Registration__c and Deal_Registration__c.Opportunity__c.
     *   - On update, re-sync mapped fields unless status is Approved.
     *   - Guard against recursive trigger execution with a static flag.
     *
     * Threading: static isRunning flag prevents recursion within a single
     * transaction. Not safe for use across @future or Queueable boundaries
     * where static state resets.
     *
     * @testClass DealRegistrationHandlerTest
     */

    // ─── Constants ────────────────────────────────────────────────────────────

    private static final String APPROVED_STATUS     = 'Approved';
    private static final String DEFAULT_OPP_STAGE   = 'Qualification';
    private static final Integer DEFAULT_CLOSE_DAYS = 90;

    // ─── Recursion guard ──────────────────────────────────────────────────────

    /** Prevents re-entrant trigger execution (e.g. when updating DR to set Opportunity__c). */
    @TestVisible
    private static Boolean isRunning = false;

    // ─── Test seam ────────────────────────────────────────────────────────────

    /**
     * Inject in-memory CMT records in unit tests to avoid a live SOQL
     * against the org's metadata store. Leave null in all production paths.
     */
    @TestVisible
    private static List<Deal_Field_Mapping__mdt> testMappingOverride = null;

    // ─── Inner exception ──────────────────────────────────────────────────────

    /** Thrown when DML or validation fails inside this handler. */
    public class DealRegistrationHandlerException extends Exception {}

    // ─── Public API ───────────────────────────────────────────────────────────

    /**
     * Creates an Opportunity for every newly inserted Deal Registration, applies
     * CMT field mappings, then writes back the Opportunity ID to the Deal
     * Registration and the Deal Registration ID to the Opportunity.
     *
     * Bulk-safe: processes all records in a single set of DML statements.
     * No SOQL or DML inside loops.
     *
     * @param dealRegistrations  Immutable Trigger.new list of inserted Deal Registration records.
     *
     * @calledBy DealRegistrationTrigger (after insert)
     * @testMethods test_afterInsert_createsLinkedOpportunity,
     *              test_afterInsert_mapsFieldsFromCMT,
     *              test_bulkInsert_200Records
     */
    public static void processAfterInsert(List<Deal_Registration__c> dealRegistrations) {
        if (isRunning) {
            return;
        }
        isRunning = true;
        try {
            List<Deal_Field_Mapping__mdt> mappings = getActiveMappings();

            // Build Opportunities — keep a parallel list so we can map back by index
            List<Opportunity> oppsToInsert = new List<Opportunity>();

            for (Deal_Registration__c dr : dealRegistrations) {
                Opportunity opp = new Opportunity();
                opp.Name       = String.isNotBlank(dr.Name) ? dr.Name : 'Deal Registration';
                opp.StageName  = DEFAULT_OPP_STAGE;
                opp.CloseDate  = Date.today().addDays(DEFAULT_CLOSE_DAYS);
                opp.Deal_Registration__c = dr.Id;

                // Apply dynamic field mappings from Custom Metadata
                for (Deal_Field_Mapping__mdt mapping : mappings) {
                    Object fieldValue = dr.get(mapping.Source_Field_API_Name__c);
                    if (fieldValue != null) {
                        opp.put(mapping.Target_Field_API_Name__c, fieldValue);
                    }
                }

                oppsToInsert.add(opp);
            }

            if (oppsToInsert.isEmpty()) {
                return;
            }

            try {
                insert oppsToInsert;
            } catch (DmlException ex) {
                System.debug(
                    LoggingLevel.ERROR,
                    'DealRegistrationHandler.processAfterInsert — Opportunity insert failed: '
                        + ex.getMessage()
                );
                throw new DealRegistrationHandlerException(
                    'Failed to create Opportunity: ' + ex.getMessage(), ex
                );
            }

            // Write the new Opportunity ID back to each Deal Registration
            List<Deal_Registration__c> drsToLink = new List<Deal_Registration__c>();
            for (Integer i = 0; i < dealRegistrations.size(); i++) {
                drsToLink.add(new Deal_Registration__c(
                    Id             = dealRegistrations[i].Id,
                    Opportunity__c = oppsToInsert[i].Id
                ));
            }

            try {
                update drsToLink;
            } catch (DmlException ex) {
                System.debug(
                    LoggingLevel.ERROR,
                    'DealRegistrationHandler.processAfterInsert — DR linkage update failed: '
                        + ex.getMessage()
                );
                throw new DealRegistrationHandlerException(
                    'Failed to link Deal Registration to Opportunity: ' + ex.getMessage(), ex
                );
            }

        } finally {
            isRunning = false;
        }
    }

    /**
     * Synchronizes mapped fields from updated Deal Registration records to their
     * linked Opportunities. Skips synchronization when:
     *   - The record has already been processed in this transaction (isRunning).
     *   - The Deal Registration status is Approved.
     *   - No linked Opportunity exists.
     *   - No CMT-mapped source field has changed.
     *
     * Bulk-safe: collects all Opportunity updates and applies them in a single DML.
     *
     * @param dealRegistrations  Immutable Trigger.new list of updated Deal Registration records.
     * @param oldMap             Map of Deal Registration ID to pre-update record state.
     *
     * @calledBy DealRegistrationTrigger (after update)
     * @testMethods test_afterUpdate_syncsFieldsWhenNotApproved,
     *              test_afterUpdate_stopsWhenApproved
     */
    public static void processAfterUpdate(
        List<Deal_Registration__c> dealRegistrations,
        Map<Id, Deal_Registration__c> oldMap
    ) {
        if (isRunning) {
            return;
        }

        List<Deal_Field_Mapping__mdt> mappings = getActiveMappings();
        if (mappings.isEmpty()) {
            return;
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Deal_Registration__c dr : dealRegistrations) {
            // Skip if approved or no linked Opportunity
            if (dr.Status__c == APPROVED_STATUS || dr.Opportunity__c == null) {
                continue;
            }

            // Only sync when at least one mapped source field has changed
            Deal_Registration__c oldDr = oldMap.get(dr.Id);
            Boolean hasChanges = false;
            for (Deal_Field_Mapping__mdt mapping : mappings) {
                if (dr.get(mapping.Source_Field_API_Name__c)
                        != oldDr.get(mapping.Source_Field_API_Name__c)) {
                    hasChanges = true;
                    break;
                }
            }

            if (!hasChanges) {
                continue;
            }

            // Build the Opportunity update record using dynamic field mappings
            Opportunity opp = new Opportunity(Id = dr.Opportunity__c);
            for (Deal_Field_Mapping__mdt mapping : mappings) {
                opp.put(
                    mapping.Target_Field_API_Name__c,
                    dr.get(mapping.Source_Field_API_Name__c)
                );
            }
            oppsToUpdate.add(opp);
        }

        if (!oppsToUpdate.isEmpty()) {
            try {
                update oppsToUpdate;
            } catch (DmlException ex) {
                System.debug(
                    LoggingLevel.ERROR,
                    'DealRegistrationHandler.processAfterUpdate — Opportunity sync failed: '
                        + ex.getMessage()
                );
                throw new DealRegistrationHandlerException(
                    'Failed to synchronize Opportunity fields: ' + ex.getMessage(), ex
                );
            }
        }
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    /**
     * Returns active field mapping metadata records.
     * In test context returns testMappingOverride to allow isolated unit tests
     * without requiring live CMT records in the org.
     */
    private static List<Deal_Field_Mapping__mdt> getActiveMappings() {
        if (testMappingOverride != null) {
            return testMappingOverride;
        }
        return [
            SELECT Source_Field_API_Name__c, Target_Field_API_Name__c
            FROM   Deal_Field_Mapping__mdt
            WHERE  Is_Active__c = true
        ];
    }
}
