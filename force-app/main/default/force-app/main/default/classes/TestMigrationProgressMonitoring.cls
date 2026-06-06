/**
 * @file        TestMigrationProgressMonitoring.cls
 * @description Tests MigrationProgressMonitoring — covers progress logging,
 *              retrieval behavior, null/empty edge cases, and test buffer management.
 * @testFor     MigrationProgressMonitoring
 * @coverage    Target ≥ 90%.
 */
@isTest
private class TestMigrationProgressMonitoring {

    @testSetup
    static void setupData() {
        // No DML setup required; MigrationProgressMonitoring uses in-memory
        // buffer during test execution.
    }

    @isTest
    static void test_logProgress_writesRecord() {
        MigrationProgressMonitoring.clearTestLogBuffer();
        ARMT_Snapshot__c snap = TestDataFactory.createSnapshot();

        Test.startTest();
        MigrationProgressMonitoring.logProgress(snap.Id, 'TestSource', 'Test message');
        Test.stopTest();

        List<String> buffer = MigrationProgressMonitoring.getTestLogBuffer();
        System.assertEquals(1, buffer.size(), 'Should have one log entry in buffer');
        System.assert(buffer[0].contains('TestSource'), 'Log entry should contain source');
        System.assert(buffer[0].contains('Test message'), 'Log entry should contain message');
    }

    @isTest
    static void test_logProgress_nullContextId_stillLogs() {
        MigrationProgressMonitoring.clearTestLogBuffer();

        Test.startTest();
        MigrationProgressMonitoring.logProgress(null, 'NullContextTest', 'Null context message');
        Test.stopTest();

        List<String> buffer = MigrationProgressMonitoring.getTestLogBuffer();
        System.assertEquals(1, buffer.size(), 'Should log even with null context ID');
        System.assert(buffer[0].contains('NO_CONTEXT'), 'Should use NO_CONTEXT placeholder');
    }

    @isTest
    static void test_logProgress_multipleEntries_allCaptured() {
        MigrationProgressMonitoring.clearTestLogBuffer();
        ARMT_Snapshot__c snap = TestDataFactory.createSnapshot();

        Test.startTest();
        MigrationProgressMonitoring.logProgress(snap.Id, 'Source1', 'Message 1');
        MigrationProgressMonitoring.logProgress(snap.Id, 'Source2', 'Message 2');
        MigrationProgressMonitoring.logProgress(snap.Id, 'Source3', 'Message 3');
        Test.stopTest();

        List<String> buffer = MigrationProgressMonitoring.getTestLogBuffer();
        System.assertEquals(3, buffer.size(), 'Should capture all 3 log entries');
    }

    @isTest
    static void test_getRecentProgress_emptyContext_returnsEmpty() {
        ARMT_Snapshot__c snap = TestDataFactory.createSnapshot();

        Test.startTest();
        List<ARMT_FlowLog__c> results = MigrationProgressMonitoring.getRecentProgress(snap.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result should not be null');
        System.assertEquals(0, results.size(),
            'Should return empty list when no log records exist for context');
    }

    @isTest
    static void test_getRecentProgress_nullContextId_returnsEmpty() {
        Test.startTest();
        List<ARMT_FlowLog__c> results = MigrationProgressMonitoring.getRecentProgress(null);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result should not be null');
        System.assertEquals(0, results.size(), 'Null context ID should return empty list');
    }

    @isTest
    static void test_getTestLogBuffer_returnsCurrentBuffer() {
        MigrationProgressMonitoring.clearTestLogBuffer();
        ARMT_Snapshot__c snap = TestDataFactory.createSnapshot();

        MigrationProgressMonitoring.logProgress(snap.Id, 'BufferTest', 'Buffer entry');

        Test.startTest();
        List<String> buffer = MigrationProgressMonitoring.getTestLogBuffer();
        Test.stopTest();

        System.assertNotEquals(null, buffer, 'Buffer should not be null');
        System.assertEquals(1, buffer.size(), 'Buffer should contain one entry');
    }

    @isTest
    static void test_clearTestLogBuffer_emptiesBuffer() {
        ARMT_Snapshot__c snap = TestDataFactory.createSnapshot();
        MigrationProgressMonitoring.logProgress(snap.Id, 'ClearTest', 'Entry before clear');

        Test.startTest();
        MigrationProgressMonitoring.clearTestLogBuffer();
        Test.stopTest();

        List<String> buffer = MigrationProgressMonitoring.getTestLogBuffer();
        System.assertEquals(0, buffer.size(), 'Buffer should be empty after clear');
    }

    @isTest
    static void test_logProgress_blankSource_stillLogs() {
        MigrationProgressMonitoring.clearTestLogBuffer();
        ARMT_Snapshot__c snap = TestDataFactory.createSnapshot();

        Test.startTest();
        MigrationProgressMonitoring.logProgress(snap.Id, '', 'Blank source message');
        Test.stopTest();

        List<String> buffer = MigrationProgressMonitoring.getTestLogBuffer();
        System.assertEquals(1, buffer.size(), 'Should log even with blank source');
    }

    @isTest
    static void test_logProgress_blankMessage_stillLogs() {
        MigrationProgressMonitoring.clearTestLogBuffer();
        ARMT_Snapshot__c snap = TestDataFactory.createSnapshot();

        Test.startTest();
        MigrationProgressMonitoring.logProgress(snap.Id, 'BlankMsgTest', '');
        Test.stopTest();

        List<String> buffer = MigrationProgressMonitoring.getTestLogBuffer();
        System.assertEquals(1, buffer.size(), 'Should log even with blank message');
    }
}
