/**
 * @file        TestDataFactoryTest.cls
 * @project     Account Deactivation
 * @lld         LLD - Intelligent Suppression Engine for Inactive Records in Lookups, Reports, Flows, Lightning, and API Contexts (draft)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-05
 */
/**
 * @file              TestDataFactoryTest.cls
 * @description       Test coverage for TestDataFactory utility class.
 * @author            ASDA Dev Agent
 * @created           2025-01-23
 * @lastModified      2025-01-23
 * @group             Tests
 *
 * @dependencies      TestDataFactory
 * @calledBy          (Test execution only)
 * @testClass         N/A (this is the test class)
 */

@isTest
private class TestDataFactoryTest {
    
    @isTest
    static void testCreateAccountsWithInsert() {
        Test.startTest();
        List<Account> accounts = TestDataFactory.createAccounts(5, true);
        Test.stopTest();
        
        System.assertEquals(5, accounts.size(), 'Should create 5 accounts');
        System.assertNotEquals(null, accounts[0].Id, 'Accounts should be inserted');
    }
    
    @isTest
    static void testCreateContactsWithInsert() {
        Account acc = TestDataFactory.createAccounts(1, true)[0];
        
        Test.startTest();
        List<Contact> contacts = TestDataFactory.createContacts(acc.Id, 3, true);
        Test.stopTest();
        
        System.assertEquals(3, contacts.size(), 'Should create 3 contacts');
        System.assertEquals(acc.Id, contacts[0].AccountId, 'Contacts should be associated with account');
    }
    
    @isTest
    static void testCreateGovernanceLog() {
        Test.startTest();
        Governance_Log__c log = TestDataFactory.createGovernanceLog('Error', 'TestClass', true);
        Test.stopTest();
        
        System.assertNotEquals(null, log.Id, 'Log should be inserted');
        System.assertEquals('Error', log.Log_Type__c, 'Log type should match input');
    }
}
