/**
 * @file              TestDataFactory.cls
 * @description       Centralised test data factory for the Partner Registration
 *                    Automation project. Provides builder methods for all SObjects
 *                    used in unit tests. Single-source-of-truth for test record
 *                    creation — prevents inline DML duplication across test classes.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             PartnerRegistrationAutomation
 *
 * @dependencies      (none — leaf utility)
 * @calledBy          DealRegistrationHandlerTest
 * @testClass         (utility used by test classes; no separate test class required)
 *
 * @see               LLD - Sr Developer creates combined technical design (draft)
 */

/**
 * Factory utility for creating and inserting test SObject records.
 *
 * Responsibilities:
 *   - Provide builder methods for Account, Contact, and Deal_Registration__c.
 *   - Each method inserts the record and returns it with a populated Id.
 *   - Bulk factory methods accept a count and return a List of inserted records.
 *
 * Usage: call factory methods from @TestSetup or individual test methods.
 * Never inline DML in test classes when a factory method covers the use case.
 */
@isTest
public class TestDataFactory {

    /**
     * Creates and inserts a single Account record.
     *
     * @param name  Display name for the Account.
     * @return      Inserted Account with populated Id.
     *
     * @calledBy  DealRegistrationHandlerTest
     * @testMethods (utility — exercised indirectly by all tests using Account)
     */
    public static Account createAccount(String name) {
        Account acct = new Account(
            Name     = name,
            Industry = 'Technology'
        );
        insert acct;
        return acct;
    }

    /**
     * Creates and inserts a single Contact associated with the given Account.
     *
     * @param lastName   Last name of the Contact.
     * @param accountId  Id of the parent Account.
     * @return           Inserted Contact with populated Id.
     *
     * @calledBy  DealRegistrationHandlerTest
     * @testMethods (utility — exercised indirectly by contact-mapping tests)
     */
    public static Contact createContact(String lastName, Id accountId) {
        Contact ct = new Contact(
            LastName  = lastName,
            AccountId = accountId
        );
        insert ct;
        return ct;
    }

    /**
     * Creates and inserts a single Deal_Registration__c record.
     * Triggers DealRegistrationTrigger (after insert), which auto-creates a
     * linked Opportunity. Callers should reload the returned record with SOQL
     * to read the trigger-populated Opportunity__c field.
     *
     * @param name       Name of the Deal Registration.
     * @param accountId  Id of the partner Account (Partner_Account__c).
     * @return           Inserted Deal_Registration__c with populated Id.
     *
     * @calledBy  DealRegistrationHandlerTest
     * @testMethods test_processAfterInsert_singleRecord_createsLinkedOpportunity,
     *              test_processAfterUpdate_notApproved_syncsFields,
     *              test_processAfterUpdate_approved_doesNotSync
     */
    public static Deal_Registration__c createDealRegistration(String name, Id accountId) {
        Deal_Registration__c dr = new Deal_Registration__c(
            Name                    = name,
            Partner_Account__c      = accountId,
            Status__c               = 'Submitted',
            Estimated_Deal_Value__c = 50000,
            Projected_Close_Date__c = Date.today().addDays(30),
            Description__c          = 'Test deal registration created by TestDataFactory.'
        );
        insert dr;
        return dr;
    }

    /**
     * Creates and inserts a bulk list of Deal_Registration__c records.
     * Triggers DealRegistrationTrigger (after insert) once for the entire batch.
     *
     * @param count      Number of records to create. Must be &gt; 0.
     * @param accountId  Id of the partner Account shared across all records.
     * @return           List of inserted Deal_Registration__c records.
     *
     * @calledBy  DealRegistrationHandlerTest
     * @testMethods test_processAfterInsert_bulk_createsOpportunitiesForAllRecords
     */
    public static List<Deal_Registration__c> createDealRegistrations(Integer count, Id accountId) {
        List<Deal_Registration__c> drs = new List<Deal_Registration__c>();
        for (Integer i = 0; i < count; i++) {
            drs.add(new Deal_Registration__c(
                Name                    = 'Bulk DR ' + i,
                Partner_Account__c      = accountId,
                Status__c               = 'Submitted',
                Estimated_Deal_Value__c = 10000 + i,
                Projected_Close_Date__c = Date.today().addDays(30)
            ));
        }
        insert drs;
        return drs;
    }
}
