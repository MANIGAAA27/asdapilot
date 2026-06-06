/**
 * @file        TestMigrationProgressMonitoring.cls
 * @description Tests MigrationProgressMonitoring — covers progress logging, retrieval behavior,
 *              null/blank input handling, and progress summary accuracy.
 * @testFor     MigrationProgressMonitoring
 * @coverage    Target ≥ 90%.
 */
@isTest
private class TestMigrationProgressMonitoring {

    /**
     * Tests that a valid progress log entry is inserted into ARMT_AuditLog__c.
     */
    @isTest
    static void test_logProgress_validInput_insertsAuditLog() {
        MigrationProgressMonitoring monitor = new MigrationProgressMonitoring();

        Test.startTest();
        Id logId = monitor.logProgress('Migration Started', 'Batch job initiated for 200 records.');
        Test.stopTest();

        System.assertNotEquals(null, logId, 'Expected a non-null log entry Id');
        ARMT_AuditLog__c log = [SELECT Id, Action__c, Details__c, User__c, Timestamp__c FROM ARMT_AuditLog__c WHERE Id = :logId];
        System.assertEquals('Migration Started', log.Action__c, 'Expected action = Migration Started');
        System.assertEquals('Batch job initiated for 200 records.', log.Details__c, 'Expected matching details');
        System.assertNotEquals(null, log.Timestamp__c, 'Expected Timestamp__c to be populated');
        System.assertEquals(UserInfo.getUserId(), log.User__c, 'Expected User__c to be current user');
    }

    /**
     * Tests that null details are accepted and the log entry is still inserted.
     */
    @isTest
    static void test_logProgress_nullDetails_insertsWithNullDetails() {
        MigrationProgressMonitoring monitor = new MigrationProgressMonitoring();

        Test.startTest();
        Id logId = monitor.logProgress('Scan Started', null);
        Test.stopTest();

        System.assertNotEquals(null, logId, 'Expected a non-null log entry Id for null details');
        ARMT_AuditLog__c log = [SELECT Id, Details__c FROM ARMT_AuditLog__c WHERE Id = :logId];
        System.assertEquals(null, log.Details__c, 'Expected null Details__c');
    }

    /**
     * Tests that blank action throws DataAccessException.
     */
    @isTest
    static void test_logProgress_blankAction_throwsDataAccessException() {
        MigrationProgressMonitoring monitor = new MigrationProgressMonitoring();
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            monitor.logProgress('', 'Some details');
        } catch (DataAccessException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('Action is required'), 'Expected action required message');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected DataAccessException for blank action');
    }

    /**
     * Tests that getRecentLogs returns entries ordered by timestamp descending.
     */
    @isTest
    static void test_getRecentLogs_returnsOrderedEntries() {
        MigrationProgressMonitoring monitor = new MigrationProgressMonitoring();
        // Insert multiple log entries
        monitor.logProgress('Scan Started', 'First entry');
        monitor.logProgress('Validation Run', 'Second entry');
        monitor.logProgress('Migration Started', 'Third entry');

        Test.startTest();
        List<ARMT_AuditLog__c> logs = monitor.getRecentLogs(10);
        Test.stopTest();

        System.assertEquals(3, logs.size(), 'Expected 3 log entries');
        // Most recent should be first
        System.assertEquals('Migration Started', logs[0].Action__c, 'Expected most recent entry first');
    }

    /**
     * Tests that getRecentLogs returns empty list when no entries exist.
     */
    @isTest
    static void test_getRecentLogs_emptyOrg_returnsEmpty() {
        MigrationProgressMonitoring monitor = new MigrationProgressMonitoring();

        Test.startTest();
        List<ARMT_AuditLog__c> logs = monitor.getRecentLogs(10);
        Test.stopTest();

        System.assertEquals(0, logs.size(), 'Expected empty list when no audit logs exist');
    }

    /**
     * Tests that getRecentLogs with null limit uses the default max.
     */
    @isTest
    static void test_getRecentLogs_nullLimit_usesDefault() {
        MigrationProgressMonitoring monitor = new MigrationProgressMonitoring();
        monitor.logProgress('Scan Started', 'Entry for null limit test');

        Test.startTest();
        List<ARMT_AuditLog__c> logs = monitor.getRecentLogs(null);
        Test.stopTest();

        System.assertEquals(1, logs.size(), 'Expected 1 log entry with null limit');
    }

    /**
     * Tests that getProgressSummary returns correct counts and latest action.
     */
    @isTest
    static void test_getProgressSummary_withLogs_returnsCorrectSummary() {
        MigrationProgressMonitoring monitor = new MigrationProgressMonitoring();
        monitor.logProgress('Scan Started', 'First');
        monitor.logProgress('Migration Started', 'Second');

        Test.startTest();
        MigrationProgressMonitoring.ProgressSummary summary = monitor.getProgressSummary();
        Test.stopTest();

        System.assertEquals(2, summary.totalEntries, 'Expected totalEntries = 2');
        System.assertNotEquals(null, summary.latestAction, 'Expected latestAction to be populated');
        System.assertNotEquals(null, summary.latestTimestamp, 'Expected latestTimestamp to be populated');
    }

    /**
     * Tests that getProgressSummary returns zero count when no logs exist.
     */
    @isTest
    static void test_getProgressSummary_noLogs_returnsZeroCount() {
        MigrationProgressMonitoring monitor = new MigrationProgressMonitoring();

        Test.startTest();
        MigrationProgressMonitoring.ProgressSummary summary = monitor.getProgressSummary();
        Test.stopTest();

        System.assertEquals(0, summary.totalEntries, 'Expected totalEntries = 0 when no logs');
        System.assertEquals(null, summary.latestAction, 'Expected null latestAction when no logs');
    }

    /**
     * Tests bulk logging of 200 entries within governor limits.
     */
    @isTest
    static void test_logProgress_bulk200_allInserted() {
        MigrationProgressMonitoring monitor = new MigrationProgressMonitoring();

        Test.startTest();
        for (Integer i = 0; i < 200; i++) {
            monitor.logProgress('Scan Started', 'Bulk entry ' + i);
        }
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM ARMT_AuditLog__c];
        System.assertEquals(200, count, 'Expected 200 audit log entries inserted in bulk');
    }
}
