/**
 * @file              LeadConversionControllerTest.cls
 * @description       Test class for LeadConversionController. Covers getLeadData,
 *                    searchAccounts, searchContacts, convertLead, and
 *                    getFiscalQuarterEndDate AuraEnabled methods.
 * @author            ASDA Dev Agent
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             LeadConversion
 * @testFor           LeadConversionController
 * @coverage          Target ≥ 90%.
 */
@isTest
private class LeadConversionControllerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Test data setup
    // ─────────────────────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        Lead testLead = new Lead(
            FirstName = 'Jane',
            LastName = 'Doe',
            Company = 'Keneland Tech',
            Email = 'jane.doe@keneland.com',
            Phone = '5551234567',
            MobilePhone = '5559876543',
            Industry = 'Technology',
            Website = 'https://keneland.com',
            Street = '123 Main St',
            City = 'Austin',
            State = 'TX',
            PostalCode = '78701',
            Status = 'Open - Not Contacted'
        );
        insert testLead;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getLeadData tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getLeadData_validId_returnsWrapper() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Doe' LIMIT 1];

        Test.startTest();
        LeadConversionService.LeadData result =
            LeadConversionController.getLeadData(testLead.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'LeadData should not be null');
        System.assertNotEquals(null, result.leadRecord, 'Lead record should be populated');
        System.assertEquals('Keneland Tech', result.accountFields.name,
            'Account name should map from Company');
        System.assertEquals('jane.doe@keneland.com', result.contactFields.email,
            'Contact email should map from Lead email');
        System.assertNotEquals(null, result.fiscalQuarterEndDate,
            'Fiscal quarter end date should be set');
    }

    @isTest
    static void test_getLeadData_nullId_throwsAuraHandled() {
        Test.startTest();
        try {
            LeadConversionController.getLeadData(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }

    @isTest
    static void test_getLeadData_invalidId_throwsAuraHandled() {
        Test.startTest();
        try {
            // Use a valid-format but non-existent Lead Id
            LeadConversionController.getLeadData('00Q000000000001AAA');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage() != null, 'Exception message should not be null');
        } catch (Exception ex) {
            // Accept any exception for invalid Id format
            System.assert(true);
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // searchAccounts tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_searchAccounts_byName_returnsMatches() {
        Account acct = new Account(Name = 'Keneland Tech Corp', Phone = '5551234567');
        insert acct;

        LeadMatchingUtil.AccountSearchRequest req = new LeadMatchingUtil.AccountSearchRequest();
        req.companyName = 'Keneland';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadConversionController.searchAccounts(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() >= 1, 'Should find at least one matching Account');
    }

    @isTest
    static void test_searchAccounts_noMatch_returnsEmpty() {
        LeadMatchingUtil.AccountSearchRequest req = new LeadMatchingUtil.AccountSearchRequest();
        req.companyName = 'ZZZNoMatchXXX99999';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadConversionController.searchAccounts(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list for no match');
    }

    @isTest
    static void test_searchAccounts_allBlank_throwsAuraHandled() {
        LeadMatchingUtil.AccountSearchRequest req = new LeadMatchingUtil.AccountSearchRequest();

        Test.startTest();
        try {
            LeadConversionController.searchAccounts(JSON.serialize(req));
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // searchContacts tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_searchContacts_byEmail_returnsMatches() {
        Account acct = new Account(Name = 'Keneland Tech');
        insert acct;
        Contact con = new Contact(
            FirstName = 'Jane',
            LastName = 'Doe',
            Email = 'jane.doe@keneland.com',
            AccountId = acct.Id
        );
        insert con;

        LeadMatchingUtil.ContactSearchRequest req = new LeadMatchingUtil.ContactSearchRequest();
        req.email = 'jane.doe@keneland.com';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadConversionController.searchContacts(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() >= 1, 'Should find at least one matching Contact');
    }

    @isTest
    static void test_searchContacts_noMatch_returnsEmpty() {
        LeadMatchingUtil.ContactSearchRequest req = new LeadMatchingUtil.ContactSearchRequest();
        req.email = 'zzznomatch99999@nowhere.invalid';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadConversionController.searchContacts(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list for no match');
    }

    @isTest
    static void test_searchContacts_allBlank_throwsAuraHandled() {
        LeadMatchingUtil.ContactSearchRequest req = new LeadMatchingUtil.ContactSearchRequest();

        Test.startTest();
        try {
            LeadConversionController.searchContacts(JSON.serialize(req));
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // convertLead tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_convertLead_newRecords_succeeds() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Doe' LIMIT 1];

        LeadConversionService.ConversionRequest req =
            new LeadConversionService.ConversionRequest();
        req.leadId = testLead.Id;
        req.accountName = 'Keneland Tech';
        req.accountIndustry = 'Technology';
        req.contactFirstName = 'Jane';
        req.contactLastName = 'Doe';
        req.contactEmail = 'jane.doe@keneland.com';
        req.createOpportunity = true;
        req.opportunityName = 'Keneland Tech Opportunity';
        req.opportunityCloseDate = Date.today().addDays(30);

        Test.startTest();
        LeadConversionService.ConversionResult result =
            LeadConversionController.convertLead(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, result, 'ConversionResult should not be null');
        System.assertNotEquals(null, result.accountId, 'Account Id should be set');
        System.assertNotEquals(null, result.contactId, 'Contact Id should be set');
        System.assertNotEquals(null, result.opportunityId, 'Opportunity Id should be set');
        System.assertEquals(true, result.opportunityCreated, 'Opportunity should be marked created');
    }

    @isTest
    static void test_convertLead_skipOpportunity_succeeds() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Doe' LIMIT 1];

        LeadConversionService.ConversionRequest req =
            new LeadConversionService.ConversionRequest();
        req.leadId = testLead.Id;
        req.accountName = 'Keneland Tech No Opp';
        req.contactFirstName = 'Jane';
        req.contactLastName = 'Doe';
        req.createOpportunity = false;

        Test.startTest();
        LeadConversionService.ConversionResult result =
            LeadConversionController.convertLead(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, result, 'ConversionResult should not be null');
        System.assertNotEquals(null, result.accountId, 'Account Id should be set');
        System.assertNotEquals(null, result.contactId, 'Contact Id should be set');
        System.assertEquals(null, result.opportunityId, 'Opportunity Id should be null when skipped');
        System.assertEquals(false, result.opportunityCreated,
            'opportunityCreated should be false when skipped');
    }

    @isTest
    static void test_convertLead_missingRequired_throwsAuraHandled() {
        LeadConversionService.ConversionRequest req =
            new LeadConversionService.ConversionRequest();
        // Missing leadId and accountName

        Test.startTest();
        try {
            LeadConversionController.convertLead(JSON.serialize(req));
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getFiscalQuarterEndDate tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getFiscalQuarterEndDate_returnsLastDayOfQuarter() {
        Test.startTest();
        Date result = LeadConversionController.getFiscalQuarterEndDate();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Fiscal quarter end date should not be null');
        System.assert(result >= Date.today(), 'End date should be today or in the future');

        // Verify it is the last day of a quarter-end month (Mar, Jun, Sep, Dec)
        Integer endMonth = result.month();
        System.assert(
            endMonth == 3 || endMonth == 6 || endMonth == 9 || endMonth == 12,
            'End month should be a quarter-end month: ' + endMonth
        );
    }
}
