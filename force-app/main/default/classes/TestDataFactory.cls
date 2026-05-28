/**
 * @file              TestDataFactory.cls
 * @description       Centralised test data factory for the Partner Registration
 *                    Automation project. Provides builder-style methods for
 *                    creating SObject records used across all test classes.
 *                    All methods insert records and return the inserted SObject
 *                    so callers can chain or inspect the assigned Id.
 *
 *                    Adding a new required field to any object requires a
 *                    change in exactly ONE place — the relevant factory method
 *                    here — rather than in every test class.
 *
 * @author            ASDA Dev Agent
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             PartnerRegistrationAutomation
 *
 * @dependencies      (none — base SObjects only)
 * @calledBy          DealRegistrationHandlerTest
 * @testClass         (this IS the test support class — no paired test class required)
 *
 * @see               LLD - Partner Registration Automation (Feature: Partner Registration Automation)
 */
@isTest
public class TestDataFactory {

    // ─────────────────────────────────────────────────────────────────────────
    // Account
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a single Account record.
     *
     * @param  name  The Account Name value.
     * @return The inserted Account with Id populated.
     */
    public static Account createAccount(String name) {
        Account acct = new Account(
            Name = name,
            Industry = 'Technology'
        );
        insert acct;
        return acct;
    }

    /**
     * Creates and inserts a list of Account records.
     *
     * @param  count  Number of Account records to create.
     * @return List of inserted Accounts with Ids populated.
     */
    public static List<Account> createAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                Industry = 'Technology'
            ));
        }
        insert accounts;
        return accounts;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Contact
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a single Contact record linked to the given Account.
     *
     * @param  accountId  The Id of the parent Account.
     * @param  lastName   The Contact Last Name value.
     * @return The inserted Contact with Id populated.
     */
    public static Contact createContact(Id accountId, String lastName) {
        Contact con = new Contact(
            LastName = lastName,
            AccountId = accountId
        );
        insert con;
        return con;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Deal Registration
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a single Deal_Registration__c record with all
     * mappable fields populated. The trigger will fire and create a linked
     * Opportunity automatically.
     *
     * @param  name       The Deal Registration Name.
     * @param  accountId  The Id of the Partner Account (Account lookup).
     * @param  contactId  The Id of the Primary Partner Contact (Contact lookup).
     * @return The inserted Deal_Registration__c with Id populated.
     *         Note: Linked_Opportunity__c is populated by the trigger after
     *         insert — re-query if you need the linked Opportunity Id.
     */
    public static Deal_Registration__c createDealRegistration(
        String name,
        Id accountId,
        Id contactId
    ) {
        Deal_Registration__c dealReg = new Deal_Registration__c(
            Name = name,
            Partner_Account__c = accountId,
            Primary_Partner_Contact__c = contactId,
            Estimated_Deal_Value__c = 50000,
            Projected_Close_Date__c = Date.today().addDays(90),
            Deal_Description__c = 'Test deal description for ' + name,
            Status__c = 'Submitted'
        );
        insert dealReg;
        return dealReg;
    }

    /**
     * Creates and inserts a single Deal_Registration__c record with minimal
     * required fields only. Useful for negative / edge-case tests.
     *
     * @param  name  The Deal Registration Name.
     * @return The inserted Deal_Registration__c with Id populated.
     */
    public static Deal_Registration__c createMinimalDealRegistration(String name) {
        Deal_Registration__c dealReg = new Deal_Registration__c(
            Name = name,
            Status__c = 'Submitted'
        );
        insert dealReg;
        return dealReg;
    }

    /**
     * Creates and inserts a list of Deal_Registration__c records for bulk
     * testing. Each record is given a unique name suffix.
     *
     * @param  count      Number of records to create.
     * @param  accountId  The Id of the Partner Account to assign to each record.
     * @return List of inserted Deal_Registration__c records with Ids populated.
     */
    public static List<Deal_Registration__c> createDealRegistrations(
        Integer count,
        Id accountId
    ) {
        List<Deal_Registration__c> dealRegs = new List<Deal_Registration__c>();
        for (Integer i = 0; i < count; i++) {
            dealRegs.add(new Deal_Registration__c(
                Name = 'Bulk Deal Reg ' + i,
                Partner_Account__c = accountId,
                Estimated_Deal_Value__c = 10000 + (i * 1000),
                Projected_Close_Date__c = Date.today().addDays(90 + i),
                Deal_Description__c = 'Bulk test description ' + i,
                Status__c = 'Submitted'
            ));
        }
        insert dealRegs;
        return dealRegs;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Opportunity
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a standalone Opportunity record (not linked to a
     * Deal Registration). Useful for update-path tests where a pre-existing
     * Opportunity is needed.
     *
     * @param  name       The Opportunity Name.
     * @param  accountId  The Id of the Account.
     * @return The inserted Opportunity with Id populated.
     */
    public static Opportunity createOpportunity(String name, Id accountId) {
        Opportunity opp = new Opportunity(
            Name = name,
            AccountId = accountId,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(90)
        );
        insert opp;
        return opp;
    }
}
