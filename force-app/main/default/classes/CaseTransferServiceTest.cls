/**
 * @file        CaseTransferServiceTest.cls
 * @project     Case Transfer
 * @lld         LLD-CaseTransfer-2 (BR3-BR4)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-05
 */
/**
 * @file              CaseTransferServiceTest.cls
 * @description       Test class for CaseTransferService.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-23
 * @lastModified      2026-05-23
 * @group             CaseManagement
 *
 * @dependencies      CaseTransferService
 * @testClass         (self)
 *
 * @see               LLD Case Transfer Summary Generation
 */
@isTest
private class CaseTransferServiceTest {
    
    @isTest
    static void testHandleTransfers_createsSum summary() {
        // Arrange
        User testUser1 = createTestUser('user1@test.com');
        User testUser2 = createTestUser('user2@test.com');
        
        Case testCase = new Case(
            Subject = 'Test Transfer',
            Status = 'New',
            OwnerId = testUser1.Id
        );
        insert testCase;
        
        testCase.OwnerId = testUser2.Id;
        update testCase;
        
        // Act
        Test.startTest();
        CaseTransferService.handleTransfers(new Set<Id>{ testCase.Id });
        Test.stopTest();
        
        // Assert
        List<CaseTransferSummary__c> summaries = [
            SELECT Id, Case__c, GenerationStatus__c, TransferredFrom__c, TransferredTo__c
            FROM CaseTransferSummary__c
            WHERE Case__c = :