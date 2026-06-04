/**
 * @file        ManualInactivationControllerTest.cls
 * @description Test coverage for ManualInactivationController
 * @testFor     ManualInactivationController
 * @author      ASDA Dev Agent
 * @created     2026-06-04
 */
// MODIFIED 2026-06-04 — Project: Account Deactivation | Implementation - Automated Lifecycle Policy Engine Using Scheduled Flows and Asynchronous Apex (draft) | ASDA
@isTest
private class ManualInactivationControllerTest {
    
    @TestSetup
    static void setupData() {
        TestDataFactory.createAccounts(5, false);
    }
    
    @isTest
    static void test_inactivateAccounts_success() {
        List<Account> accounts = [SELECT Id FROM Account WHERE Is_Inactive__c = false];
        List<Id> accountIds = new List<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        
        Test.startTest();
        Integer result = ManualInactivationController.inactivateAccounts(
            accountIds, 
            'Manual Inactivation'
        );
        Test.stopTest();
        
        System.assertEquals(5, result, 'Should inactivate all 5 accounts');
        
        List<Account> inactivated = [
            SELECT Id, Is_Inactive__c 
            FROM Account 
            WHERE Id IN :accountIds
        ];
        for (Account acc : inactivated) {
            System.assertEquals(true, acc.Is_Inactive__c, 'Account should be inactive');
        }
        
        List<Governance_Log__c> logs = [
            SELECT Id, Change_Type__c 
            FROM Governance_Log__c 
            WHERE Change_Type__c = 'Inactivated'
        ];
        System.assertEquals(5, logs.size(), 'Should create 5 governance logs');
    }
    
    @isTest
    static void test_inactivateAccounts_emptyList() {
        Test.startTest();
        try {
            ManualInactivationController.inactivateAccounts(new List<Id>(), 'Test');
            System.assert(false, 'Should throw exception for empty list');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('cannot be empty'), 
                         'Should throw exception with appropriate message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void test_inactivateAccounts_alreadyInactive() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 2];
        update new List<Account>{
            new Account(Id = accounts[0].Id, Is_Inactive__c = true),
            new Account(Id = accounts[1].Id, Is_Inactive__c = true)
        };
        
        List<Id> accountIds = new List<Id>{ accounts[0].Id, accounts[1].Id };
        
        Test.startTest();
        Integer result = ManualInactivationController.inactivateAccounts(
            accountIds, 
            'Test'
        );
        Test.stopTest();
        
        System.assertEquals(0, result, 'Should return 0 for already inactive accounts');
    }
}
