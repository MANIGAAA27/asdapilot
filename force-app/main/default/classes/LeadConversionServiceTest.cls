/**
 * @file              LeadConversionServiceTest.cls
 * @description       Test class for LeadConversionService. Covers getLeadData,
 *                    convertLead (new records, existing records, skip opportunity),
 *                    getFiscalQuarterEndDate, and validation error paths.
 * @author            ASDA Dev Agent
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             LeadConversion
 * @testFor           LeadConversionService
 * @coverage          Target ≥ 90%.
 */
@isTest
private class LeadConversionServiceTest {

    @TestSetup
    static void makeData() {
        Lead testLead = new Lead(
            FirstName = 'John',
            LastName = 'Smith',
            Company = 'Acme Corp',
            Email = 'john.smith@acme.com',
            Phone = '5550001111',
            MobilePhone = '5550002222',
            Industry = 'Technology',
            Website = 'https://acme.com',
            Street = '456 Oak Ave',
            City = 'Dallas',
            State = 'TX',
            PostalCode = '75201',
            Status = 'Open - Not Contacted'
        );
        insert testLead;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getLeadData tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getLeadData_validId_returnsWrapper() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Smith' LIMIT 1];

        Test.startTest();
        LeadConversionService.LeadData result =
            LeadConversionService.getLeadData(testLead.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'LeadData should not be null');
        System.assertEquals('Acme Corp', result.accountFields.name,
            'Account name should map from Company');
        System.assertEquals('john.smith@acme.com', result.contactFields.email,
            'Contact email should map from Lead email');
        System.assertEquals('Acme Corp', result.opportunityFields.name,
            'Opportunity name should default to Company');
        System.assertNotEquals(null, result.fiscalQuarterEndDate,
            'Fiscal quarter end date should be populated');
    }

