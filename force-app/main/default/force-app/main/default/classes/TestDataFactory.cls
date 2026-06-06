/**
 * @file              TestDataFactory.cls
 * @description       Test data factory utility that generates mock snapshot records
 *                    for testing. Provides builder-pattern methods for creating
 *                    ARMT_Snapshot__c and ARMT_SnapshotRecord__c records used
 *                    across automated test scenarios.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             TestUtilities
 *
 * @dependencies      (none)
 * @calledBy          TestMigrationBatchJob, TestMigrationProgressMonitoring
 * @testClass         (utility — not directly tested; exercised by consumer test classes)
 *
 * @see               AGENTS.md Test Data Strategy §3
 */
@isTest
public class TestDataFactory {

    // ─────────────────────────────────────────────────────────────────────────
    // ARMT_Snapshot__c factory methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a single ARMT_Snapshot__c record with Status__c = 'In Progress'.
     *
     * @return Inserted ARMT_Snapshot__c record with Id populated.
     */
    public static ARMT_Snapshot__c createSnapshot() {
        ARMT_Snapshot__c snap = new ARMT_Snapshot__c(
            Status__c        = 'In Progress',
            Snapshot_Time__c = System.now(),
            Record_Count__c  = 0
        );
        insert snap;
        return snap;
    }

    /**
     * Creates and inserts a single ARMT_Snapshot__c record with the given status.
     *
     * @param  status  The Status__c value to assign (e.g. 'In Progress', 'Complete').
     * @return Inserted ARMT_Snapshot__c record with Id populated.
     */
    public static ARMT_Snapshot__c createSnapshot(String status) {
        ARMT_Snapshot__c snap = new ARMT_Snapshot__c(
            Status__c        = status,
            Snapshot_Time__c = System.now(),
            Record_Count__c  = 0
        );
        insert snap;
        return snap;
    }

    /**
     * Creates and inserts N ARMT_Snapshot__c records all with Status__c = 'In Progress'.
     * Used for bulk testing paths.
     *
     * @param  count  Number of records to create. Must be > 0.
     * @return List of inserted ARMT_Snapshot__c records with Ids populated.
     */
    public static List<ARMT_Snapshot__c> createSnapshots(Integer count) {
        List<ARMT_Snapshot__c> snaps = new List<ARMT_Snapshot__c>();
        for (Integer i = 0; i < count; i++) {
            snaps.add(new ARMT_Snapshot__c(
                Status__c        = 'In Progress',
                Snapshot_Time__c = System.now(),
                Record_Count__c  = i
            ));
        }
        insert snaps;
        return snaps;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ARMT_SnapshotRecord__c factory methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a single ARMT_SnapshotRecord__c associated with the
     * given snapshot.
     *
     * @param  snapshotId  Id of the parent ARMT_Snapshot__c record.
     * @return Inserted ARMT_SnapshotRecord__c record with Id populated.
     */
    public static ARMT_SnapshotRecord__c createSnapshotRecord(Id snapshotId) {
        ARMT_SnapshotRecord__c rec = new ARMT_SnapshotRecord__c(
            Snapshot__c           = snapshotId,
            Record_Id__c          = '001000000000001AAA',
            Record_JSON__c        = '{"Name":"Test Record","Status__c":"Active"}',
            Sequence__c           = 1,
            SnapshotRecordData__c = '{"serialized":"data"}'
        );
        insert rec;
        return rec;
    }

    /**
     * Creates and inserts N ARMT_SnapshotRecord__c records associated with the
     * given snapshot. Used for bulk testing paths.
     *
     * @param  snapshotId  Id of the parent ARMT_Snapshot__c record.
     * @param  count       Number of records to create. Must be > 0.
     * @return List of inserted ARMT_SnapshotRecord__c records with Ids populated.
     */
    public static List<ARMT_SnapshotRecord__c> createSnapshotRecords(Id snapshotId, Integer count) {
        List<ARMT_SnapshotRecord__c> recs = new List<ARMT_SnapshotRecord__c>();
        for (Integer i = 0; i < count; i++) {
            recs.add(new ARMT_SnapshotRecord__c(
                Snapshot__c           = snapshotId,
                Record_Id__c          = '001000000000' + String.valueOf(i).leftPad(6, '0') + 'AAA',
                Record_JSON__c        = '{"index":' + i + '}',
                Sequence__c           = i + 1,
                SnapshotRecordData__c = '{"seq":' + i + '}'
            ));
        }
        insert recs;
        return recs;
    }
}
