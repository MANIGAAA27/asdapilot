/**
 * @file              CPQ_ConfigScanner.cls
 * @description       Scans CPQ-related objects and fetches metadata for migration
 *                    mapping. Provides methods to discover CPQ object schemas,
 *                    enumerate field metadata, and persist scan results as
 *                    ARMT_MappingRegistry__c records for downstream mapping.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ConfigurationDiscovery
 *
 * @dependencies      (none)
 * @calledBy          (none in this changeset)
 * @testClass         CPQ_ConfigScannerTest
 *
 * @see               HLD-CMP-002 DiscoveryService
 */

/**
 * Service class for scanning CPQ configuration objects and generating
 * mapping registry entries for migration.
 *
 * Responsibilities:
 *   - Enumerate CPQ object API names from a configurable list.
 *   - Retrieve field-level metadata for each CPQ object via Schema.
 *   - Persist discovered field mappings to ARMT_MappingRegistry__c.
 *   - Return structured scan results for UI consumption.
 *
 * Threading: Designed for synchronous invocation from LWC controllers.
 * For large orgs, invoke via Queueable to avoid synchronous limits.
 *
 * @testClass CPQ_ConfigScannerTest
 */
public with sharing class CPQ_ConfigScanner {

    /** CPQ object API names targeted for discovery in V1. */
    private static final List<String> CPQ_OBJECT_NAMES = new List<String>{
        'Product2',
        'Pricebook2',
        'PricebookEntry'
    };

    // ─────────────────────────────────────────────────────────────────────────
    // Inner types
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Lightweight DTO representing a single discovered field mapping candidate.
     */
    public class FieldScanResult {
        /** API name of the source CPQ object. */
        public String sourceObjectApiName;
        /** API name of the source field. */
        public String sourceFieldApiName;
        /** Display label of the source field. */
        public String sourceFieldLabel;
        /** Salesforce field type of the source field. */
        public String sourceFieldType;
        /** Suggested target field API name (may be blank for gaps). */
        public String suggestedTargetFieldApiName;
        /** Confidence score: 1.0 = exact, 0.5 = suggested, 0.0 = gap. */
        public Decimal confidenceScore;

        /** Default constructor. */
        public FieldScanResult() {}
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Scans all configured CPQ objects and returns a flat list of field scan
     * results. Does not perform DML — callers must invoke persistScanResults
     * to write to ARMT_MappingRegistry__c.
     *
     * @return  List of FieldScanResult DTOs. Empty list when no CPQ objects
     *          are accessible in the running user's context.
     * @calledBy    (none in this changeset)
     * @testMethods test_scanCpqObjects_returnsResults, test_scanCpqObjects_emptyOrg_returnsEmpty
     */
    public List<FieldScanResult> scanCpqObjects() {
        List<FieldScanResult> results = new List<FieldScanResult>();

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        for (String objectName : CPQ_OBJECT_NAMES) {
            if (!globalDescribe.containsKey(objectName)) {
                continue;
            }

            Schema.SObjectType sot = globalDescribe.get(objectName);
            Schema.DescribeSObjectResult describeResult = sot.getDescribe();
            Map<String, Schema.SObjectField> fields = describeResult.fields.getMap();

            for (String fieldName : fields.keySet()) {
                Schema.DescribeFieldResult dfr = fields.get(fieldName).getDescribe();
                if (!dfr.isAccessible()) {
                    continue;
                }

                FieldScanResult fsr = new FieldScanResult();
                fsr.sourceObjectApiName = objectName;
                fsr.sourceFieldApiName = dfr.getName();
                fsr.sourceFieldLabel = dfr.getLabel();
                fsr.sourceFieldType = String.valueOf(dfr.getType());
                fsr.suggestedTargetFieldApiName = '';
                fsr.confidenceScore = 0.0;

                results.add(fsr);
            }
        }

        return results;
    }

    /**
     * Persists a list of FieldScanResult DTOs as ARMT_MappingRegistry__c records.
     * Performs a bulk insert; partial failures are captured and returned.
     *
     * @param  scanResults  List of FieldScanResult DTOs to persist.
     * @return              List of Database.SaveResult objects, one per input record.
     * @calledBy    (none in this changeset)
     * @testMethods test_persistScanResults_insertsRecords, test_persistScanResults_emptyList_returnsEmpty
     */
    public List<Database.SaveResult> persistScanResults(List<FieldScanResult> scanResults) {
        if (scanResults == null || scanResults.isEmpty()) {
            return new List<Database.SaveResult>();
        }

        List<ARMT_MappingRegistry__c> registryRecords = new List<ARMT_MappingRegistry__c>();

        for (FieldScanResult fsr : scanResults) {
            ARMT_MappingRegistry__c reg = new ARMT_MappingRegistry__c(
                Name = truncateName(fsr.sourceObjectApiName + '.' + fsr.sourceFieldApiName),
                SourceFieldAPI__c = fsr.sourceFieldApiName,
                TargetFieldAPI__c = fsr.suggestedTargetFieldApiName,
                ConfidenceScore__c = fsr.confidenceScore
            );
            registryRecords.add(reg);
        }

        return Database.insert(registryRecords, false);
    }

    /**
     * Returns the list of CPQ object API names configured for scanning.
     *
     * @return  Unmodifiable list of CPQ object API name strings.
     * @calledBy    (none in this changeset)
     * @testMethods test_getCpqObjectNames_returnsExpectedList
     */
    public List<String> getCpqObjectNames() {
        return CPQ_OBJECT_NAMES;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Truncates a string to 80 characters for use as a Name field value. */
    private static String truncateName(String raw) {
        if (raw == null) {
            return '';
        }
        return raw.length() > 80 ? raw.substring(0, 80) : raw;
    }
}
