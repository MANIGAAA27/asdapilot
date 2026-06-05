/**
 * @file        CaseTriggerHandlerTest.cls
 * @project     Case Transfer
 * @lld         LLD-CaseTransfer-2 (BR3-BR4)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-05
 */
/**
 * @file              CaseTriggerHandlerTest.cls
 * @description       Test class for CaseTriggerHandler. Validates ownership
 *                    change detection and service delegation.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-23
 * @lastModified      2026-05-23
 * @group             CaseManagement
 *
 * @dependencies      CaseTriggerHandler, CaseTransferService
 * @testClass         (self)
 *
 * @see               LLD Case Transfer Summary Generation
 */
@isTest
private class CaseTriggerHandlerTest {
    
    @isTest
    static void testAfterUpdate_ownershipChange_enqueuesService() {
        // Arrange
        User testUser1 = createTestUser('test1@example.com');
        User testUser2 = createTestUser('test2@example.com');
        
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            OwnerId = testUser1.Id
        );
        insert testCase;
        
        // Act
        Test.startTest();
        testCase.OwnerId = testUser2.Id;
        update testCase;
        Test.stopTest();
        
        // Assert
        List<CaseTransferSummary__c> summaries = [
            SELECT Id, Case__c, GenerationStatus__c
            FROM CaseTransferSummary__c
            WHERE Case__c = :testCase.Id
        ];
        
        System.assertEquals(1, summaries.size(), 'Should create one transfer summary');
        System.assert(
            summaries[0].GenerationStatus__c == 'Pending' || 
            summaries[0].GenerationStatus__c == 'Completed',
            'Status should be Pending or Completed'
        );
    }
    
    @isTest
    static void testAfterUpdate_noOwnershipChange_noSummary() {
        // Arrange
        User testUser = createTestUser('test@example.com');
        
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            OwnerId = testUser.Id
        );
        insert testCase;
        
        // Act
        Test.startTest();
        testCase.Subject = 'Updated Subject';
        update testCase;
        Test.stopTest();
        
        // Assert
        List<CaseTransferSummary__c> summaries = [
            SELECT Id
            FROM CaseTransferSummary__c
            WHERE Case__c = :testCase.Id
        ];
        
        System.assertEquals(0, summaries.size(), 'Should not create summary when owner unchanged');
    }
    
    private static User createTestUser(String email) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = email.substring(0, 5),
            Email = email,
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = email + System.currentTimeMillis()
        );
        insert u;
        return u;
    }
}
