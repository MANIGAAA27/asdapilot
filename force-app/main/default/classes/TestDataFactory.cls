/**
  @file              TestDataFactory.cls
  @description       Centralised test data factory for the Case Transfer Intelligence feature.
                     Provides builder methods for all SObjects used across test classes,
                     ensuring a single source of truth for test data setup.
  @author            ASDA Dev Agent (Claude Code)
  @created           2026-06-05
  @lastModified      2026-06-05
  @group             CaseTransfer
 
  @dependencies      (none — this is a test utility)
  @calledBy          CaseSummaryControllerTest, CaseSummaryGeneratorQueueableTest,
                     CaseSummarySelector, CaseTransferServiceTest, CaseTriggerHandlerTest
  @testClass         (none — this IS the test utility; it is annotated @isTest)
 
  @see               HLD Section 5 — Test Data Strategy
 */
// MODIFIED 2026-06-05 — Project: Case Transfer | LLD-CaseTransfer-1 (BR1-BR2) | ASDA
@isTest
public class TestDataFactory {

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

    public static Object createCaseTransferSummary(Id caseId, String status) {
        return null;
    }

    public static List<Object> createCaseTransferSummaries(Id caseId, Integer count) {
        return new List<Object>();
    }

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
