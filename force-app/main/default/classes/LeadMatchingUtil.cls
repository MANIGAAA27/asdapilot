/**
 * @file              LeadMatchingUtil.cls
 * @description       Utility class providing configurable matching logic for identifying
 *                    existing Account and Contact records that may correspond to a Lead
 *                    being converted. Matching criteria include Company Name, Email,
 *                    Phone, and Website. Enforces FLS via WITH SECURITY_ENFORCED.
 * @author            ASDA Dev Agent
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             LeadConversion
 *
 * @dependencies      LeadConversionException
 * @calledBy          LeadConversionController
 * @testClass         LeadMatchingUtilTest
 *
 * @see               LLD - LWC Lead Conversion (Keneland Technology)
 */
public with sharing class LeadMatchingUtil {

    /** Maximum number of match results returned per search. */
    private static final Integer MAX_RESULTS = 10;

    // ─────────────────────────────────────────────────────────────────────────
    // Request / Result wrappers
    // ─────────────────────────────────────────────────────────────────────────

    /** Search criteria for Account matching. */
    public class AccountSearchRequest {
        @AuraEnabled public String companyName { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String website { get; set; }
    }

    /** Search criteria for Contact matching. */
    public class ContactSearchRequest {
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
    }

    /** A single matching record result returned to the LWC. */
    public class MatchResult {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String recordName { get; set; }
        @AuraEnabled public String objectType { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String matchedOn { get; set; }
        @AuraEnabled public String additionalInfo { get; set; }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public matching methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Finds existing Account records matching the supplied search criteria.
     * Matches on Company Name (LIKE), Phone (exact), and Website (exact).
     *
     * @param  req   AccountSearchRequest with at least one non-blank criterion.
     * @return       List of MatchResult (max 10). Empty list when no matches found.
     * @throws       LeadConversionException when all criteria are blank.
     *
     * @calledBy    LeadConversionController.searchAccounts
     * @testMethods test_findMatchingAccounts_byName_returnsMatches,
     *              test_findMatchingAccounts_byPhone_returnsMatches,
     *              test_findMatchingAccounts_noMatch_returnsEmpty,
     *              test_findMatchingAccounts_allBlank_throws
     */
    public static List<MatchResult> findMatchingAccounts(AccountSearchRequest req) {
        if (req == null
                || (String.isBlank(req.companyName)
                    && String.isBlank(req.phone)
                    && String.isBlank(req.website))) {
            throw new LeadConversionException(
                'At least one Account search criterion is required.');
        }

        String nameFilter = String.isBlank(req.companyName)
            ? null : '%' + String.escapeSingleQuotes(req.companyName.trim()) + '%';
        String phoneFilter = String.isBlank(req.phone)
            ? null : req.phone.trim();
        String websiteFilter = String.isBlank(req.website)
            ? null : req.website.trim();

        List<Account> accounts = [
            SELECT Id, Name, Phone, Website, Owner.Name, Industry, BillingCity
            FROM Account
            WHERE (Name LIKE :nameFilter
                   OR Phone = :phoneFilter
                   OR Website = :websiteFilter)
            WITH SECURITY_ENFORCED
            ORDER BY Name
            LIMIT :MAX_RESULTS
        ];

        List<MatchResult> results = new List<MatchResult>();
        for (Account acct : accounts) {
            MatchResult mr = new MatchResult();
            mr.recordId = acct.Id;
            mr.recordName = acct.Name;
            mr.objectType = 'Account';
            mr.ownerName = acct.Owner != null ? acct.Owner.Name : '';
            mr.matchedOn = determineAccountMatchReason(acct, req);
            mr.additionalInfo = buildAccountAdditionalInfo(acct);
            results.add(mr);
        }
        return results;
    }

    /**
     * Finds existing Contact records matching the supplied search criteria.
     * Matches on Email (exact), Phone (exact), and Name (LIKE).
     *
     * @param  req   ContactSearchRequest with at least one non-blank criterion.
     * @return       List of MatchResult (max 10). Empty list when no matches found.
     * @throws       LeadConversionException when all criteria are blank.
     *
     * @calledBy    LeadConversionController.searchContacts
     * @testMethods test_findMatchingContacts_byEmail_returnsMatches,
     *              test_findMatchingContacts_byPhone_returnsMatches,
     *              test_findMatchingContacts_noMatch_returnsEmpty,
     *              test_findMatchingContacts_allBlank_throws
     */
    public static List<MatchResult> findMatchingContacts(ContactSearchRequest req) {
        if (req == null
                || (String.isBlank(req.email)
                    && String.isBlank(req.phone)
                    && String.isBlank(req.lastName))) {
            throw new LeadConversionException(
                'At least one Contact search criterion is required.');
        }

        String emailFilter = String.isBlank(req.email) ? null : req.email.trim();
        String phoneFilter = String.isBlank(req.phone) ? null : req.phone.trim();
        String lastNameFilter = String.isBlank(req.lastName)
            ? null : '%' + String.escapeSingleQuotes(req.lastName.trim()) + '%';

        List<Contact> contacts = [
            SELECT Id, Name, FirstName, LastName, Email, MobilePhone,
                   Phone, Account.Name, Owner.Name, Title
            FROM Contact
            WHERE (Email = :emailFilter
                   OR MobilePhone = :phoneFilter
                   OR Phone = :phoneFilter
                   OR LastName LIKE :lastNameFilter)
            WITH SECURITY_ENFORCED
            ORDER BY LastName, FirstName
            LIMIT :MAX_RESULTS
        ];

        List<MatchResult> results = new List<MatchResult>();
        for (Contact con : contacts) {
            MatchResult mr = new MatchResult();
            mr.recordId = con.Id;
            mr.recordName = con.Name;
            mr.objectType = 'Contact';
            mr.ownerName = con.Owner != null ? con.Owner.Name : '';
            mr.matchedOn = determineContactMatchReason(con, req);
            mr.additionalInfo = buildContactAdditionalInfo(con);
            results.add(mr);
        }
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Determines the primary reason an Account was matched. */
    private static String determineAccountMatchReason(
            Account acct, AccountSearchRequest req) {
        if (!String.isBlank(req.companyName)
                && acct.Name != null
                && acct.Name.containsIgnoreCase(req.companyName.trim())) {
            return 'Company Name';
        }
        if (!String.isBlank(req.phone) && req.phone.trim() == acct.Phone) {
            return 'Phone';
        }
        if (!String.isBlank(req.website) && req.website.trim() == acct.Website) {
            return 'Website';
        }
        return 'Multiple criteria';
    }

    /** Determines the primary reason a Contact was matched. */
    private static String determineContactMatchReason(
            Contact con, ContactSearchRequest req) {
        if (!String.isBlank(req.email) && req.email.trim() == con.Email) {
            return 'Email';
        }
        if (!String.isBlank(req.phone)
                && (req.phone.trim() == con.MobilePhone
                    || req.phone.trim() == con.Phone)) {
            return 'Phone';
        }
        if (!String.isBlank(req.lastName)
                && con.LastName != null
                && con.LastName.containsIgnoreCase(req.lastName.trim())) {
            return 'Last Name';
        }
        return 'Multiple criteria';
    }

    /** Builds a display string with key Account details. */
    private static String buildAccountAdditionalInfo(Account acct) {
        List<String> parts = new List<String>();
        if (!String.isBlank(acct.Industry)) {
            parts.add('Industry: ' + acct.Industry);
        }
        if (!String.isBlank(acct.BillingCity)) {
            parts.add('City: ' + acct.BillingCity);
        }
        if (!String.isBlank(acct.Phone)) {
            parts.add('Phone: ' + acct.Phone);
        }
        return String.join(parts, ' | ');
    }

    /** Builds a display string with key Contact details. */
    private static String buildContactAdditionalInfo(Contact con) {
        List<String> parts = new List<String>();
        if (!String.isBlank(con.Title)) {
            parts.add('Title: ' + con.Title);
        }
        if (con.Account != null && !String.isBlank(con.Account.Name)) {
            parts.add('Account: ' + con.Account.Name);
        }
        if (!String.isBlank(con.Email)) {
            parts.add('Email: ' + con.Email);
        }
        return String.join(parts, ' | ');
    }
}
