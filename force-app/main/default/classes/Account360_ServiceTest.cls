/**
 * @file        Account360_ServiceTest.cls
 * @description Tests Account360_Service — covers getAccountData and getERPOrders
 *              with valid inputs, null/blank inputs, and bulk scenarios.
 * @testFor     Account360_Service
 * @coverage    Target ≥ 90%.
 */
// MODIFIED 2026-06-23 — Project: Account 360 | CodeImplementation-Account360 | ASDA
@isTest
private class Account360_ServiceTest {

    @TestSetup
    static void setupData() {
        Account acct = TestDataFactory.createAccount('Service Test Account');
        TestDataFactory.createERPOrder(acct.Id, 'ERP-SVC-001');
        TestDataFactory.createInvoice(acct.Id, 'INV-SVC-001');
        Opportunity opp = new Opportunity(
            AccountId = acct.Id,
            Name = 'Service Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 15000
        );
        insert opp;
        Case c = new Case(AccountId = acct.Id, Subject = 'Service Test Case', Priority = 'Medium', Status = 'New');
        insert c;
    }

    @isTest
    static void test_getAccountData_validId_returnsWrapper() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Service Test Account' LIMIT 1];
        Test.startTest();
        Account360_Service.AccountDataWrapper wrapper = Account360_Service.getAccountData(acct.Id);
        Test.stopTest();
        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
        System.assertNotEquals(null, wrapper.accountRecord, 'Account record should be populated');
        System.assertEquals('Service Test Account', wrapper.accountRecord.Name, 'Account name should match');
        System.assert(!wrapper.opportunities.isEmpty(), 'Should have at least one Opportunity');
        System.assert(!wrapper.cases.isEmpty(), 'Should have at least one Case');
        System.assert(!wrapper.erpOrders.isEmpty(), 'Should have at least one ERP Order');
        System.assert(!wrapper.invoices.isEmpty(), 'Should have at least one Invoice');
    }

    @isTest
    static void test_getAccountData_nullId_throwsException() {
        Test.startTest();
        try {
            Account360_Service.getAccountData(null);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('required'), 'Exception message should mention required');
        }
        Test.stopTest();
    }

    @isTest
    static void test_getAccountData_blankId_throwsException() {
        Test.startTest();
        try {
            Account360_Service.getAccountData('');
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Exception should have a message');
        }
        Test.stopTest();
    }

    @isTest
    static void test_getERPOrders_validId_returnsList() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Service Test Account' LIMIT 1];
        Test.startTest();
        List<ERP_Order__c> orders = Account360_Service.getERPOrders(acct.Id, 5);
        Test.stopTest();
        System.assert(!orders.isEmpty(), 'Should return at least one ERP Order');
        System.assertEquals('ERP-SVC-001', orders[0].ERP_Order_ID__c, 'ERP Order ID should match');
    }

    @isTest
    static void test_getERPOrders_nullLimit_usesDefault() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Service Test Account' LIMIT 1];
        Test.startTest();
        List<ERP_Order__c> orders = Account360_Service.getERPOrders(acct.Id, null);
        Test.stopTest();
        System.assert(!orders.isEmpty(), 'Should return orders even with null limit');
    }

    @isTest
    static void test_getERPOrders_nullId_throwsException() {
        Test.startTest();
        try {
            Account360_Service.getERPOrders(null, 10);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Exception should have a message');
        }
        Test.stopTest();
    }

    @isTest
    static void test_getAccountData_emptyListsInitialised() {
        Account emptyAcct = TestDataFactory.createAccount('Empty Account No Children');
        Test.startTest();
        Account360_Service.AccountDataWrapper wrapper = Account360_Service.getAccountData(emptyAcct.Id);
        Test.stopTest();
        System.assertNotEquals(null, wrapper.opportunities, 'Opportunities list should not be null');
        System.assertNotEquals(null, wrapper.cases, 'Cases list should not be null');
        System.assertNotEquals(null, wrapper.contracts, 'Contracts list should not be null');
        System.assertNotEquals(null, wrapper.erpOrders, 'ERP Orders list should not be null');
        System.assertNotEquals(null, wrapper.invoices, 'Invoices list should not be null');
    }

    @isTest
    static void test_getAccountData_bulk200Accounts_noExceptions() {
        List<Account> bulkAccts = TestDataFactory.createAccounts(200);
        Test.startTest();
        Account360_Service.AccountDataWrapper wrapper = Account360_Service.getAccountData(bulkAccts[0].Id);
        Test.stopTest();
        System.assertNotEquals(null, wrapper, 'Wrapper should not be null for bulk account');
    }
}
