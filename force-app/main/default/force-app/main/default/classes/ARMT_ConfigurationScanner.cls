/**
 * @file              ARMT_ConfigurationScanner.cls
 * @description       Scans CPQ objects and logs catalogued configuration data into ARMT_Catalogue__c.
 *                    Implements the Configuration Discovery capability (FR-02) by querying CPQ
 *                    configuration objects and persisting discovered records for downstream mapping
 *                    and validation.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ARMT_Services
 *
 * @dependencies      DataAccessException, ScanException, ARMTConfigurationTriggerHandler
 * @calledBy          (none in this changeset — invoked from LWC Apex controller in future sprint)
 * @testClass         ARMT_ConfigurationScannerTest
 *
 * @see               HLD-ARMT-V1.0 Section 3.3, HLD-CMP-002
 */

/**
 * Service class for scanning CPQ configuration objects and cataloguing them.
 *
 * Responsibilities:
 *   - Accept a list of object type names to scan.
 *   - Query existing ARMT_Catalogue__c records to avoid re-scanning.
 *   - Insert new catalogue records for discovered configuration items.
 *   - Return a summary of scan results.
 *   - Enforce FLS via WITH SECURITY_ENFORCED.
 *   - Bulkify all operations — no SOQL or DML inside loops.
 *
 * Threading: Designed for synchronous Apex context. For large volumes,
 * invoke via MigrationExecutionBatch.
 *
 * @testClass ARMT_ConfigurationScannerTest
 */
