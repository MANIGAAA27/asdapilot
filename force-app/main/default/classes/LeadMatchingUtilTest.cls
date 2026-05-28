/**
 * @file              LeadMatchingUtilTest.cls
 * @description       Test class for LeadMatchingUtil. Covers findMatchingAccounts
 *                    and findMatchingContacts with positive, negative, and error paths.
 * @author            ASDA Dev Agent
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             LeadConversion
 * @testFor           LeadMatchingUtil
 * @coverage          Target ≥ 90%.
 */
@isTest
private class LeadMatchingUtilTest {

    @TestSetup
    static void makeData() {
        Account acct = new Account(
            Name = 'Matching Corp',
            Phone = '5551112222',
            Website = 'https://matchingcorp.com',
            Industry = 'Technology',
            BillingCity = 'Houston'
        );
        insert acct;

        Contact con = new Contact(
            FirstName = 'Alice',
            LastName = 'Matching',
            Email = 'alice@matchingcorp.com',
            MobilePhone = '5553334444',
            Phone = '5555556666',
            AccountId = acct.Id,
            Title = 'VP Sales'
        );
        insert con;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // findMatchingAccounts tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_findMatchingAccounts_byName_returnsMatches() {
        LeadMatchingUtil.AccountSearchRequest req =
            new LeadMatchingUtil.AccountSearchRequest();
        req.companyName = 'Matching Corp';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadMatchingUtil.findMatchingAccounts(req);
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should find at least one Account by name');
        System.assertEquals('Account', results[0].objectType, 'Object type should be Account');
        System.assertNotEquals(null, results[0].recordId, 'Record Id should be set');
        System.assertNotEquals(null, results[0].matchedOn, 'MatchedOn should be set');
    }

    @isTest
    static void test_findMatchingAccounts_byPhone_returnsMatches() {
        LeadMatchingUtil.AccountSearchRequest req =
            new LeadMatchingUtil.AccountSearchRequest();
        req.phone = '5551112222';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadMatchingUtil.findMatchingAccounts(req);
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should find at least one Account by phone');
    }

    @isTest
    static void test_findMatchingAccounts_byWebsite_returnsMatches() {
        LeadMatchingUtil.AccountSearchRequest req =
            new LeadMatchingUtil.AccountSearchRequest();
        req.website = 'https://matchingcorp.com';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadMatchingUtil.findMatchingAccounts(req);
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should find at least one Account by website');
    }

    @isTest
    static void test_findMatchingAccounts_noMatch_returnsEmpty() {
        LeadMatchingUtil.AccountSearchRequest req =
            new LeadMatchingUtil.AccountSearchRequest();
        req.companyName = 'ZZZNoMatchXXX99999';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadMatchingUtil.findMatchingAccounts(req);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for no match');
    }

    @isTest
    static void test_findMatchingAccounts_allBlank_throws() {
        LeadMatchingUtil.AccountSearchRequest req =
            new LeadMatchingUtil.AccountSearchRequest();

        Test.startTest();
        try {
            LeadMatchingUtil.findMatchingAccounts(req);
            System.assert(false, 'Expected LeadConversionException');
        } catch (LeadConversionException ex) {
            System.assert(ex.getMessage().contains('At least one Account search criterion'),
                'Exception should mention search criterion requirement');
        }
        Test.stopTest();
    }

    @isTest
    static void test_findMatchingAccounts_nullRequest_throws() {
        Test.startTest();
        try {
            LeadMatchingUtil.findMatchingAccounts(null);
            System.assert(false, 'Expected LeadConversionException');
        } catch (LeadConversionException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // findMatchingContacts tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_findMatchingContacts_byEmail_returnsMatches() {
        LeadMatchingUtil.ContactSearchRequest req =
            new LeadMatchingUtil.ContactSearchRequest();
        req.email = 'alice@matchingcorp.com';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadMatchingUtil.findMatchingContacts(req);
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should find at least one Contact by email');
        System.assertEquals('Contact', results[0].objectType, 'Object type should be Contact');
        System.assertEquals('Email', results[0].matchedOn, 'MatchedOn should be Email');
    }

    @isTest
    static void test_findMatchingContacts_byPhone_returnsMatches() {
        LeadMatchingUtil.ContactSearchRequest req =
            new LeadMatchingUtil.ContactSearchRequest();
        req.phone = '5553334444';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadMatchingUtil.findMatchingContacts(req);
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should find at least one Contact by phone');
    }

    @isTest
    static void test_findMatchingContacts_byLastName_returnsMatches() {
        LeadMatchingUtil.ContactSearchRequest req =
            new LeadMatchingUtil.ContactSearchRequest();
        req.lastName = 'Matching';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadMatchingUtil.findMatchingContacts(req);
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should find at least one Contact by last name');
    }

    @isTest
    static void test_findMatchingContacts_noMatch_returnsEmpty() {
        LeadMatchingUtil.ContactSearchRequest req =
            new LeadMatchingUtil.ContactSearchRequest();
        req.email = 'zzznomatch99999@nowhere.invalid';

        Test.startTest();
        List<LeadMatchingUtil.MatchResult> results =
            LeadMatchingUtil.findMatchingContacts(req);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for no match');
    }

    @isTest
    static void test_findMatchingContacts_allBlank_throws() {
        LeadMatchingUtil.ContactSearchRequest req =
            new LeadMatchingUtil.ContactSearchRequest();

        Test.startTest();
        try {
            LeadMatchingUtil.findMatchingContacts(req);
            System.assert(false, 'Expected LeadConversionException');
        } catch (LeadConversionException ex) {
            System.assert(ex.getMessage().contains('At least one Contact search criterion'),
                'Exception should mention search criterion requirement');
        }
        Test.stopTest();
    }

    @isTest
    static void test_findMatchingContacts_nullRequest_throws() {
        Test.startTest();
        try {
            LeadMatchingUtil.findMatchingContacts(null);
            System.assert(false, 'Expected LeadConversionException');
        } catch (LeadConversionException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }
}
