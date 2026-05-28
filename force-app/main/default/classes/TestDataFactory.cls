/**
 * @file              TestDataFactory.cls
 * @description       Centralised test data factory for the Custom Lead Conversion
 *                    feature. Provides builder methods for Lead, Account, and Contact
 *                    records used across all test classes in this changeset.
 *                    All methods insert the record and return it so callers can chain.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             TestUtilities
 *
 * @dependencies      (none)
 * @calledBy          LeadConversionServiceTest, LeadConversionControllerTest
 * @testClass         (utility — not directly tested; covered by consumers)
 *
 * @see               LLD-001 Custom Lead Conversion (Feature: Custom Lead Conversion)
 */

/**
 * Centralised factory for test SObject records used by the Lead Conversion
 * feature tests.
 *
 * Responsibilities:
 *   - Create and insert Lead records with all conversion-relevant fields.
 *   - Create and insert Account records for "existing account" test paths.
 *   - Create and insert Contact records for "existing contact" test paths.
 *   - Provide bulk variants (createLeads, createAccounts) for governor-limit tests.
 *
 * @testClass (utility — exercised via LeadConversionServiceTest /
 *             LeadConversionControllerTest)
 */
@isTest
public class TestDataFactory {

    // ─────────────────────────────────────────────────────────────────────────
    //  Lead Builders
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a Lead with all fields relevant to the conversion wizard.
     *
     * @param  firstName   Lead.FirstName
     * @param  lastName    Lead.LastName
     * @param  company     Lead.Company (also used as default Opportunity name)
     * @return Inserted Lead record.
     */
    public static Lead createLead(String firstName, String lastName, String company) {
        Lead lead = new Lead(
            FirstName           = firstName,
            LastName            = lastName,
            Company             = company,
            Email               = firstName.toLowerCase() + '.' + lastName.toLowerCase()
                                    + '@' + company.replaceAll('\\s+', '').toLowerCase() + '.example.com',
            Phone               = '415-555-0100',
            MobilePhone         = '415-555-0101',
            Industry            = 'Technology',
            Website             = 'https://www.' + company.replaceAll('\\s+', '').toLowerCase() + '.example.com',
            Title               = 'CEO',
            Street              = '123 Main St',
            City                = 'San Francisco',
            State               = 'CA',
            PostalCode          = '94105',
            Country             = 'USA',
            Status              = 'Open - Not Contacted',
            Conversion_Amount__c = 50000.00
        );
        insert lead;
        return lead;
    }

    /**
     * Creates and inserts a list of Leads for bulk/governor-limit tests.
     *
     * @param  count  Number of Lead records to create.
     * @return List of inserted Lead records.
     */
    public static List<Lead> createLeads(Integer count) {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < count; i++) {
            leads.add(new Lead(
                FirstName    = 'Test',
                LastName     = 'Lead ' + i,
                Company      = 'Bulk Corp ' + i,
                Email        = 'lead' + i + '@bulkcorp.example.com',
                Status       = 'Open - Not Contacted',
                Conversion_Amount__c = 1000.00 * i
            ));
        }
        insert leads;
        return leads;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Account Builders
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts an Account with a given name.
     *
     * @param  name  Account.Name
     * @return Inserted Account record.
     */
    public static Account createAccount(String name) {
        Account acct = new Account(
            Name        = name,
            Industry    = 'Technology',
            Phone       = '415-555-0200',
            Website     = 'https://www.' + name.replaceAll('\\s+', '').toLowerCase() + '.example.com',
            BillingStreet     = '456 Market St',
            BillingCity       = 'San Francisco',
            BillingState      = 'CA',
            BillingPostalCode = '94105'
        );
        insert acct;
        return acct;
    }

    /**
     * Creates and inserts multiple Account records for bulk tests.
     *
     * @param  count  Number of Account records to create.
     * @return List of inserted Account records.
     */
    public static List<Account> createAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Bulk Account ' + i));
        }
        insert accounts;
        return accounts;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Contact Builders
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a Contact associated with the given Account.
     *
     * @param  accountId   Id of the parent Account.
     * @param  firstName   Contact.FirstName
     * @param  lastName    Contact.LastName
     * @param  email       Contact.Email (used for duplicate matching)
     * @return Inserted Contact record.
     */
    public static Contact createContact(
        Id accountId,
        String firstName,
        String lastName,
        String email
    ) {
        Contact con = new Contact(
            AccountId   = accountId,
            FirstName   = firstName,
            LastName    = lastName,
            Email       = email,
            Phone       = '415-555-0300',
            MobilePhone = '415-555-0301',
            Title       = 'VP Sales'
        );
        insert con;
        return con;
    }
}