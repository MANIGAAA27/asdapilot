/**
 * @file              TestDataFactory.cls
 * @description       Test data factory utility that generates mock snapshot records for testing.
 *                    Provides builder-pattern methods for creating ARMT_Snapshot__c and
 *                    ARMT_SnapshotRecord__c records used across test classes.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ARMT_TestUtilities
 *
 * @dependencies      (none)
 * @calledBy          TestMigrationBatchJob, TestMigrationProgressMonitoring
 * @testClass         (this IS the test factory — consumed by test classes)
 *
 * @see               HLD-ARMT-V1.0 Section 3.3
 */

/**
 * Generic test data factory for ARMT snapshot-related test scenarios.
 *
 * Responsibilities:
 *   - Create ARMT_Snapshot__c records with configurable status.
 *   - Create ARMT_SnapshotRecord__c records with configurable JSON payloads.
 *   - Support bulk creation for governor limit testing.
 */
@isTest
public class TestDataFactory {

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
     * Creates and inserts a single ARMT_SnapshotRecord__c record.
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
