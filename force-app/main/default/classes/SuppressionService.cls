/**
 * @file              SuppressionService.cls
 * @description       Core suppression engine for inactive record filtering.
 *                    Evaluates metadata-driven policies and applies suppression
 *                    to SOQL queries, lookup filters, and search results.
 * @author            ASDA Dev Agent
 * @created           2025-01-23
 * @lastModified      2025-01-23
 * @group             SuppressionEngine
 *
 * @dependencies      Suppressed_Object_Setting__mdt, ErrorLogger
 * @calledBy          InactiveRecordSearchController, custom lookup components
 * @testClass         SuppressionServiceTest
 *
 * @see               LLD Account Deactivation - Section: Intelligent Record Suppression
 */

// MODIFIED 2026-06-05 — Project: Account Deactivation | LLD - Intelligent Suppression Engine for Inactive Records in Lookups, Reports, Flows, Lightning, and API Contexts (draft) | ASDA
/**
 * Service layer for evaluating and applying inactive record suppression policies.
 * Reads Suppressed_Object_Setting__mdt metadata and injects WHERE clause filters.
 *
 * Threading: Synchronous and bulkified for UI contexts.
 *
 * @testClass SuppressionServiceTest
 */
public with sharing class SuppressionService {
    
    private static Map<String, Boolean> suppressionCache;
    
    /**
     * Determines whether a given object type has suppression enabled via metadata.
     *
     * @param  objectApiName  API name of the SObject (e.g., 'Account', 'Contact')
     * @return true if suppression is enabled for this object, false otherwise
     */
    public static Boolean isSuppressionEnabled(String objectApiName) {
        if (suppressionCache == null) {
            loadSuppressionCache();
        }
        
        return suppressionCache.containsKey(objectApiName) 
            ? suppressionCache.get(objectApiName) 
            : false;
    }
    
    /**
     * Constructs a SOQL WHERE clause fragment to filter out inactive records.
     *
     * @param  objectApiName  API name of the SObject being queried
     * @return WHERE clause string (e.g., 'Inactive__c = false'), or empty string if not applicable
     */
    public static String getSuppressionFilter(String objectApiName) {
        if (!isSuppressionEnabled(objectApiName)) {
            return '';
        }
        
        return 'Inactive__c = false';
    }
    
    /**
     * Loads suppression settings from Custom Metadata into a static cache.
     * Called automatically on first access. Catches and logs any query failures.
     */
    private static void loadSuppressionCache() {
        suppressionCache = new Map<String, Boolean>();
        
        try {
            List<Suppressed_Object_Setting__mdt> settings = [
                SELECT Object_Name__c, Suppression_Enabled__c
                FROM Suppressed_Object_Setting__mdt
                WHERE Suppression_Enabled__c = true
            ];
            
            for (Suppressed_Object_Setting__mdt setting : settings) {
                suppressionCache.put(setting.Object_Name__c, setting.Suppression_Enabled__c);
            }
            
        } catch (Exception ex) {
            ErrorLogger.logError(ex, 'SuppressionService', 'loadSuppressionCache');
            // Continue with empty cache rather than failing - graceful degradation
        }
    }
    
    /**
     * Applies suppression filter to a list of SObject records in-memory.
     * Used when records are already retrieved and need post-query filtering.
     *
     * @param  records        List of SObject records to filter
     * @param  objectApiName  API name of the SObject type
     * @return Filtered list with inactive records removed
     */
    public static List<SObject> applySuppression(List<SObject> records, String objectApiName) {
        if (!isSuppressionEnabled(objectApiName) || records == null || records.isEmpty()) {
            return records;
        }
        
        List<SObject> filtered = new List<SObject>();
        
        try {
            for (SObject rec : records) {
                Boolean isInactive = (Boolean) rec.get('Inactive__c');
                if (isInactive == null || isInactive == false) {
                    filtered.add(rec);
                }
            }
            
        } catch (Exception ex) {
            ErrorLogger.logError(ex, 'SuppressionService', 'applySuppression');
            return records; // Return original list if field access fails
        }
        
        return filtered;
    }
}
