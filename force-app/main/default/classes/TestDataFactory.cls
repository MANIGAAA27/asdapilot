/**
 * @file              TestDataFactory.cls
 * @description       Centralised test-data factory for Case Summary Transfer 1.0.
 *                    All @isTest classes in this package must call these methods
 *                    instead of duplicating inline insert statements. Keeps
 *                    schema changes to a single place.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-25
 * @lastModified      2026-05-25
 * @group             CaseSummaryTransfer
 *
 * @dependencies      (none in this changeset)
 * @calledBy          CaseDataAggregationServiceTest, CaseTransferPayloadBuilderTest,
 *                    LLMCalloutServiceTest, CaseSummaryPersistenceServiceTest,
 *                    CaseSummaryTransferServiceTest, CaseSummaryTransferQueueableTest,
 *                    CaseTriggerHandlerTest, CaseSummaryControllerTest
 * @testClass         (this IS the test factory — no separate test class required)
 *
 * @see               LLD-Case Summary Transfer 1.0
 */
@isTest
public class TestDataFactory {

    /**
     * Creates and inserts a single Account with the given name.
     *
     * @param  name  Display name for the Account.
     * @return Inserted Account with Id populated.
     */
    public static Account createAccount(String name) {
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }

    /**
     * Creates and inserts a single Contact linked to the given Account.
     *
     * @param  firstName  Contact first name.
     * @param  lastName   Contact last name.
     * @param  accountId  Id of the parent Account.
     * @return Inserted Contact with Id populated.
     */
    public static Contact createContact(String firstName, String lastName, Id accountId) {
        Contact con = new Contact(
            FirstName = firstName,
            LastName  = lastName,
            AccountId = accountId
        );
        insert con;
        return con;
    }

    /**
     * Creates and inserts a single Case.
     *
     * @param  subject    Case subject line.
     * @param  accountId  Id of the related Account (may be null).
     * @param  contactId  Id of the related Contact (may be null).
     * @return Inserted Case with Id populated.
     */
    public static Case createCase(String subject, Id accountId, Id contactId) {
        Case c = new Case(
            Subject   = subject,
            AccountId = accountId,
            ContactId = contactId,
            Status    = 'New',
            Priority  = 'Medium'
        );
        insert c;
        return c;
    }

    /**
     * Creates and inserts N bare Cases attached to the given Account.
     * Used for bulk-path testing (200+ records).
     *
     * @param  count      Number of cases to create.
     * @param  accountId  Id of the parent Account.
     * @return Inserted List<Case> with Ids populated.
     */
    public static List<Case> createCases(Integer count, Id accountId) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(new Case(
                Subject   = 'Bulk Test Case ' + i,
                AccountId = accountId,
                Status    = 'New',
                Priority  = 'Medium'
            ));
        }
        insert cases;
        return cases;
    }

    /**
     * Creates and inserts a successful Case_Transfer_Summary__c record.
     *
     * @param  caseId       Id of the parent Case.
     * @param  summaryText  The summary body text.
     * @return Inserted Case_Transfer_Summary__c with Id populated.
     */
    public static Case_Transfer_Summary__c createCaseTransferSummary(Id caseId, String summaryText) {
        Case_Transfer_Summary__c summary = new Case_Transfer_Summary__c(
            Case__c              = caseId,
            Summary_Text__c      = summaryText,
            Transfer_Timestamp__c = System.now(),
            Model_Name__c        = 'gpt-4',
            Model_Version__c     = '1.0',
            Generation_Status__c = 'Success'
        );
        insert summary;
        return summary;
    }
}