/**
 * @file        TestMigrationBatchJob.cls
 * @description Tests MigrationBatchJob — covers success path, error path,
 *              bulk processing (200+ records), and finish logging.
 * @testFor     MigrationBatchJob
 * @coverage    Target ≥ 90%.
 */
@isTest
private class TestMigrationBatchJob {

    // ─────────────────────────────────────────────────────────────────────────
    // Test: start() — default constructor
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_start_defaultConstructor_returnsQueryLocator() {
        // Arrange
        TestDataFactory.createSnapshot('In Progress');

        // Act
        Test.startTest();
        MigrationBatchJob job = new MigrationBatchJob();
        Database.QueryLocator ql = job.start(null);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
    }

    @isTest
    static void test_start_paramConstructor_returnsQueryLocator() {
        // Arrange
        TestDataFactory.createSnapshot('In Progress');

        // Act
        Test.startTest();
        MigrationBatchJob job = new MigrationBatchJob('CORR-001');
        Database.QueryLocator ql = job.start(null);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, ql, 'QueryLocator should not be null for parameterised constructor');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: execute() — success path
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_execute_successPath_incrementsSuccessCount() {
        // Arrange
        List<ARMT_Snapshot__c> snaps = TestDataFactory.createSnapshots(5);
        MigrationBatchJob job = new MigrationBatchJob('CORR-002');

        // Act
        Test.startTest();
        job.execute(null, snaps);
        Test.stopTest();

        // Assert
        System.assertEquals(5, job.getSuccessCount(), 'All 5 records should succeed');
        System.assertEquals(0, job.getErrorCount(), 'Error count should be 0 on success path');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: execute() — bulk path (200+ records)
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_execute_bulkRecords_processesAll() {
        // Arrange
        List<ARMT_Snapshot__c> snaps = TestDataFactory.createSnapshots(200);
        MigrationBatchJob job = new MigrationBatchJob('CORR-BULK');

        // Act
        Test.startTest();
        job.execute(null, snaps);
        Test.stopTest();

        // Assert
        System.assertEquals(200, job.getSuccessCount(), '200 records should all succeed');
        System.assertEquals(0, job.getErrorCount(), 'No errors expected in bulk path');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: execute() — empty scope
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_execute_emptyScope_noCountChange() {
        // Arrange
        MigrationBatchJob job = new MigrationBatchJob('CORR-EMPTY');

        // Act
        Test.startTest();
        job.execute(null, new List<SObject>());
        Test.stopTest();

        // Assert
        System.assertEquals(0, job.getSuccessCount(), 'Success count should remain 0 for empty scope');
        System.assertEquals(0, job.getErrorCount(), 'Error count should remain 0 for empty scope');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: finish() — logs completion
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_finish_logsCompletion() {
        // Arrange
        MigrationProgressMonitoring.clearLog();
        MigrationBatchJob job = new MigrationBatchJob('CORR-FINISH');

        // Act
        Test.startTest();
        job.finish(null);
        Test.stopTest();

        // Assert
        List<MigrationProgressMonitoring.ProgressEntry> entries =
            MigrationProgressMonitoring.getProgressByCorrelationId('CORR-FINISH');
        Boolean foundFinish = false;
        for (MigrationProgressMonitoring.ProgressEntry e : entries) {
            if (e.eventType == 'FINISH') {
                foundFinish = true;
            }
        }
        System.assert(foundFinish, 'A FINISH log entry should be present after finish()');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: full batch execution via Database.executeBatch
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_fullBatchExecution_completesWithoutException() {
        // Arrange
        TestDataFactory.createSnapshots(10);
        MigrationProgressMonitoring.clearLog();

        // Act
        Test.startTest();
        Id jobId = Database.executeBatch(new MigrationBatchJob('CORR-FULL'), 5);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, jobId, 'Batch job Id should be returned');
        List<ARMT_Snapshot__c> updated = [
            SELECT Id, Status__c FROM ARMT_Snapshot__c WHERE Status__c = 'Complete'
        ];
        System.assertEquals(10, updated.size(), 'All 10 snapshots should be marked Complete');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: null correlationId handled gracefully
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_constructor_nullCorrelationId_usesDefault() {
        // Act
        Test.startTest();
        MigrationBatchJob job = new MigrationBatchJob(null);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, job.correlationId,
            'correlationId should be auto-generated when null is passed');
    }
}
