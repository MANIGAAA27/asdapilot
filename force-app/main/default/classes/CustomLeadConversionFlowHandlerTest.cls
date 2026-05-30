/**
 * @file        CustomLeadConversionFlowHandlerTest.cls
 * @description Tests CustomLeadConversionFlowHandler — covers eligibility
 *              validation, full conversion with new records, conversion using an
 *              existing Account, conversion without an Opportunity, and error
 *              handling for blank Lead Id input.
 * @testFor     CustomLeadConversionFlowHandler
 * @coverage    Target ≥ 90%.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-05-30
 * @lastModified 2026-05-30
 * @group       LeadManagement
 *
 * @dependencies CustomLeadConversionFlowHandler, TestDataFactory
 * @calledBy    (none in this changeset)
 */
@isTest
private class CustomLeadConversionFlowHandlerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // handleLeadConversion — guard / eligibility checks
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_handleLeadConversion_flowLaunchedSuccessfully() {
        Lead testLead = TestDataFactory.createLead('Flow Test Lead');

        Test.startTest();
        Boolean result = CustomLeadConversionFlowHandler.handleLeadConversion(testLead.Id);
        Test.stopTest();

        System.assertEquals(true, result, 'handleLeadConversion should return true for a non-converted Lead');
    }

    @isTest
    static void test_handleLeadConversion_leadAlreadyConverted() {
        Lead convertedLead = TestDataFactory.createConvertedLead('Already Converted Lead');

        Test.startTest();
        Boolean result = CustomLeadConversionFlowHandler.handleLeadConversion(convertedLead.Id);
        Test.stopTest();

        System.assertEquals(false, result, 'handleLeadConversion should return false for an already-converted Lead');
    }

    @isTest
    static void test_handleLeadConversion_blankId_returnsFalse() {
        Test.startTest();
        Boolean result = CustomLeadConversionFlowHandler.handleLeadConversion('');
        Test.stopTest();

        System.assertEquals(false, result, 'handleLeadConversion should return false for a blank Lead Id');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // convertLead — @InvocableMethod
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_convertLead_newRecords_succeeds() {
        Lead testLead = TestDataFactory.createLead('NewRecords Lead');

        CustomLeadConversionFlowHandler.ConversionRequest req = new CustomLeadConversionFlowHandler.ConversionRequest();
        req.leadId              = testLead.Id;
        req.createOpportunity   = true;
        req.opportunityName     = testLead.Company + ' Opportunity';
        req.opportunityAmount   = 5000;
        req.opportunityCloseDate = Date.today().addDays(90);
        req.accountName         = testLead.Company;
        req.accountIndustry     = 'Technology';
        req.accountWebsite      = 'https://example.com';
        req.accountPhone        = '5555550100';
        req.accountBillingStreet     = '123 Main St';
        req.accountBillingCity       = 'Chicago';
        req.accountBillingState      = 'IL';
        req.accountBillingPostalCode = '60601';

        Test.startTest();
        List<CustomLeadConversionFlowHandler.ConversionResult> results =
            CustomLeadConversionFlowHandler.convertLead(
                new List<CustomLeadConversionFlowHandler.ConversionRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return exactly one result');
        System.assertEquals(true, results[0].isSuccess, 'Conversion with new records should succeed: ' + results[0].errorMessage);
        System.assertNotEquals(null, results[0].convertedAccountId,     'Account should be created');
        System.assertNotEquals(null, results[0].convertedContactId,     'Contact should be created');
        System.assertNotEquals(null, results[0].convertedOpportunityId, 'Opportunity should be created');

        Lead convertedLead = [SELECT IsConverted FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals(true, convertedLead.IsConverted, 'Lead.IsConverted must be true after conversion');
    }

    @isTest
    static void test_convertLead_existingAccount_succeeds() {
        Lead testLead = TestDataFactory.createLead('ExistingAcct Lead');
        Account existingAcct = new Account(Name = 'Existing Corp');
        insert existingAcct;

        CustomLeadConversionFlowHandler.ConversionRequest req = new CustomLeadConversionFlowHandler.ConversionRequest();
        req.leadId            = testLead.Id;
        req.existingAccountId = existingAcct.Id;
        req.createOpportunity = false;

        Test.startTest();
        List<CustomLeadConversionFlowHandler.ConversionResult> results =
            CustomLeadConversionFlowHandler.convertLead(
                new List<CustomLeadConversionFlowHandler.ConversionRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess, 'Conversion with existing Account should succeed: ' + results[0].errorMessage);
        System.assertEquals(existingAcct.Id, results[0].convertedAccountId, 'Should link to the provided existing Account');
        System.assertEquals(null, results[0].convertedOpportunityId, 'No Opportunity should be created when createOpportunity=false');
    }

    @isTest
    static void test_convertLead_noOpportunity_succeeds() {
        Lead testLead = TestDataFactory.createLead('NoOpp Lead');

        CustomLeadConversionFlowHandler.ConversionRequest req = new CustomLeadConversionFlowHandler.ConversionRequest();
        req.leadId            = testLead.Id;
        req.createOpportunity = false;

        Test.startTest();
        List<CustomLeadConversionFlowHandler.ConversionResult> results =
            CustomLeadConversionFlowHandler.convertLead(
                new List<CustomLeadConversionFlowHandler.ConversionRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess, 'Conversion without Opportunity should succeed: ' + results[0].errorMessage);
        System.assertEquals(null, results[0].convertedOpportunityId, 'Opportunity Id should be null when skipped');
    }

    @isTest
    static void test_convertLead_blankLeadId_returnsError() {
        CustomLeadConversionFlowHandler.ConversionRequest req = new CustomLeadConversionFlowHandler.ConversionRequest();
        req.leadId = '';

        Test.startTest();
        List<CustomLeadConversionFlowHandler.ConversionResult> results =
            CustomLeadConversionFlowHandler.convertLead(
                new List<CustomLeadConversionFlowHandler.ConversionRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess, 'Blank leadId should return isSuccess=false');
        System.assertNotEquals(null, results[0].errorMessage, 'An error message should be populated');
    }
}
