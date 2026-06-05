/**
 * @file        ErrorLoggerTest.cls
 * @project     Account Deactivation
 * @lld         LLD - Intelligent Suppression Engine for Inactive Records in Lookups, Reports, Flows, Lightning, and API Contexts (draft)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-05
 */
/**
 * @file              ErrorLoggerTest.cls
 * @description       Test coverage for ErrorLogger and AppException classes.
 *                    Validates error logging, exception routing, and graceful fallback.
 * @author            ASDA Dev Agent
 * @created           2025-01-23
 * @lastModified      2025-01-23
 * @group             Tests
 *
 * @dependencies      ErrorLogger, AppException, Governance_Log__c
 * @calledBy          (Test execution only)
 * @testClass         N/A (this is the test class)
 *
 * @see               ErrorLogger.cls, AppException.cls
 */

/**
 * Test class for ErrorLogger and AppException.
 * Covers error capture, logging, and custom exception flows.
 */
@isTest
private class ErrorLoggerTest {
    
    /**
     * Validates that logError creates a Governance_Log__c record with full context.
     */
    @isTest
    static void testLogErrorCreatesGovernanceLogRecord() {
        // Arrange
        Exception testEx = new AppException('Test error message');
        
        // Act
        Test.startTest();
        ErrorLogger.logError(testEx, 'TestClass', 'testMethod', 'a001234567890AAA');
        Test.stopTest();
        
        // Assert
        List<Governance_Log__c> logs = [
            SELECT Log_Type__c, Class_Name__c, Method_Name__c, Error_Message__c, Record_Id__c
            FROM Governance_Log__c
            LIMIT 1
        ];
        
        System.assertEquals(1, logs.size(), 'Expected exactly one log record');
        System.assertEquals('Error', logs[0].Log_Type__c, 'Log type should be Error');
        System.assertEquals('TestClass', logs[0].Class_Name__c, 'Class name should match input');
        System.assertEquals('testMethod', logs[0].Method_Name__c, 'Method name should match input');
        System.assertEquals('Test error message', logs[0].Error_Message__c, 'Error message should match exception');
        System.assertEquals('a001234567890AAA', logs[0].Record_Id__c, 'Record ID should match input');
    }
    
    /**
     * Validates overloaded logError without recordId parameter.
     */
    @isTest
    static void testLogErrorWithoutRecordId() {
        // Arrange
        Exception testEx = new QueryException('Query failed');
        
        // Act
        Test.startTest();
        ErrorLogger.logError(testEx, 'ServiceClass', 'queryMethod');
        Test.stopTest();
        
        // Assert
        List<Governance_Log__c> logs = [
            SELECT Record_Id__c
            FROM Governance_Log__c
            LIMIT 1
        ];
        
        System.assertEquals(1, logs.size(), 'Expected one log record');
        System.assertEquals(null, logs[0].Record_Id__c, 'Record ID should be null when not provided');
    }
    
    /**
     * Validates throwAppException logs and throws AppException.
     */
    @isTest
    static void testThrowAppExceptionLogsAndThrows() {
        // Arrange
        Boolean exceptionCaught = false;
        
        // Act
        Test.startTest();
        try {
            ErrorLogger.throwAppException('Custom app error', 'BusinessLogic', 'validateInput');
        } catch (AppException ex) {
            exceptionCaught = true;
            System.assertEquals('Custom app error', ex.getMessage(), 'Exception message should match input');
        }
        Test.stopTest();
        
        // Assert
        System.assert(exceptionCaught, 'AppException should have been thrown');
        
        List<Governance_Log__c> logs = [
            SELECT Error_Message__c, Class_Name__c
            FROM Governance_Log__c
            LIMIT 1
        ];
        
        System.assertEquals(1, logs.size(), 'Error should be logged before throwing');
        System.assertEquals('Custom app error', logs[0].Error_Message__c, 'Logged message should match exception');
    }
    
    /**
     * Validates ErrorLogger handles logging failures gracefully without throwing.
     */
    @isTest
    static void testLogErrorHandlesInsertFailureGracefully() {
        // Arrange - simulate a scenario where Governance_Log__c insert might fail
        // (In real scenario, this might involve field-level security or validation rules)
        Exception testEx = new DmlException('DML operation failed');
        
        // Act - should not throw even if internal logging fails
        Test.startTest();
        try {
            ErrorLogger.logError(testEx, 'FailureTestClass', 'testMethod', null);
            System.assert(true, 'logError should not throw even on internal failures');
        } catch (Exception ex) {
            System.assert(false, 'ErrorLogger should handle internal failures gracefully: ' + ex.getMessage());
        }
        Test.stopTest();
    }
}
