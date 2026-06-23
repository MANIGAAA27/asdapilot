/**
 * @file        Account_SelectorTest.cls
 * @description Tests Account_Selector — covers each query method with data,
 *              null-input guards, and default-limit fallback.
 * @testFor     Account_Selector
 * @coverage    Target ≥ 90%.
 */
// MODIFIED 2026-06-23 — Project: Account 360 | CodeImplementation-Account360 | ASDA
@isTest
private class Account_SelectorTest {

    @TestSetup
    static void setupData() {
        Account acct = TestDataFactory.createAccount('Selector Test Account');
        TestDataFactory.createERPOrder(acct.Id, 'ERP-SEL-001');
        TestDataFactory.createInvoice(acct.Id, 'INV-SEL-001');
        Opportunity opp = new Opportunity(
            AccountId = acct.Id,
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 10000
        );
        insert opp;
        Case c = new Case(AccountId = acct.Id, Subject = 'Test Case', Priority = 'High', Status = 'New');
        insert c;
        Contract con = new Contract(AccountId = acct.Id, StartDate = Date.today(), ContractTerm = 12, Status = 'Draft');
        insert con;
    }

    @isTest
    static void test_getAccountById_validId_returnsAccount() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Selector Test Account' LIMIT 1];
        Test.startTest();
        Account result = Account_Selector.getAccountById(acct.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Should return an Account for a valid Id');
        System.assertEquals('Selector Test Account', result.Name, 'Name should match');
    }

    @isTest
    static void test_getAccountById_nullId_returnsNull() {
        Test.startTest();
        Account result = Account_Selector.getAccountById(null);
        Test.stopTest();
        System.assertEquals(null, result, 'Should return null for a null Id');
    }

    @isTest
    static void test_getOpportunitiesForAccount_withData_returnsList() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Selector Test Account' LIMIT 1];
        Test.startTest();
        List<Opportunity> results = Account_Selector.getOpportunitiesForAccount(acct.Id, 10);
        Test.stopTest();
        System.assert(!results.isEmpty(), 'Should return at least one Opportunity');
        System.assertEquals('Prospecting', results[0].StageName, 'Stage should match');
    }

    @isTest
    static void test_getOpportunitiesForAccount_nullId_returnsEmpty() {
        Test.startTest();
        List<Opportunity> results = Account_Selector.getOpportunitiesForAccount(null, 10);
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Should return empty list for null accountId');
    }

    @isTest
    static void test_getCasesForAccount_withData_returnsList() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Selector Test Account' LIMIT 1];
        Test.startTest();
        List<Case> results = Account_Selector.getCasesForAccount(acct.Id, 10);
        Test.stopTest();
        System.assert(!results.isEmpty(), 'Should return at least one Case');
        System.assertEquals('High', results[0].Priority, 'Priority should be High');
    }

    @isTest
    static void test_getContractsForAccount_withData_returnsList() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Selector Test Account' LIMIT 1];
        Test.startTest();
        List<Contract> results = Account_Selector.getContractsForAccount(acct.Id, 10);
        Test.stopTest();
        System.assert(!results.isEmpty(), 'Should return at least one Contract');
    }

    @isTest
    static void test_getERPOrdersForAccount_withData_returnsList() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Selector Test Account' LIMIT 1];
        Test.startTest();
        List<ERP_Order__c> results = Account_Selector.getERPOrdersForAccount(acct.Id, 10);
        Test.stopTest();
        System.assert(!results.isEmpty(), 'Should return at least one ERP Order');
        System.assertEquals('ERP-SEL-001', results[0].ERP_Order_ID__c, 'ERP Order ID should match');
    }

    @isTest
    static void test_getERPOrdersForAccount_nullLimit_usesDefault() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Selector Test Account' LIMIT 1];
        Test.startTest();
        List<ERP_Order__c> results = Account_Selector.getERPOrdersForAccount(acct.Id, null);
        Test.stopTest();
        System.assert(!results.isEmpty(), 'Should return results even with null limit');
    }

    @isTest
    static void test_getInvoicesForAccount_withData_returnsList() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Selector Test Account' LIMIT 1];
        Test.startTest();
        List<Invoice__c> results = Account_Selector.getInvoicesForAccount(acct.Id, 10);
        Test.stopTest();
        System.assert(!results.isEmpty(), 'Should return at least one Invoice');
        System.assertEquals('INV-SEL-001', results[0].ERP_Invoice_ID__c, 'ERP Invoice ID should match');
    }
}
