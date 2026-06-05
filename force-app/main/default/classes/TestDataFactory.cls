/**
 * @file              TestDataFactory.cls
 * @description       Centralised test data factory for the Case Transfer Intelligence feature.
 *                    Provides builder methods for all SObjects used across test classes,
 *                    ensuring a single source of truth for test data setup.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-05
 * @lastModified      2026-06-05
 * @group             CaseTransfer
 *
 * @dependencies      (none — this is a test utility)
 * @calledBy          CaseSummaryControllerTest, CaseSummaryGeneratorQueueableTest,
 *                    CaseSummarySelector, CaseTransferServiceTest, CaseTriggerHandlerTest
 * @testClass         (none — this IS the test utility; it is annotated @isTest)
 *
 * @see               HLD Section 5 — Test Data Strategy
 */
@isTest
public class TestDataFactory {

    /** Creates and inserts a single Case with sensible defaults. */
    public static Case createCase(String subject) {
        Case c = new Case(
            Subject  = subject,
            Status   = 'New',
            Origin   = 'Web',
            Priority = 'Medium'
        );
        insert c;
        return c;
    }

    /**
     * Creates and inserts multiple Cases.
     *
     * @param  count  Number of cases to create.
     * @return List of inserted Case records.
     */
    public static List<Case> createCases(Integer count) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(new Case(
                Subject  = 'Test Case ' + i,
                Status   = 'New',
                Origin   = 'Web',
                Priority = 'Medium'
            ));
        }
        insert cases;
        return cases;
    }

    /**
     * Creates and inserts a CaseTransferSummary__c record for the given case.
     *
     * @param  caseId  Parent Case Id.
     * @param  status  GenerationStatus__c picklist value.
     * @return Inserted CaseTransferSummary__c record.
     */
    public static CaseTransferSummary__c createCaseTransferSummary(Id caseId, String status) {
        CaseTransferSummary__c summary = new CaseTransferSummary__c(
            Case__c                = caseId,
            GenerationStatus__c    = status,
            GenerationTimestamp__c = System.now(),
            GeneratedFor__c        = 'Test Agent'
        );
        if (status == 'Success') {
            summary.SummaryText__c = 'Test summary text.';
        }
        if (status == 'Failed') {
            summary.ErrorMessage__c = 'Test error message.';
        }
        insert summary;
        return summary;
    }

    /**
     * Creates and inserts multiple CaseTransferSummary__c records.
     *
     * @param  caseId  Parent Case Id.
     * @param  count   Number of summaries to create (all with Success status).
     * @return List of inserted records.
     */
    public static List<CaseTransferSummary__c> createCaseTransferSummaries(Id caseId, Integer count) {
        List<CaseTransferSummary__c> summaries = new List<CaseTransferSummary__c>();
        for (Integer i = 0; i < count; i++) {
            summaries.add(new CaseTransferSummary__c(
                Case__c                = caseId,
                GenerationStatus__c    = 'Success',
                GenerationTimestamp__c = System.now().addMinutes(-i),
                GeneratedFor__c        = 'Agent ' + i,
                SummaryText__c         = 'Summary ' + i
            ));
        }
        insert summaries;
        return summaries;
    }

    /**
     * Creates and inserts a standard User with System Administrator profile.
     * Use sparingly — creating users requires mixed DML workarounds.
     *
     * @param  username  Unique username for the test user.
     * @return Inserted User record.
     */
    public static User createAdminUser(String username) {
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            FirstName          = 'Test',
            LastName           = 'Admin',
            Email              = username,
            Username           = username,
            Alias              = 'tadmin',
            TimeZoneSidKey     = 'America/New_York',
            LocaleSidKey       = 'en_US',
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            ProfileId          = adminProfile.Id
        );
        insert u;
        return u;
    }
}
