/**
 * @file        TestMigrationBatchJob.cls
 * @description Tests MigrationBatchJob — covers migration batch job success,
 *              failure, and bulk processing scenarios. Uses TestDataFactory
 *              for all test data setup.
 * @testFor     MigrationBatchJob
 * @coverage    Target ≥ 90%.
 */
@isTest
private class TestMigrationBatchJob {

    @testSetup
    static void setupData() {
        ARMT_Snapshot__c snap = TestDataFactory.createSnapshot();
        // Create valid records for success path
        TestDataFactory.createSnapshotRecords(snap.Id, 5);
        // Create one blank record for failure path
        TestDataFactory.createBlankSnapshotRecord(snap.Id);
    }

    @isTest
    static void test_start_returnsQueryLocator() {
        ARMT_Snapshot__c snap = [SELECT Id FROM ARMT_Snapshot__c LIMIT 1];
        MigrationBatchJob job = new MigrationBatchJob(snap.Id);

        Test.startTest();
        Database.QueryLocator ql = job.start(null);
        Test.stopTest();

        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
    }

    @isTest
    static void test_execute_successPath_incrementsSuccessCount() {
        ARMT_Snapshot__c snap = [SELECT Id FROM ARMT_Snapshot__c LIMIT 1];
        List<ARMT_SnapshotRecord__c> validRecords = [
            SELECT Id, SnapshotRecordData__c, Name
            FROM ARMT_SnapshotRecord__c
            WHERE ARMT_Snapshot__c = :snap.Id
            AND SnapshotRecordData__c != ''
            AND SnapshotRecordData__c != null
        ];

        MigrationBatchJob job = new MigrationBatchJob(snap.Id);

        Test.startTest();
        job.execute(null, validRecords);
        Test.stopTest();

        System.assertEquals(validRecords.size(), job.getSuccessCount(),
            'Success count should equal number of valid records processed');
        System.assertEquals(0, job.getFailureCount(),
            'Failure count should be 0 for valid records');
    }

    @isTest
    static void test_execute_failurePath_incrementsFailureCount() {
        ARMT_Snapshot__c snap = [SELECT Id FROM ARMT_Snapshot__c LIMIT 1];
        List<ARMT_SnapshotRecord__c> blankRecords = [
            SELECT Id, SnapshotRecordData__c, Name
            FROM ARMT_SnapshotRecord__c
            WHERE ARMT_Snapshot__c = :snap.Id
            AND (SnapshotRecordData__c = '' OR SnapshotRecordData__c = null)
        ];

        MigrationBatchJob job = new MigrationBatchJob(snap.Id);

        Test.startTest();
        job.execute(null, blankRecords);
        Test.stopTest();

        System.assertEquals(blankRecords.size(), job.getFailureCount(),
            'Failure count should equal number of blank records');
        System.assertEquals(0, job.getSuccessCount(),
            'Success count should be 0 for blank records');
        System.assert(!job.getErrorMessages().isEmpty(),
            'Error messages should be populated for failures');
    }

    @isTest
    static void test_execute_bulkRecords_processesAll() {
        // Create a new snapshot with 200 records for bulk testing
        ARMT_Snapshot__c bulkSnap = TestDataFactory.createSnapshot();
        TestDataFactory.createSnapshotRecords(bulkSnap.Id, 200);

        List<ARMT_SnapshotRecord__c> bulkRecords = [
            SELECT Id, SnapshotRecordData__c, Name
            FROM ARMT_SnapshotRecord__c
            WHERE ARMT_Snapshot__c = :bulkSnap.Id
        ];

        MigrationBatchJob job = new MigrationBatchJob(bulkSnap.Id);

        Test.startTest();
        job.execute(null, bulkRecords);
        Test.stopTest();

        System.assertEquals(200, job.getSuccessCount(),
            'All 200 bulk records should be processed successfully');
        System.assertEquals(0, job.getFailureCount(),
            'No failures expected for valid bulk records');
    }

    @isTest
    static void test_finish_logsCompletion() {
        ARMT_Snapshot__c snap = [SELECT Id FROM ARMT_Snapshot__c LIMIT 1];
        MigrationBatchJob job = new MigrationBatchJob(snap.Id);

        Test.startTest();
        // Simulate some processing before finish
        List<ARMT_SnapshotRecord__c> records = [
            SELECT Id, SnapshotRecordData__c, Name
            FROM ARMT_SnapshotRecord__c
            WHERE ARMT_Snapshot__c = :snap.Id
            AND SnapshotRecordData__c != ''
            AND SnapshotRecordData__c != null
            LIMIT 2
        ];
        job.execute(null, records);
        job.finish(null);
        Test.stopTest();

        // Verify the test log buffer captured the finish log
        List<String> logBuffer = MigrationProgressMonitoring.getTestLogBuffer();
        Boolean foundFinishLog = false;
        for (String entry : logBuffer) {
            if (entry.contains('finished')) {
                foundFinishLog = true;
                break;
            }
        }
        System.assert(foundFinishLog, 'Finish should log a completion message');
    }

    @isTest
    static void test_fullBatchExecution_endToEnd() {
        ARMT_Snapshot__c snap = TestDataFactory.createSnapshot();
        TestDataFactory.createSnapshotRecords(snap.Id, 10);

        Test.startTest();
        Database.executeBatch(new MigrationBatchJob(snap.Id), 200);
        Test.stopTest();

        // After batch completes, verify no unhandled exceptions were thrown
        // (the batch framework would surface them as failed jobs)
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'MigrationBatchJob'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!jobs.isEmpty(), 'Batch job should have been enqueued');
        System.assertEquals('Completed', jobs[0].Status,
            'Batch job should complete successfully');
    }

    @isTest
    static void test_constructor_initializesCountersToZero() {
        ARMT_Snapshot__c snap = [SELECT Id FROM ARMT_Snapshot__c LIMIT 1];

        Test.startTest();
        MigrationBatchJob job = new MigrationBatchJob(snap.Id);
        Test.stopTest();

        System.assertEquals(0, job.getSuccessCount(), 'Initial success count should be 0');
        System.assertEquals(0, job.getFailureCount(), 'Initial failure count should be 0');
        System.assert(job.getErrorMessages().isEmpty(), 'Initial error messages should be empty');
    }
}