public with sharing class ARMT_ConfigurationScanner {

    /** Maximum number of catalogue records to insert per scan invocation. */
    @TestVisible
    private static final Integer MAX_SCAN_BATCH_SIZE = 200;

    /**
     * Scans the provided list of CPQ configuration items and inserts them into ARMT_Catalogue__c.
     * Skips items that already exist (same Object_Type__c + Name combination).
     *
     * @param  scanItems  List of ScanItem wrappers describing configuration items to catalogue.
     * @return ScanResult summary containing counts of inserted, skipped, and failed records.
     * @throws ScanException when the scan operation fails due to unexpected errors.
     * @throws DataAccessException when SOQL or DML operations fail due to access violations.
     *
     * @calledBy (none in this changeset)
     * @testMethods test_scanItems_validInput_insertsRecords, test_scanItems_duplicateItems_skipped, test_scanItems_nullInput_returnsEmptyResult, test_scanItems_bulk200_allInserted
     */
    public ScanResult scanItems(List<ScanItem> scanItems) {
        ScanResult result = new ScanResult();

        if (scanItems == null || scanItems.isEmpty()) {
            return result;
        }

        // Limit to max batch size
        List<ScanItem> itemsToProcess = scanItems.size() > MAX_SCAN_BATCH_SIZE
            ? scanItems.subList(0, MAX_SCAN_BATCH_SIZE)
            : scanItems;

        // Build lookup sets for deduplication query
        Set<String> objectTypes = new Set<String>();
        Set<String> names = new Set<String>();
        for (ScanItem item : itemsToProcess) {
            if (String.isNotBlank(item.objectType)) {
                objectTypes.add(item.objectType);
            }
            if (String.isNotBlank(item.name)) {
                names.add(item.name);
            }
        }

        // Query existing records to skip duplicates
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
                existingKeys.add(buildKey(existing.Object_Type__c, existing.Name));
            }
        } catch (System.QueryException qe) {
            throw new DataAccessException('Failed to query existing catalogue records: ' + qe.getMessage());
        }

        // Build list of new records to insert
        List<ARMT_Catalogue__c> toInsert = new List<ARMT_Catalogue__c>();
        for (ScanItem item : itemsToProcess) {
            if (String.isBlank(item.objectType) || String.isBlank(item.name)) {
                result.failedCount++;
                result.errors.add('Invalid scan item: objectType and name are required.');
                continue;
            }

            String key = buildKey(item.objectType, item.name);
            if (existingKeys.contains(key)) {
                result.skippedCount++;
                continue;
            }

            toInsert.add(new ARMT_Catalogue__c(
                Name = item.name,
                Object_Type__c = item.objectType,
                Configuration_Details__c = item.configurationDetails
            ));
            existingKeys.add(key); // Prevent in-batch duplicates
        }

        // Perform DML
        if (!toInsert.isEmpty()) {
            try {
                Database.SaveResult[] saveResults = Database.insert(toInsert, false);
                for (Database.SaveResult sr : saveResults) {
                    if (sr.isSuccess()) {
                        result.insertedCount++;
                    } else {
                        result.failedCount++;
                        for (Database.Error err : sr.getErrors()) {
                            result.errors.add(err.getMessage());
                        }
                    }
                }
            } catch (DmlException de) {
                throw new ScanException('DML failure during catalogue insert: ' + de.getMessage());
            }
        }

        return result;
    }

    /**
     * Retrieves all ARMT_Catalogue__c records for a given object type.
     *
     * @param  objectType  The Object_Type__c picklist value to filter by.
     * @return List of ARMT_Catalogue__c records matching the object type.
     * @throws DataAccessException when the SOQL query fails.
     *
     * @calledBy (none in this changeset)
     * @testMethods test_getCatalogueByType_validType_returnsRecords, test_getCatalogueByType_noRecords_returnsEmpty
     */
    public List<ARMT_Catalogue__c> getCatalogueByType(String objectType) {
        if (String.isBlank(objectType)) {
            return new List<ARMT_Catalogue__c>();
        }
        try {
            return [
                SELECT Id, Name, Object_Type__c, Configuration_Details__c, ARMT_Duplicate_Check__c
                FROM ARMT_Catalogue__c
                WHERE Object_Type__c = :objectType
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
                LIMIT 1000
            ];
        } catch (System.QueryException qe) {
            throw new DataAccessException('Failed to retrieve catalogue records by type: ' + qe.getMessage());
        }
    }

    /**
     * Retrieves all ARMT_Catalogue__c records across all object types.
     *
     * @return List of all ARMT_Catalogue__c records.
     * @throws DataAccessException when the SOQL query fails.
     *
     * @calledBy (none in this changeset)
     * @testMethods test_getAllCatalogueRecords_returnsAll
     */
    public List<ARMT_Catalogue__c> getAllCatalogueRecords() {
        try {
            return [
                SELECT Id, Name, Object_Type__c, Configuration_Details__c, ARMT_Duplicate_Check__c
                FROM ARMT_Catalogue__c
                WITH SECURITY_ENFORCED
                ORDER BY Object_Type__c, Name ASC
                LIMIT 2000
            ];
        } catch (System.QueryException qe) {
            throw new DataAccessException('Failed to retrieve all catalogue records: ' + qe.getMessage());
        }
    }

    /** Builds a composite key for duplicate detection. */
    private String buildKey(String objectType, String name) {
        return objectType + '|' + name;
    }

    // ─── Inner Classes ────────────────────────────────────────────────────────

    /**
     * Wrapper class representing a single configuration item to be scanned and catalogued.
     */
    public class ScanItem {
        /** The object type (Product, Bundle, PriceRule, etc.). */
        public String objectType;
        /** The name of the configuration item. */
        public String name;
        /** Optional serialized configuration details. */
        public String configurationDetails;

        /**
         * Constructs a ScanItem with required fields.
         *
         * @param  objectType           The object type picklist value.
         * @param  name                 The name of the configuration item.
         * @param  configurationDetails Optional JSON configuration details.
         */
        public ScanItem(String objectType, String name, String configurationDetails) {
            this.objectType = objectType;
            this.name = name;
            this.configurationDetails = configurationDetails;
        }
    }

    /**
     * Result wrapper returned by scanItems() summarizing the scan outcome.
     */
    public class ScanResult {
        /** Number of records successfully inserted. */
        public Integer insertedCount;
        /** Number of records skipped due to existing duplicates. */
        public Integer skippedCount;
        /** Number of records that failed to insert. */
        public Integer failedCount;
        /** List of error messages for failed records. */
        public List<String> errors;

        /** Constructs an empty ScanResult. */
        public ScanResult() {
            this.insertedCount = 0;
            this.skippedCount = 0;
            this.failedCount = 0;
            this.errors = new List<String>();
        }
    }
}
