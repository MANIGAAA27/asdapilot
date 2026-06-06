/**
 * @file        TestMigrationProgressMonitoring.cls
 * @description Tests MigrationProgressMonitoring — covers progress logging,
 *              retrieval by correlation ID, log clearing, and null-safety.
 * @testFor     MigrationProgressMonitoring
 * @coverage    Target ≥ 90%.
 */
@isTest
private class TestMigrationProgressMonitoring {

    // ─────────────────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────────────────

    @testSetup
    static void setup() {
        // No DML required; MigrationProgressMonitoring is stateless across tests
        // when clearLog() is called in each test method.
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: logProgress — valid entry
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_logProgress_validEntry_addsToLog() {
        // Arrange
        MigrationProgressMonitoring.clearLog();

        // Act
        Test.startTest();
        MigrationProgressMonitoring.logProgress('CORR-001', 'TestClass', 'START', 'Test started');
        Test.stopTest();

        // Assert
        System.assertEquals(1, MigrationProgressMonitoring.getLogSize(),
            'Log should contain exactly 1 entry after one logProgress call');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: logProgress — null message handled gracefully
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_logProgress_nullMessage_handledGracefully() {
        // Arrange
        MigrationProgressMonitoring.clearLog();

        // Act
        Test.startTest();
        MigrationProgressMonitoring.logProgress('CORR-002', 'TestClass', 'INFO', null);
        Test.stopTest();

        // Assert
        List<MigrationProgressMonitoring.ProgressEntry> entries =
            MigrationProgressMonitoring.getProgressLog();
        System.assertEquals(1, entries.size(), 'Entry should still be added for null message');
        System.assertEquals('(no message)', entries[0].message,
            'Null message should be replaced with placeholder');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: getProgressLog — returns all entries
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getProgressLog_afterLogging_returnsEntries() {
        // Arrange
        MigrationProgressMonitoring.clearLog();
        MigrationProgressMonitoring.logProgress('CORR-003', 'ClassA', 'START', 'msg1');
        MigrationProgressMonitoring.logProgress('CORR-003', 'ClassA', 'FINISH', 'msg2');

        // Act
        Test.startTest();
        List<MigrationProgressMonitoring.ProgressEntry> entries =
            MigrationProgressMonitoring.getProgressLog();
        Test.stopTest();

        // Assert
        System.assertEquals(2, entries.size(), 'Should return 2 entries');
        System.assertEquals('START', entries[0].eventType, 'First entry should be START');
        System.assertEquals('FINISH', entries[1].eventType, 'Second entry should be FINISH');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: getProgressByCorrelationId — matching ID returns filtered list
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getProgressByCorrelationId_matchingId_returnsFiltered() {
        // Arrange
        MigrationProgressMonitoring.clearLog();
        MigrationProgressMonitoring.logProgress('CORR-A', 'ClassA', 'START', 'A started');
        MigrationProgressMonitoring.logProgress('CORR-B', 'ClassB', 'START', 'B started');
        MigrationProgressMonitoring.logProgress('CORR-A', 'ClassA', 'FINISH', 'A finished');

        // Act
        Test.startTest();
        List<MigrationProgressMonitoring.ProgressEntry> filtered =
            MigrationProgressMonitoring.getProgressByCorrelationId('CORR-A');
        Test.stopTest();

        // Assert
        System.assertEquals(2, filtered.size(), 'Should return 2 entries for CORR-A');
        for (MigrationProgressMonitoring.ProgressEntry e : filtered) {
            System.assertEquals('CORR-A', e.correlationId,
                'All returned entries should have correlationId = CORR-A');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: getProgressByCorrelationId — no match returns empty list
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getProgressByCorrelationId_noMatch_returnsEmpty() {
        // Arrange
        MigrationProgressMonitoring.clearLog();
        MigrationProgressMonitoring.logProgress('CORR-X', 'ClassX', 'START', 'X started');

        // Act
        Test.startTest();
        List<MigrationProgressMonitoring.ProgressEntry> filtered =
            MigrationProgressMonitoring.getProgressByCorrelationId('CORR-NOTEXIST');
        Test.stopTest();

        // Assert
        System.assertEquals(0, filtered.size(),
            'Should return empty list when no entries match the correlationId');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: clearLog — empties the log
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_clearLog_afterLogging_logIsEmpty() {
        // Arrange
        MigrationProgressMonitoring.logProgress('CORR-CLR', 'ClassC', 'START', 'msg');

        // Act
        Test.startTest();
        MigrationProgressMonitoring.clearLog();
        Test.stopTest();

        // Assert
        System.assertEquals(0, MigrationProgressMonitoring.getLogSize(),
            'Log should be empty after clearLog()');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: getLogSize — returns correct count
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getLogSize_afterMultipleEntries_returnsCorrectCount() {
        // Arrange
        MigrationProgressMonitoring.clearLog();

        // Act
        Test.startTest();
        MigrationProgressMonitoring.logProgress('C1', 'Cls', 'E1', 'msg1');
        MigrationProgressMonitoring.logProgress('C2', 'Cls', 'E2', 'msg2');
        MigrationProgressMonitoring.logProgress('C3', 'Cls', 'E3', 'msg3');
        Integer sz = MigrationProgressMonitoring.getLogSize();
        Test.stopTest();

        // Assert
        System.assertEquals(3, sz, 'Log size should be 3 after 3 logProgress calls');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: ProgressEntry fields are populated correctly
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_progressEntry_fields_populatedCorrectly() {
        // Arrange
        MigrationProgressMonitoring.clearLog();

        // Act
        Test.startTest();
        MigrationProgressMonitoring.logProgress('CORR-FIELD', 'FieldClass', 'FIELD_EVENT', 'field message');
        Test.stopTest();

        // Assert
        List<MigrationProgressMonitoring.ProgressEntry> entries =
            MigrationProgressMonitoring.getProgressLog();
        System.assertEquals(1, entries.size(), 'Should have 1 entry');
        MigrationProgressMonitoring.ProgressEntry e = entries[0];
        System.assertEquals('CORR-FIELD', e.correlationId, 'correlationId mismatch');
        System.assertEquals('FieldClass', e.sourceClass, 'sourceClass mismatch');
        System.assertEquals('FIELD_EVENT', e.eventType, 'eventType mismatch');
        System.assertEquals('field message', e.message, 'message mismatch');
        System.assertNotEquals(null, e.loggedAt, 'loggedAt should be populated');
    }
}
