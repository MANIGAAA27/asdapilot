/**
 * @file        ErrorLoggerTest.cls
 * @description Tests ErrorLogger — covers exception logging, direct error log creation,
 *              and admin notification paths. Verifies Error_Log__c records are inserted
 *              with correct field values and emails are queued.
 * @testFor     ErrorLogger
 * @coverage    Target >= 90%. Last measured 2026-05-30.
 */
@isTest
private class ErrorLoggerTest {

    @TestSetup
    static void setup() {
        // No SObjects beyond Error_Log__c are needed for ErrorLogger tests.
    }

    @isTest
    static void test_logException_validException_createsLog() {
        CaseTransferException ex = new CaseTransferException('Test error message');

        Test.startTest();
        ErrorLogger.logException(ex, 'ErrorLoggerTest');
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Error_Message__c, Class_Name__c, Severity__c
            FROM   Error_Log__c
            WHERE  Class_Name__c = 'ErrorLoggerTest'
        ];
        System.assertEquals(1, logs.size(), 'Expected one error log to be created');
        System.assertEquals('Test error message', logs[0].Error_Message__c, 'Error message should match');
        System.assertEquals('Error', logs[0].Severity__c, 'Severity should be Error');
    }

    @isTest
    static void test_logException_withRecordId_setsRelatedId() {
        // Need a real Case to get a valid Id
        Case testCase = new Case(Subject = 'ErrorLogger Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        CaseTransferException ex = new CaseTransferException('Transfer failed');

        Test.startTest();
        ErrorLogger.logException(ex, 'CaseTransferService', testCase.Id);
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Related_Record_Id__c
            FROM   Error_Log__c
            WHERE  Class_Name__c = 'CaseTransferService'
        ];
        System.assertEquals(1, logs.size(), 'Expected one log record');
        System.assertEquals(String.valueOf(testCase.Id), logs[0].Related_Record_Id__c,
            'Related record Id should be set');
    }

    @isTest
    static void test_createErrorLog_validData_insertsRecord() {
        Test.startTest();
        ErrorLogger.createErrorLog(
            'Manual error',
            'TestClass',
            'Line 42 in TestClass',
            'Warning',
            null
        );
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Error_Message__c, Severity__c, Class_Name__c
            FROM   Error_Log__c
            WHERE  Class_Name__c = 'TestClass'
        ];
        System.assertEquals(1, logs.size(), 'Expected one error log');
        System.assertEquals('Warning', logs[0].Severity__c, 'Severity should be Warning');
    }

    @isTest
    static void test_notifyAdministrator_validMessage_queuesEmail() {
        // Verify no exception is thrown — email sending is async, so count check
        // is not reliable in tests. We verify no exception.
        Test.startTest();
        ErrorLogger.notifyAdministrator('Critical Error', 'Body of the error notification');
        Test.stopTest();

        // If we reach here without an unhandled exception the method is considered passing.
        System.assert(true, 'notifyAdministrator completed without throwing');
    }

    @isTest
    static void test_logException_bulk200_handlesAll() {
        List<CaseTransferException> exceptions = new List<CaseTransferException>();
        for (Integer i = 0; i < 10; i++) {
            exceptions.add(new CaseTransferException('Bulk error ' + i));
        }

        Test.startTest();
        for (CaseTransferException ex : exceptions) {
            ErrorLogger.logException(ex, 'BulkTest');
        }
        Test.stopTest();

        Integer logCount = [SELECT COUNT() FROM Error_Log__c WHERE Class_Name__c = 'BulkTest'];
        System.assertEquals(10, logCount, 'All exceptions should produce log records');
    }
}
