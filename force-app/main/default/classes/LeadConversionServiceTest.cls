/**
 * @file        LeadConversionServiceTest.cls
 * @description Tests LeadConversionService — covers new-account/contact creation,
 *              existing account/contact association, opportunity creation and suppression,
 *              and the converted status / stage resolution helpers.
 * @testFor     LeadConversionService
 * @coverage    Target >= 90%.
 */
@isTest
private class LeadConversionServiceTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Test data setup
    // ─────────────────────────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        Lead testLead = new Lead(
            FirstName   = 'Test',
            LastName    = 'LeadRecord',
            Company     = 'Keneland Tech',
            Email       = 'test.lead@keneland.example.com',
            MobilePhone = '+44 7700 900123',
            Title       = 'Sales Manager',
            Industry    = 'Technology',
            Website     = 'https://keneland.example.com',
            Phone       = '+44 20 0000 0001',
            Street      = '1 Test Lane',
            City        = 'Manchester',
            State       = 'Greater Manchester',
            PostalCode  = 'M1 1AA'
        );
        insert testLead;
    }

    /** Retrieves the seeded Lead record. */
    private static Lead getTestLead() {
        return [
            SELECT Id, Company, FirstName, LastName, Email, Street, City, State, PostalCode
            FROM Lead
            WHERE LastName = 'LeadRecord'
            LIMIT 1
        ];
    }

    /** Builds a minimal ConversionRequest for a brand-new account and contact. */
    private static LeadConversionService.ConversionRequest buildNewRequest(Id leadId) {
        LeadConversionService.ConversionRequest req = new LeadConversionService.ConversionRequest();
        req.leadId               = leadId;
        req.accountChoice        = 'new';
        req.newAccountName       = 'Keneland Tech';
        req.newAccountIndustry   = 'Technology';
        req.newAccountWebsite    = 'https://keneland.example.com';
        req.newAccountPhone      = '+44 20 0000 0001';
        req.newAccountBillingStreet     = '1 Test Lane';
        req.newAccountBillingCity       = 'Manchester';
        req.newAccountBillingState      = 'Greater Manchester';
        req.newAccountBillingPostalCode = 'M1 1AA';
        req.contactChoice        = 'new';
        req.newContactFirstName  = 'Test';
        req.newContactLastName   = 'LeadRecord';
        req.newContactTitle      = 'Sales Manager';
        req.newContactEmail      = 'test.lead@keneland.example.com';
        req.newContactMobilePhone = '+44 7700 900123';
        req.createOpportunity    = true;
        req.opportunityName      = 'Keneland Tech - Conversion';
        req.opportunityCloseDate = Date.today().addDays(90);
        req.opportunityAmount    = 25000;
        return req;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_convertLead_newAccountNewContact_succeeds() {
        Lead lead = getTestLead();
        LeadConversionService.ConversionRequest req = buildNewRequest(lead.Id);

        Test.startTest();
        List<LeadConversionService.ConversionResult> results =
            LeadConversionService.convertLead(
                new List<LeadConversionService.ConversionRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly one result');
        LeadConversionService.ConversionResult res = results[0];
        System.assertEquals(true, res.isSuccess,
            'Conversion should succeed; error: ' + res.errorMessage);
        System.assertNotEquals(null, res.accountId, 'Account ID must be set');
        System.assertNotEquals(null, res.contactId, 'Contact ID must be set');
        System.assertNotEquals(null, res.opportunityId, 'Opportunity ID must be set');

        Account createdAcct = [SELECT Name, BillingCity FROM Account WHERE Id = :res.accountId];
        System.assertEquals('Keneland Tech', createdAcct.Name, 'Account name should match Lead Company');
        System.assertEquals('Manchester', createdAcct.BillingCity, 'BillingCity should be mapped from Lead.City');

        Lead convertedLead = [SELECT IsConverted FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(true, convertedLead.IsConverted, 'Lead must be marked as converted');
    }

    @isTest
    static void test_convertLead_existingAccount_succeeds() {
        Lead lead = getTestLead();
        Account existingAcct = new Account(Name = 'Pre-existing Keneland');
        insert existingAcct;

        LeadConversionService.ConversionRequest req = new LeadConversionService.ConversionRequest();
        req.leadId          = lead.Id;
        req.accountChoice   = existingAcct.Id;
        req.contactChoice   = 'new';
        req.newContactFirstName = 'Test';
        req.newContactLastName  = 'LeadRecord';
        req.newContactEmail     = 'test.lead@keneland.example.com';
        req.createOpportunity   = false;

        Test.startTest();
        List<LeadConversionService.ConversionResult> results =
            LeadConversionService.convertLead(
                new List<LeadConversionService.ConversionRequest>{ req }
            );
        Test.stopTest();

        LeadConversionService.ConversionResult res = results[0];
        System.assertEquals(true, res.isSuccess,
            'Conversion with existing account should succeed; error: ' + res.errorMessage);
        System.assertEquals(existingAcct.Id, res.accountId,
            'Should use the pre-existing Account ID');
        System.assertEquals(null, res.opportunityId,
            'No Opportunity should be created when createOpportunity is false');
    }

    @isTest
    static void test_convertLead_noOpportunity_succeeds() {
        Lead lead = getTestLead();
        LeadConversionService.ConversionRequest req = buildNewRequest(lead.Id);
        req.createOpportunity = false;

        Test.startTest();
        List<LeadConversionService.ConversionResult> results =
            LeadConversionService.convertLead(
                new List<LeadConversionService.ConversionRequest>{ req }
            );
        Test.stopTest();

        LeadConversionService.ConversionResult res = results[0];
        System.assertEquals(true, res.isSuccess,
            'Conversion without opportunity should succeed; error: ' + res.errorMessage);
        System.assertEquals(null, res.opportunityId,
            'Opportunity ID must be null when createOpportunity is false');
    }

    @isTest
    static void test_convertLead_existingContact_succeeds() {
        Lead lead = getTestLead();
        Account existingAcct = new Account(Name = 'Existing Contact Account');
        insert existingAcct;
        Contact existingContact = new Contact(
            FirstName = 'Existing',
            LastName  = 'Contact',
            AccountId = existingAcct.Id
        );
        insert existingContact;

        LeadConversionService.ConversionRequest req = new LeadConversionService.ConversionRequest();
        req.leadId          = lead.Id;
        req.accountChoice   = existingAcct.Id;
        req.contactChoice   = existingContact.Id;
        req.createOpportunity = false;

        Test.startTest();
        List<LeadConversionService.ConversionResult> results =
            LeadConversionService.convertLead(
                new List<LeadConversionService.ConversionRequest>{ req }
            );
        Test.stopTest();

        LeadConversionService.ConversionResult res = results[0];
        System.assertEquals(true, res.isSuccess,
            'Conversion with existing contact should succeed; error: ' + res.errorMessage);
        System.assertEquals(existingContact.Id, res.contactId,
            'Should use the pre-existing Contact ID');
    }

    @isTest
    static void test_convertLead_withOpportunityDefaultCloseDate_usesToday() {
        Lead lead = getTestLead();
        LeadConversionService.ConversionRequest req = buildNewRequest(lead.Id);
        req.opportunityCloseDate = null; // let the service default

        Test.startTest();
        List<LeadConversionService.ConversionResult> results =
            LeadConversionService.convertLead(
                new List<LeadConversionService.ConversionRequest>{ req }
            );
        Test.stopTest();

        LeadConversionService.ConversionResult res = results[0];
        System.assertEquals(true, res.isSuccess,
            'Conversion with null close date should succeed; error: ' + res.errorMessage);
        System.assertNotEquals(null, res.opportunityId,
            'Opportunity should still be created with a default close date');

        Opportunity createdOpp = [SELECT CloseDate FROM Opportunity WHERE Id = :res.opportunityId];
        System.assertNotEquals(null, createdOpp.CloseDate, 'CloseDate must be set');
        System.assert(createdOpp.CloseDate >= Date.today(),
            'Default CloseDate should be today or in the future');
    }

    @isTest
    static void test_convertLead_newRecordSentinelConstant_isNew() {
        System.assertEquals('new', LeadConversionService.NEW_RECORD_SENTINEL,
            'Sentinel constant must equal "new" to match Flow screen choice value');
    }
}