    @isTest
    static void test_getLeadData_nullId_throws() {
        Test.startTest();
        try {
            LeadConversionService.getLeadData(null);
            System.assert(false, 'Expected LeadConversionException');
        } catch (LeadConversionException ex) {
            System.assertEquals('Lead Id is required.', ex.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void test_getLeadData_convertedLead_throws() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Smith' LIMIT 1];

        // Convert the lead first using a minimal conversion
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setDoNotCreateOpportunity(true);
        LeadStatus convertedStatus = [
            SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1
        ];
        lc.setConvertedStatus(convertedStatus.MasterLabel);
        Database.convertLead(lc);

        Test.startTest();
        try {
            LeadConversionService.getLeadData(testLead.Id);
            System.assert(false, 'Expected LeadConversionException for converted lead');
        } catch (LeadConversionException ex) {
            System.assert(ex.getMessage().contains('already been converted'),
                'Exception should mention already converted');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // convertLead tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_convertLead_newRecords_succeeds() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Smith' LIMIT 1];

        LeadConversionService.ConversionRequest req =
            new LeadConversionService.ConversionRequest();
        req.leadId = testLead.Id;
        req.accountName = 'Acme Corp';
        req.accountIndustry = 'Technology';
        req.contactFirstName = 'John';
        req.contactLastName = 'Smith';
        req.contactEmail = 'john.smith@acme.com';
        req.createOpportunity = true;
        req.opportunityName = 'Acme Corp Deal';
        req.opportunityCloseDate = Date.today().addDays(90);

        Test.startTest();
        LeadConversionService.ConversionResult result =
            LeadConversionService.convertLead(req);
        Test.stopTest();

        System.assertNotEquals(null, result.accountId, 'Account Id should be set');
        System.assertNotEquals(null, result.contactId, 'Contact Id should be set');
        System.assertNotEquals(null, result.opportunityId, 'Opportunity Id should be set');
        System.assertEquals(true, result.opportunityCreated,
            'opportunityCreated should be true');
        System.assertNotEquals(null, result.successMessage,
            'Success message should be populated');

        // Verify Lead is now converted
        Lead convertedLead = [SELECT IsConverted FROM Lead WHERE Id = :testLead.Id LIMIT 1];
        System.assertEquals(true, convertedLead.IsConverted, 'Lead should be marked converted');
    }

    @isTest
    static void test_convertLead_existingAccount_succeeds() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Smith' LIMIT 1];
        Account existingAcct = new Account(Name = 'Existing Acme Corp');
        insert existingAcct;

        LeadConversionService.ConversionRequest req =
            new LeadConversionService.ConversionRequest();
        req.leadId = testLead.Id;
        req.existingAccountId = existingAcct.Id;
        req.contactFirstName = 'John';
        req.contactLastName = 'Smith';
        req.createOpportunity = false;

        Test.startTest();
        LeadConversionService.ConversionResult result =
            LeadConversionService.convertLead(req);
        Test.stopTest();

        System.assertEquals(existingAcct.Id, result.accountId,
            'Should use existing Account Id');
        System.assertNotEquals(null, result.contactId, 'Contact Id should be set');
    }

    @isTest
    static void test_convertLead_skipOpportunity_succeeds() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Smith' LIMIT 1];

        LeadConversionService.ConversionRequest req =
            new LeadConversionService.ConversionRequest();
        req.leadId = testLead.Id;
        req.accountName = 'Acme Corp Skip Opp';
        req.contactFirstName = 'John';
        req.contactLastName = 'Smith';
        req.createOpportunity = false;

        Test.startTest();
        LeadConversionService.ConversionResult result =
            LeadConversionService.convertLead(req);
        Test.stopTest();

        System.assertEquals(null, result.opportunityId,
            'Opportunity Id should be null when skipped');
        System.assertEquals(false, result.opportunityCreated,
            'opportunityCreated should be false');
    }

    @isTest
    static void test_convertLead_missingLeadId_throws() {
        LeadConversionService.ConversionRequest req =
            new LeadConversionService.ConversionRequest();
        req.accountName = 'Some Account';
        req.contactLastName = 'Smith';

        Test.startTest();
        try {
            LeadConversionService.convertLead(req);
            System.assert(false, 'Expected LeadConversionException');
        } catch (LeadConversionException ex) {
            System.assert(ex.getMessage().contains('Lead Id is required'),
                'Exception should mention Lead Id');
        }
        Test.stopTest();
    }

    @isTest
    static void test_convertLead_missingAccountName_throws() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Smith' LIMIT 1];

        LeadConversionService.ConversionRequest req =
            new LeadConversionService.ConversionRequest();
        req.leadId = testLead.Id;
        // No accountName and no existingAccountId
        req.contactLastName = 'Smith';

        Test.startTest();
        try {
            LeadConversionService.convertLead(req);
            System.assert(false, 'Expected LeadConversionException');
        } catch (LeadConversionException ex) {
            System.assert(ex.getMessage().contains('Account Name is required'),
                'Exception should mention Account Name');
        }
        Test.stopTest();
    }

    @isTest
    static void test_convertLead_missingContactLastName_throws() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Smith' LIMIT 1];

        LeadConversionService.ConversionRequest req =
            new LeadConversionService.ConversionRequest();
        req.leadId = testLead.Id;
        req.accountName = 'Acme Corp';
        // No contactLastName and no existingContactId

        Test.startTest();
        try {
            LeadConversionService.convertLead(req);
            System.assert(false, 'Expected LeadConversionException');
        } catch (LeadConversionException ex) {
            System.assert(ex.getMessage().contains('Contact Last Name is required'),
                'Exception should mention Contact Last Name');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getFiscalQuarterEndDate tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getFiscalQuarterEndDate_returnsLastDayOfQuarter() {
        Test.startTest();
        Date result = LeadConversionService.getFiscalQuarterEndDate();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        Integer endMonth = result.month();
        System.assert(
            endMonth == 3 || endMonth == 6 || endMonth == 9 || endMonth == 12,
            'End month should be a quarter-end month'
        );
        // Verify it is the last day of that month
        Integer expectedLastDay = Date.daysInMonth(result.year(), endMonth);
        System.assertEquals(expectedLastDay, result.day(),
            'Should be the last day of the quarter-end month');
    }
}
