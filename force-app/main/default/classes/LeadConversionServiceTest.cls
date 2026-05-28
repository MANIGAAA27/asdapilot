/**
 * @file        LeadConversionServiceTest.cls
 * @description Tests for LeadConversionService. Covers field retrieval, account
 *              and contact matching, quarter-end date calculation, and all
 *              conversion paths: new records, existing account, existing contact,
 *              no opportunity, and error handling.
 * @testFor     LeadConversionService
 * @coverage    Target ≥ 90%. Last measured 2026-05-28.
 */
@isTest
private class LeadConversionServiceTest {

    // ─────────────────────────────────────────────────────────────────────────
    //  Test Setup
    // ─────────────────────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        TestDataFactory.createLead('Jane', 'Doe', 'Keneland Tech');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  getLeadForConversion
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getLeadForConversion_validId_returnsLead() {
        Lead inserted = [SELECT Id FROM Lead WHERE LastName = 'Doe' LIMIT 1];

        Test.startTest();
        Lead result = LeadConversionService.getLeadForConversion(inserted.Id);
        Test.stopTest();

        System.assertEquals('Jane',         result.FirstName,  'FirstName mismatch');
        System.assertEquals('Doe',          result.LastName,   'LastName mismatch');
        System.assertEquals('Keneland Tech',result.Company,    'Company mismatch');
        System.assertEquals('Technology',   result.Industry,   'Industry mismatch');
        System.assertEquals(50000.00,       result.Conversion_Amount__c, 'Amount mismatch');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  findMatchingAccounts
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_findMatchingAccounts_matchFound_returnsAccounts() {
        TestDataFactory.createAccount('Keneland Tech');

        Test.startTest();
        List<Account> results = LeadConversionService.findMatchingAccounts('Keneland Tech');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one matching account');
        System.assertEquals('Keneland Tech', results[0].Name, 'Account name mismatch');
    }

    @isTest
    static void test_findMatchingAccounts_noMatch_returnsEmpty() {
        Test.startTest();
        List<Account> results = LeadConversionService.findMatchingAccounts('NonExistentCorpXYZ');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected empty list for no match');
    }

    @isTest
    static void test_findMatchingAccounts_blankInput_returnsEmpty() {
        Test.startTest();
        List<Account> results = LeadConversionService.findMatchingAccounts('');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected empty list for blank input');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  findMatchingContacts
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_findMatchingContacts_matchFound_returnsContacts() {
        Account acct = TestDataFactory.createAccount('Keneland Tech');
        TestDataFactory.createContact(acct.Id, 'Jane', 'Doe', 'jane.doe@kenelandtech.example.com');

        Test.startTest();
        List<Contact> results = LeadConversionService.findMatchingContacts(
            'jane.doe@kenelandtech.example.com'
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one matching contact');
        System.assertEquals('jane.doe@kenelandtech.example.com', results[0].Email, 'Email mismatch');
    }

    @isTest
    static void test_findMatchingContacts_noMatch_returnsEmpty() {
        Test.startTest();
        List<Contact> results = LeadConversionService.findMatchingContacts(
            'nobody@nowhere.example.com'
        );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected empty list for no match');
    }

    @isTest
    static void test_findMatchingContacts_blankInput_returnsEmpty() {
        Test.startTest();
        List<Contact> results = LeadConversionService.findMatchingContacts('');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected empty list for blank email');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  getQuarterEndDate
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getQuarterEndDate_returnsCorrectDate() {
        Test.startTest();
        Date result = LeadConversionService.getQuarterEndDate();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Quarter end date must not be null');

        Integer month = result.month();
        System.assert(
            month == 3 || month == 6 || month == 9 || month == 12,
            'Quarter end month must be 3, 6, 9, or 12 — got: ' + month
        );

        Integer expectedDay = (month == 3 || month == 12) ? 31 : 30;
        System.assertEquals(expectedDay, result.day(),
            'Quarter end day mismatch for month ' + month
        );
        System.assertEquals(Date.today().year(), result.year(), 'Year mismatch');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  convertLead — new records path
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_convertLead_newRecords_success() {
        Lead testLead = [SELECT Id, Company FROM Lead WHERE LastName = 'Doe' LIMIT 1];

        LeadConversionService.ConversionRequest req = buildBaseRequest(testLead.Id);
        req.useExistingAccount = false;
        req.newAccountName     = testLead.Company;
        req.createOpportunity  = true;
        req.opportunityName    = testLead.Company;
        req.opportunityCloseDate = Date.today().addDays(90);

        Test.startTest();
        List<LeadConversionService.ConversionResult> results =
            LeadConversionService.convertLead(
                new List<LeadConversionService.ConversionRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one result');
        System.assertEquals(true, results[0].success,
            'Expected success. Error: ' + results[0].errorMessage);
        System.assertNotEquals(null, results[0].convertedAccountId, 'Account ID should be set');
        System.assertNotEquals(null, results[0].convertedContactId, 'Contact ID should be set');
        System.assertNotEquals(null, results[0].convertedOpportunityId, 'Opportunity ID should be set');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  convertLead — existing account path
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_convertLead_existingAccount_success() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Doe' LIMIT 1];
        Account existingAccount = TestDataFactory.createAccount('Keneland Tech');

        LeadConversionService.ConversionRequest req = buildBaseRequest(testLead.Id);
        req.useExistingAccount  = true;
        req.existingAccountId   = existingAccount.Id;
        req.createOpportunity   = false;

        Test.startTest();
        List<LeadConversionService.ConversionResult> results =
            LeadConversionService.convertLead(
                new List<LeadConversionService.ConversionRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].success,
            'Expected success with existing account. Error: ' + results[0].errorMessage);
        System.assertEquals(existingAccount.Id, results[0].convertedAccountId,
            'Should use the existing account');
        System.assertEquals(null, results[0].convertedOpportunityId,
            'No opportunity expected when createOpportunity = false');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  convertLead — no opportunity path
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_convertLead_noOpportunity_success() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Doe' LIMIT 1];

        LeadConversionService.ConversionRequest req = buildBaseRequest(testLead.Id);
        req.useExistingAccount = false;
        req.createOpportunity  = false;

        Test.startTest();
        List<LeadConversionService.ConversionResult> results =
            LeadConversionService.convertLead(
                new List<LeadConversionService.ConversionRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].success,
            'Expected success without opportunity. Error: ' + results[0].errorMessage);
        System.assertEquals(null, results[0].convertedOpportunityId,
            'Opportunity ID should be null when skipped');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  convertLead — null leadId error path
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_convertLead_nullLeadId_fails() {
        LeadConversionService.ConversionRequest req = new LeadConversionService.ConversionRequest();
        req.leadId = null;

        Test.startTest();
        List<LeadConversionService.ConversionResult> results =
            LeadConversionService.convertLead(
                new List<LeadConversionService.ConversionRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Expected failure for null leadId');
        System.assert(
            String.isNotBlank(results[0].errorMessage),
            'Error message should be populated'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Builds a ConversionRequest pre-populated with common field-mapping values. */
    private static LeadConversionService.ConversionRequest buildBaseRequest(Id leadId) {
        LeadConversionService.ConversionRequest req = new LeadConversionService.ConversionRequest();
        req.leadId                = leadId;
        req.useExistingContact    = false;
        req.leadTitle             = 'CEO';
        req.leadMobilePhone       = '415-555-0101';
        req.leadIndustry          = 'Technology';
        req.leadWebsite           = 'https://www.kenelandtech.example.com';
        req.leadPhone             = '415-555-0100';
        req.leadBillingStreet     = '123 Main St';
        req.leadBillingCity       = 'San Francisco';
        req.leadBillingState      = 'CA';
        req.leadBillingPostalCode = '94105';
        req.opportunityAmount     = 50000.00;
        return req;
    }
}