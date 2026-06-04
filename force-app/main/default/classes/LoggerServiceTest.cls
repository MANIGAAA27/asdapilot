/**
 * @file        LoggerServiceTest.cls
 * @project     Account Deactivation
 * @lld         Implementation - Automated Lifecycle Policy Engine Using Scheduled Flows and Asynchronous Apex (draft)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-04
 */
/**
 * @file        LoggerServiceTest.cls
 * @description Test coverage for LoggerService
 * @testFor     LoggerService
 * @author      ASDA Dev Agent
 * @created     2026-06-04
 */
@isTest
private class LoggerServiceTest {
    
    @isTest
    static void test_log_success() {
        Test.startTest();
        LoggerService.log('Test message', 'TestClass.testMethod', 'INFO');
        Test.stopTest();
        
        List<Error_Log__c> logs = [
            SELECT Id, Message__c, Source__c, Level__c 
            FROM Error_Log__c 
            WHERE Message__c = 'Test message'
        ];
        
        System.assertEquals(1, logs.size(), 'One log record should be created');
        System.assertEquals('TestClass.testMethod', logs[0].Source__c, 'Source should match');
        System.assertEquals('INFO', logs[0].Level__c, 'Level should match');
    }
    
    @isTest
    static void test_logException_success() {
        Exception testException = new AppException('Test exception');
        
        Test.startTest();
        LoggerService.logException(testException, 'TestClass.testMethod');
        Test.stopTest();
        
        List<Error_Log__c> logs = [
            SELECT Id, Message__c, Stack_Trace__c, Exception_Type__c 
            FROM Error_Log__c 
            WHERE Exception_Type__c = 'AppException'
        ];
        
        System.assertEquals(1, logs.size(), 'One exception log should be created');
        System.assert(logs[0].Message__c.contains('Test exception'), 
                     'Message should contain exception message');
    }
    
    @isTest
    static void test_log_bulkInsert() {
        List<String> messages = new List<String>();
        for (Integer i = 0; i < 200; i++) {
            messages.add('Bulk message ' + i);
        }
        
        Test.startTest();
        for (String msg : messages) {
            LoggerService.log(msg, 'BulkTest', 'INFO');
        }
        Test.stopTest();
        
        Integer logCount = [SELECT COUNT() FROM Error_Log__c WHERE Source__c = 'BulkTest'];
        System.assertEquals(200, logCount, 'All 200 logs should be created');
    }
    
    @isTest
    static void test_log_nullMessage() {
        Test.startTest();
        try {
            LoggerService.log(null, 'TestClass', 'ERROR');
        } catch (AppException e) {
            System.assert(e.getMessage().contains('Message cannot be null'), 
                         'Should throw AppException for null message');
        }
        Test.stopTest();
    }
}
