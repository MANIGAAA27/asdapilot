/**
 * Handler for Deal Registration trigger logic.
 * Implements auto-creation of Opportunities and field synchronization.
 */
public with sharing class DealRegistrationTriggerHandler {

    /**
     * After insert: create linked Opportunity for each new Deal Registration.
     */
    public static void handleAfterInsert(List<Deal_Registration__c> newRecords) {
        List<Opportunity> oppsToInsert = new List<Opportunity>();
        List<Deal_Registration__c> dealsToUpdate = new List<Deal_Registration__c>();
        
        Map<String, String> fieldMappings = getFieldMappings();
        
        for (Deal_Registration__c dr : newRecords) {
            Opportunity opp = new Opportunity();
            opp.Name = 'Opp from ' + dr.Name;
            opp.StageName = 'Prospecting';
            opp.Linked_Deal_Registration__c = dr.Id;
            
            // Apply field mappings
            applyFieldMappings(dr, opp, fieldMappings);
            
            oppsToInsert.add(opp);
        }
        
        if (!oppsToInsert.isEmpty()) {
            insert oppsToInsert;
            
            // Update Deal Registrations with back-reference
            for (Integer i = 0; i < newRecords.size(); i++) {
                Deal_Registration__c drUpdate = new Deal_Registration__c(
                    Id = newRecords[i].Id,
                    Linked_Opportunity__c = oppsToInsert[i].Id
                );
                dealsToUpdate.add(drUpdate);
            }
            
            update dealsToUpdate;
        }
    }
    
    /**
     * After update: sync field changes to linked Opportunity unless status is Approved.
     */
    public static void handleAfterUpdate(Map<Id, Deal_Registration__c> newMap, Map<Id, Deal_Registration__c> oldMap) {
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        Map<String, String> fieldMappings = getFieldMappings();
        
        for (Deal_Registration__c dr : newMap.values()) {
            Deal_Registration__c oldDr = oldMap.get(dr.Id);
            
            // Skip if status is Approved (sync lock)
            if (dr.Status__c == 'Approved') {
                continue;
            }
            
            // Only sync if linked Opportunity exists and mapped fields changed
            if (dr.Linked_Opportunity__c != null && hasRelevantChanges(dr, oldDr, fieldMappings)) {
                Opportunity opp = new Opportunity(Id = dr.Linked_Opportunity__c);
                applyFieldMappings(dr, opp, fieldMappings);
                oppsToUpdate.add(opp);
            }
        }
        
        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
    
    /**
     * Retrieve field mappings from Custom Metadata.
     */
    private static Map<String, String> getFieldMappings() {
        Map<String, String> mappings = new Map<String, String>();
        
        for (Deal_Reg_Field_Mapping__mdt mapping : [
            SELECT Deal_Registration_Field__c, Opportunity_Field__c
            FROM Deal_Reg_Field_Mapping__mdt
            WHERE DeveloperName != null
        ]) {
            mappings.put(mapping.Deal_Registration_Field__c, mapping.Opportunity_Field__c);
        }
        
        return mappings;
    }
    
    /**
     * Apply field mappings from Deal Registration to Opportunity.
     */
    private static void applyFieldMappings(Deal_Registration__c source, Opportunity target, Map<String, String> mappings) {
        for (String drField : mappings.keySet()) {
            String oppField = mappings.get(drField);
            Object value = source.get(drField);
            target.put(oppField, value);
        }
    }
    
    /**
     * Check if any mapped fields changed.
     */
    private static Boolean hasRelevantChanges(Deal_Registration__c newRecord, Deal_Registration__c oldRecord, Map<String, String> mappings) {
        for (String drField : mappings.keySet()) {
            if (newRecord.get(drField) != oldRecord.get(drField)) {
                return true;
            }
        }
        return false;
    }
}
