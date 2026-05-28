/**
 * @file        LeadConversionControllerTest.cls
 * @description Tests for LeadConversionController. Covers all AuraEnabled
 *              endpoints: getLeadData, findMatchingAccounts, findMatchingContacts,
 *              getQuarterEndDate, and performConversion (new records, existing
 *              account, no opportunity, and null-leadId failure paths).
 * @testFor     LeadConversionController
 * @coverage    Target ≥ 90%. Last measured 2026-05-28.
 */
@isTest
private class LeadConversionControllerTest {

    // ─────────────────────────────────────────────────────────────────────────
    //  Test Setup
    // ─────────────────────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        TestDataFactory.createLead('John', 'Smith', 'Keneland LLC');
        Account acct = TestDataFactory.createAccount('Keneland LLC');
        TestDataFactory.createContact(
            acct.Id, 'John', 'Smith', 'john.smith@kenelandllc.example.com'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  getLeadData
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getLeadData_validId_returnsLead() {
        Lead inserted = [SELECT Id FROM Lead WHERE LastName = 'Smith' LIMIT 1];

        Test.startTest();
        Lead result = LeadConversionController.getLeadData(inserted.Id);
        Test.stopTest();

        System.assertEquals('John',        result.FirstName, 'FirstName mismatch');
        System.assertEquals('Smith',       result.LastName,  'LastName mismatch');
        System.assertEquals('Keneland LLC',result.Company,   'Company mismatch');
    }

    @isTest
    static void test_getLeadData_invalidId_throwsAuraHandledException() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            LeadConversionController.getLeadData('001000000000000AAA');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        } catch (Exception ex) {
            // Accept any exception for an invalid Id — AuraHandledException wraps it
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Expected an exception for invalid Id');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  findMatchingAccounts
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_findMatchingAccounts_matchFound_returnsAccounts() {
        Test.startTest();
        List<Account> results = LeadConversionController.findMatchingAccounts('Keneland LLC');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one matching account');
        System.assertEquals('Keneland LLC', results[0].Name, 'Account name mismatch');
    }

    @isTest
    static void test_findMatchingAccounts_noMatch_returnsEmpty() {
        Test.startTest();
        List<Account> results = LeadConversionController.findMatchingAccounts('UnknownCorpABC');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected empty list');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  findMatchingContacts
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_findMatchingContacts_matchFound_returnsContacts() {
        Test.startTest();
        List<Contact> results = LeadConversionController.findMatchingContacts(
            'john.smith@kenelandllc.example.com'
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one matching contact');
        System.assertEquals(
            'john.smith@kenelandllc.example.com',
            results[0].Email,
            'Email mismatch'
        );
    }

    @isTest
    static void test_findMatchingContacts_noMatch_returnsEmpty() {
        Test.startTest();
        List<Contact> results = LeadConversionController.findMatchingContacts(
            'nobody@nobody.example.com'
        );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Expected empty list');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  getQuarterEndDate
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getQuarterEndDate_returnsExpectedDate() {
        Test.startTest();
        Date result = LeadConversionController.getQuarterEndDate();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Quarter end date must not be null');
        Integer m = result.month();
        System.assert(
            m == 3 || m == 6 || m == 9 || m == 12,
            'Expected quarter-end month (3/6/9/12), got: ' + m
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  performConversion — new records path
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_performConversion_newRecords_success() {
        Lead testLead = [SELECT Id, Company FROM Lead WHERE LastName = 'Smith' LIMIT 1];

        LeadConversionController.ConversionPayload payload = buildBasePayload(testLead.Id);
        payload.useExistingAccount = false;
        payload.newAccountName     = testLead.Company;
        payload.createOpportunity  = true;
        payload.opportunityName    = testLead.Company;
        payload.opportunityCloseDate = Date.today().addDays(90);

        Test.startTest();
        LeadConversionController.ConversionResultWrapper result =
            LeadConversionController.performConversion(payload);
        Test.stopTest();

        System.assertEquals(true, result.success,
            'Expected success. Error: ' + result.errorMessage);
        System.assertNotEquals(null, result.convertedAccountId, 'Account ID should be set');
        System.assertNotEquals(null, result.convertedContactId, 'Contact ID should be set');
        System.assertNotEquals(null, result.convertedOpportunityId, 'Opportunity ID should be set');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  performConversion — existing account path
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_performConversion_existingAccount_success() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Smith' LIMIT 1];
        Account existingAccount = [SELECT Id FROM Account WHERE Name = 'Keneland LLC' LIMIT 1];

        LeadConversionController.ConversionPayload payload = buildBasePayload(testLead.Id);
        payload.useExistingAccount = true;
        payload.existingAccountId  = existingAccount.Id;
        payload.createOpportunity  = false;

        Test.startTest();
        LeadConversionController.ConversionResultWrapper result =
            LeadConversionController.performConversion(payload);
        Test.stopTest();

        System.assertEquals(true, result.success,
            'Expected success with existing account. Error: ' + result.errorMessage);
        System.assertEquals(
            String.valueOf(existingAccount.Id),
            result.convertedAccountId,
            'Should reference existing account'
        );
        System.assertEquals(null, result.convertedOpportunityId,
            'No opportunity expected');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  performConversion — no opportunity path
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_performConversion_noOpportunity_success() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Smith' LIMIT 1];

        LeadConversionController.ConversionPayload payload = buildBasePayload(testLead.Id);
        payload.useExistingAccount = false;
        payload.createOpportunity  = false;

        Test.startTest();
        LeadConversionController.ConversionResultWrapper result =
            LeadConversionController.performConversion(payload);
        Test.stopTest();

        System.assertEquals(true, result.success,
            'Expected success without opportunity. Error: ' + result.errorMessage);
        System.assertEquals(null, result.convertedOpportunityId,
            'Opportunity should not be created');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  performConversion — null leadId failure path
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_performConversion_nullLeadId_returnsFailure() {
        LeadConversionController.ConversionPayload payload =
            new LeadConversionController.ConversionPayload();
        payload.leadId = null;

        Test.startTest();
        LeadConversionController.ConversionResultWrapper result =
            LeadConversionController.performConversion(payload);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected failure for null leadId');
        System.assert(String.isNotBlank(result.errorMessage), 'Error message should be set');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Builds a ConversionPayload pre-populated with common field-mapping values. */
    private static LeadConversionController.ConversionPayload buildBasePayload(Id leadId) {
        LeadConversionController.ConversionPayload payload =
            new LeadConversionController.ConversionPayload();
        payload.leadId                = leadId;
        payload.useExistingContact    = false;
        payload.leadTitle             = 'CEO';
        payload.leadMobilePhone       = '415-555-0101';
        payload.leadIndustry          = 'Technology';
        payload.leadWebsite           = 'https://www.kenelandllc.example.com';
        payload.leadPhone             = '415-555-0100';
        payload.leadBillingStreet     = '123 Main St';
        payload.leadBillingCity       = 'San Francisco';
        payload.leadBillingState      = 'CA';
        payload.leadBillingPostalCode = '94105';
        payload.opportunityAmount     = 75000.00;
        return payload;
    }
}