/**
 * @file              ARMT_TestDataFactory.cls
 * @description       Test data factory utility that generates mock records for ARMT automated test scenarios.
 *                    Provides builder-pattern methods for creating ARMT_Catalogue__c, ARMT_Snapshot__c,
 *                    ARMT_SnapshotRecord__c, ARMT_AuditLog__c, and ARMT_ValidationReport__c records.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ARMT_TestUtilities
 *
 * @dependencies      (none)
 * @calledBy          ARMT_ConfigurationScannerTest, ARMT_ValidationReportTest, TestMigrationBatchJob, TestMigrationProgressMonitoring
 * @testClass         (this IS the test factory — consumed by test classes)
 *
 * @see               HLD-ARMT-V1.0 Section 3.3
 */

/**
 * Test data factory for ARMT test scenarios.
 *
 * Responsibilities:
 *   - Create ARMT_Catalogue__c records with configurable object types.
 *   - Create ARMT_Snapshot__c and ARMT_SnapshotRecord__c records for snapshot tests.
 *   - Create ARMT_AuditLog__c records for audit log tests.
 *   - Create ARMT_ValidationReport__c records for validation report tests.
 *   - Support bulk creation for governor limit testing.
 */
@isTest
public class ARMT_TestDataFactory {

    /**
     * Creates and inserts a single ARMT_Catalogue__c record.
     *
     * @param  name        The name of the catalogue item.
     * @param  objectType  The object type picklist value (Product, Bundle, PriceRule, etc.).
     * @return The inserted ARMT_Catalogue__c record.
     *
     * @calledBy ARMT_ConfigurationScannerTest, ARMT_ValidationReportTest
     * @testMethods (this is the factory itself)
     */
    public static ARMT_Catalogue__c createCatalogueRecord(String name, String objectType) {
        ARMT_Catalogue__c record = new ARMT_Catalogue__c(
            Name = name,
            Object_Type__c = objectType,
            Configuration_Details__c = '{"type":"' + objectType + '","name":"' + name + '"}'
        );
        insert record;
        return record;
    }

    /**
     * Creates and inserts a list of ARMT_Catalogue__c records for bulk testing.
     *
     * @param  count       Number of records to create.
     * @param  objectType  The object type picklist value for all records.
     * @return List of inserted ARMT_Catalogue__c records.
     *
     * @calledBy ARMT_ConfigurationScannerTest
     * @testMethods (this is the factory itself)
     */
    public static List<ARMT_Catalogue__c> createCatalogueRecords(Integer count, String objectType) {
        List<ARMT_Catalogue__c> records = new List<ARMT_Catalogue__c>();
        for (Integer i = 0; i < count; i++) {
            records.add(new ARMT_Catalogue__c(
                Name = 'Test Catalogue ' + i,
                Object_Type__c = objectType,
                Configuration_Details__c = '{"type":"' + objectType + '","index":' + i + '}'
            ));
        }
        insert records;
        return records;
    }

    /**
     * Creates and inserts a single ARMT_Snapshot__c record.
     *
     * @param  status  The snapshot status (In Progress, Complete, Rolled Back).
     * @return The inserted ARMT_Snapshot__c record.
     *
     * @calledBy TestMigrationBatchJob, TestMigrationProgressMonitoring
     * @testMethods (this is the factory itself)
     */
    public static ARMT_Snapshot__c createSnapshot(String status) {
        ARMT_Snapshot__c snap = new ARMT_Snapshot__c(
            Snapshot_Time__c = System.now(),
            Status__c = status,
            Record_Count__c = 0
        );
        insert snap;
        return snap;
    }

    /**
     * Creates and inserts a single ARMT_SnapshotRecord__c record linked to a snapshot.
     *
     * @param  snapshotId  The Id of the parent ARMT_Snapshot__c record.
     * @param  recordId    The Salesforce record Id being snapshotted.
     * @param  recordJson  The serialized JSON of the record.
     * @return The inserted ARMT_SnapshotRecord__c record.
     *
     * @calledBy TestMigrationBatchJob
     * @testMethods (this is the factory itself)
     */
    public static ARMT_SnapshotRecord__c createSnapshotRecord(Id snapshotId, String recordId, String recordJson) {
        ARMT_SnapshotRecord__c rec = new ARMT_SnapshotRecord__c(
            Snapshot__c = snapshotId,
            Record_Id__c = recordId,
            Record_JSON__c = recordJson,
            Sequence__c = 1
        );
        insert rec;
        return rec;
    }

    /**
     * Creates and inserts a single ARMT_ValidationReport__c record.
     *
     * @param  reportId  The unique report identifier.
     * @param  status    The validation status (BLOCKER, WARNING, INFO).
     * @param  summary   The validation summary text.
     * @return The inserted ARMT_ValidationReport__c record.
     *
     * @calledBy ARMT_ValidationReportTest
     * @testMethods (this is the factory itself)
     */
    public static ARMT_ValidationReport__c createValidationReport(String reportId, String status, String summary) {
        ARMT_ValidationReport__c report = new ARMT_ValidationReport__c(
            Report_Id__c = reportId,
            Validation_Status__c = status,
            Summary__c = summary
        );
        insert report;
        return report;
    }

    /**
     * Creates and inserts a list of ARMT_ValidationReport__c records for bulk testing.
     *
     * @param  count   Number of records to create.
     * @param  status  The validation status for all records.
     * @return List of inserted ARMT_ValidationReport__c records.
     *
     * @calledBy ARMT_ValidationReportTest
     * @testMethods (this is the factory itself)
     */
    public static List<ARMT_ValidationReport__c> createValidationReports(Integer count, String status) {
        List<ARMT_ValidationReport__c> reports = new List<ARMT_ValidationReport__c>();
        for (Integer i = 0; i < count; i++) {
            reports.add(new ARMT_ValidationReport__c(
                Report_Id__c = 'RPT-' + i + '-' + System.currentTimeMillis(),
                Validation_Status__c = status,
                Summary__c = 'Test validation summary ' + i
            ));
        }
        insert reports;
        return reports;
    }

    /**
     * Creates and inserts a list of ARMT_SnapshotRecord__c records for bulk testing.
     *
     * @param  snapshotId  The Id of the parent ARMT_Snapshot__c record.
     * @param  count       Number of records to create.
     * @return List of inserted ARMT_SnapshotRecord__c records.
     *
     * @calledBy TestMigrationBatchJob
     * @testMethods (this is the factory itself)
     */
    public static List<ARMT_SnapshotRecord__c> createSnapshotRecords(Id snapshotId, Integer count) {
        List<ARMT_SnapshotRecord__c> records = new List<ARMT_SnapshotRecord__c>();
        for (Integer i = 0; i < count; i++) {
            records.add(new ARMT_SnapshotRecord__c(
                Snapshot__c = snapshotId,
                Record_Id__c = '001000000000' + String.valueOf(i).leftPad(6, '0'),
                Record_JSON__c = '{"Id":"001000000000' + String.valueOf(i).leftPad(6, '0') + '","Name":"Test ' + i + '"}',
                Sequence__c = 1
            ));
        }
        insert records;
        return records;
    }
}
