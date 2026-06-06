/**
 * @file        TestDataFactory.cls
 * @description Test data factory utility that generates mock snapshot records
 *              and related ARMT objects for testing. Provides builder-pattern
 *              methods returning inserted SObjects for use across all test classes.
 * @author      ASDA Dev Agent
 * @created     2026-06-06
 * @lastModified 2026-06-06
 * @group       TestUtilities
 *
 * @dependencies (none)
 * @calledBy    TestMigrationBatchJob, TestMigrationProgressMonitoring
 * @testClass   (this IS the factory — no paired test class required)
 */
@isTest
public class TestDataFactory {

    // ─────────────────────────────────────────────────────────────────────────
    // ARMT_Snapshot__c factory methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a single ARMT_Snapshot__c record.
     *
     * @return  Inserted ARMT_Snapshot__c record with Id populated.
     */
    public static ARMT_Snapshot__c createSnapshot() {
        ARMT_Snapshot__c snap = new ARMT_Snapshot__c(
            SnapshotData__c = '{"version":1,"records":[]}'
        );
        insert snap;
        return snap;
    }

    /**
     * Creates and inserts N ARMT_Snapshot__c records.
     *
     * @param  count  Number of snapshot records to create.
     * @return        List of inserted ARMT_Snapshot__c records.
     */
    public static List<ARMT_Snapshot__c> createSnapshots(Integer count) {
        List<ARMT_Snapshot__c> snaps = new List<ARMT_Snapshot__c>();
        for (Integer i = 0; i < count; i++) {
            snaps.add(new ARMT_Snapshot__c(
                SnapshotData__c = '{"version":1,"index":' + i + '}'
            ));
        }
        insert snaps;
        return snaps;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ARMT_SnapshotRecord__c factory methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a single ARMT_SnapshotRecord__c child record
     * associated with the provided snapshot.
     *
     * @param  snapshotId  The Id of the parent ARMT_Snapshot__c record.
     * @return             Inserted ARMT_SnapshotRecord__c record with Id populated.
     */
    public static ARMT_SnapshotRecord__c createSnapshotRecord(Id snapshotId) {
        ARMT_SnapshotRecord__c rec = new ARMT_SnapshotRecord__c(
            Name = 'Test Record',
            ARMT_Snapshot__c = snapshotId,
            SnapshotRecordData__c = '{"id":"001000000000001","name":"Test Product"}'
        );
        insert rec;
        return rec;
    }

    /**
     * Creates and inserts N ARMT_SnapshotRecord__c records associated with
     * the provided snapshot. Suitable for bulk testing (200+ records).
     *
     * @param  snapshotId  The Id of the parent ARMT_Snapshot__c record.
     * @param  count       Number of child records to create.
     * @return             List of inserted ARMT_SnapshotRecord__c records.
     */
    public static List<ARMT_SnapshotRecord__c> createSnapshotRecords(Id snapshotId, Integer count) {
        List<ARMT_SnapshotRecord__c> records = new List<ARMT_SnapshotRecord__c>();
        for (Integer i = 0; i < count; i++) {
            records.add(new ARMT_SnapshotRecord__c(
                Name = 'Test Record ' + i,
                ARMT_Snapshot__c = snapshotId,
                SnapshotRecordData__c = '{"id":"00100000000000' + i + '","name":"Product ' + i + '"}'
            ));
        }
        insert records;
        return records;
    }

    /**
     * Creates and inserts a single ARMT_SnapshotRecord__c with a blank
     * SnapshotRecordData__c value — used to test failure paths.
     *
     * @param  snapshotId  The Id of the parent ARMT_Snapshot__c record.
     * @return             Inserted ARMT_SnapshotRecord__c with blank data.
     */
    public static ARMT_SnapshotRecord__c createBlankSnapshotRecord(Id snapshotId) {
        ARMT_SnapshotRecord__c rec = new ARMT_SnapshotRecord__c(
            Name = 'Blank Record',
            ARMT_Snapshot__c = snapshotId,
            SnapshotRecordData__c = ''
        );
        insert rec;
        return rec;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ARMT_ValidationReport__c factory methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a single ARMT_ValidationReport__c record.
     *
     * @param  reportId  The unique report identifier string.
     * @param  status    The validation status (BLOCKER, WARNING, INFO).
     * @param  summary   The summary text for the report.
     * @return           Inserted ARMT_ValidationReport__c record.
     */
    public static ARMT_ValidationReport__c createValidationReport(
        String reportId,
        String status,
        String summary
    ) {
        ARMT_ValidationReport__c rep = new ARMT_ValidationReport__c(
            Name = reportId.length() > 80 ? reportId.substring(0, 80) : reportId,
            Report_Id__c = reportId,
            Validation_Status__c = status,
            Summary__c = summary
        );
        insert rep;
        return rep;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ARMT_MappingRegistry__c factory methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a single ARMT_MappingRegistry__c record.
     *
     * @param  sourceField  Source field API name.
     * @param  targetField  Target field API name.
     * @param  confidence   Confidence score (0.0–1.0).
     * @return              Inserted ARMT_MappingRegistry__c record.
     */
    public static ARMT_MappingRegistry__c createMappingRegistry(
        String sourceField,
        String targetField,
        Decimal confidence
    ) {
        ARMT_MappingRegistry__c reg = new ARMT_MappingRegistry__c(
            Name = (sourceField + '.' + targetField).length() > 80
                ? (sourceField + '.' + targetField).substring(0, 80)
                : sourceField + '.' + targetField,
            SourceFieldAPI__c = sourceField,
            TargetFieldAPI__c = targetField,
            ConfidenceScore__c = confidence
        );
        insert reg;
        return reg;
    }
}
