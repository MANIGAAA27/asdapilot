/**
 * @file              TestDataFactory.cls
 * @description       Centralised test data factory for the Agent Console Workspace project.
 *                    Provides builder-pattern methods for every SObject type used in
 *                    test classes. All methods insert and return the created record.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-27
 * @lastModified      2026-06-27
 * @group             TestInfrastructure
 * @project           Agent Console Workspace
 * @lld               LLD-AgentConsoleWorkspace
 *
 * @dependencies      (none)
 * @calledBy          AgentConsoleWorkspaceServiceTest
 */
@isTest
public class TestDataFactory {

    /** Creates and inserts a single Account. */
    public static Account createAccount(String name) {
        Account acct = new Account(
            Name = name,
            Industry = 'Technology',
            Phone = '5550001234',
            BillingCity = 'San Francisco',
            BillingState = 'CA',
            BillingCountry = 'US'
        );
        insert acct;
        return acct;
    }

    /** Creates and inserts a single Contact linked to the given Account. */
    public static Contact createContact(Id accountId, String lastName) {
        Contact con = new Contact(
            AccountId = accountId,
            LastName = lastName,
            Email = lastName.toLowerCase() + '@example.com',
            Phone = '5550009999',
            Title = 'Customer'
        );
        insert con;
        return con;
    }

    /** Creates and inserts an open Case linked to the given Account and Contact. */
    public static Case createCase(Id accountId, Id contactId, String subject) {
        Case c = new Case(
            AccountId = accountId,
            ContactId = contactId,
            Subject = subject,
            Status = 'New',
            Priority = 'Medium',
            Origin = 'Web',
            Description = 'Test case: ' + subject
        );
        insert c;
        return c;
    }

    /** Creates and inserts a closed Case for previous-interaction history tests. */
    public static Case createClosedCase(Id accountId, Id contactId, String subject) {
        Case c = new Case(
            AccountId = accountId,
            ContactId = contactId,
            Subject = subject,
            Status = 'Closed',
            Priority = 'Low',
            Origin = 'Phone',
            Description = 'Closed case: ' + subject
        );
        insert c;
        return c;
    }

    /** Creates and inserts a Case_Recommendation__c linked to the given Case. */
    public static Case_Recommendation__c createCaseRecommendation(Id caseId, String recType) {
        Case_Recommendation__c rec = new Case_Recommendation__c(
            Name = 'AI Recommendation - ' + recType,
            Case__c = caseId,
            Recommendation_Text__c = 'Suggested resolution for: ' + recType,
            Recommendation_Type__c = recType,
            Confidence_Score__c = 85.0
        );
        insert rec;
        return rec;
    }

    /** Creates and inserts N Case_Recommendation__c records for bulk testing. */
    public static List<Case_Recommendation__c> createCaseRecommendations(Id caseId, Integer count) {
        List<Case_Recommendation__c> recs = new List<Case_Recommendation__c>();
        for (Integer i = 0; i < count; i++) {
            recs.add(new Case_Recommendation__c(
                Name = 'Bulk Rec ' + i,
                Case__c = caseId,
                Recommendation_Text__c = 'Bulk recommendation ' + i,
                Recommendation_Type__c = 'Resolution Steps',
                Confidence_Score__c = Decimal.valueOf(50 + Math.mod(i, 50))
            ));
        }
        insert recs;
        return recs;
    }

    /** Creates and inserts N Case records for bulk testing. */
    public static List<Case> createCases(Integer count) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(new Case(
                Subject = 'Bulk Test Case ' + i,
                Status = 'New',
                Priority = 'Medium',
                Origin = 'Web'
            ));
        }
        insert cases;
        return cases;
    }

    /** Creates and inserts an EmailMessage on a Case. */
    public static EmailMessage createEmailMessage(Id caseId, String subject) {
        EmailMessage em = new EmailMessage(
            ParentId = caseId,
            Subject = subject,
            TextBody = 'Email body for: ' + subject,
            FromAddress = 'customer@example.com',
            ToAddress = 'support@keneland.com',
            Incoming = true,
            Status = '0'
        );
        insert em;
        return em;
    }

    /** Creates and inserts a Task related to a Case. */
    public static Task createTask(Id caseId, String subject) {
        Task t = new Task(
            WhatId = caseId,
            Subject = subject,
            Status = 'Completed',
            ActivityDate = Date.today()
        );
        insert t;
        return t;
    }
}
