/**
 * @file        AgentConsoleWorkspaceServiceTest.cls
 * @description Tests AgentConsoleWorkspaceService. Covers getCaseData,
 *              getPreviousInteractions, searchKnowledge, and markWorkspaceOpened.
 *              Validates null-argument guards, idempotent workspace stamping,
 *              interaction retrieval with and without a Contact, and bulk limits.
 * @testFor     AgentConsoleWorkspaceService
 * @coverage    Target >= 85%.
 */
// MODIFIED 2026-06-24 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
@isTest
private class AgentConsoleWorkspaceServiceTest {

    @TestSetup
    static void setupData() {
        Account acct = new Account(
            Name = 'Keneland Test Corp',
            Industry = 'Technology',
            Phone = '555-000-0001'
        );
        insert acct;

        Contact con = new Contact(
            FirstName = 'Agent',
            LastName = 'Tester',
            Email = 'agent.tester@keneland.test',
            Phone = '555-000-0002',
            AccountId = acct.Id
        );
        insert con;

        Case activeCase = new Case(
            Subject = 'Workspace Integration Error',
            Status = 'New',
            Priority = 'High',
            Origin = 'Web',
            AccountId = acct.Id,
            ContactId = con.Id,
            Description = 'Integration error when loading workspace panel.'
        );
        insert activeCase;

        Case priorCase = new Case(
            Subject = 'Prior Closed Case',
            Status = 'Closed',
            Priority = 'Low',
            Origin = 'Email',
            AccountId = acct.Id,
            ContactId = con.Id
        );
        insert priorCase;

        Case_Recommendation__c rec = new Case_Recommendation__c(
            Case__c = activeCase.Id,
            Recommendation_Text__c = 'Restart the integration middleware.',
            Recommended_Resolution__c = 'Restart Middleware',
            Confidence_Score__c = 0.92,
            Recommendation_Status__c = 'Active'
        );
        insert rec;

        EmailMessage email = new EmailMessage(
            ParentId = activeCase.Id,
            Subject = 'Test email',
            FromAddress = 'noreply@keneland.test',
            ToAddress = 'agent@keneland.test',
            TextBody = 'Please investigate.',
            MessageDate = Datetime.now(),
            Status = '3'
        );
        insert email;

        Task taskRec = new Task(
            Subject = 'Follow up call',
            WhatId = activeCase.Id,
            Status = 'Open',
            Priority = 'Normal',
            ActivityDate = Date.today()
        );
        insert taskRec;
    }

    // ─── getCaseData Tests ────────────────────────────────────────────────────

    @isTest
    static void test_getCaseData_returnsCase() {
        Case seedCase = [SELECT Id FROM Case WHERE Subject = 'Workspace Integration Error' LIMIT 1];
        Test.startTest();
        AgentConsoleWorkspaceService.CaseDataWrapper result =
            AgentConsoleWorkspaceService.getCaseData(seedCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertNotEquals(null, result.caseRecord, 'caseRecord should not be null');
        System.assertEquals(seedCase.Id, result.caseRecord.Id, 'Case Id should match');
    }

    @isTest
    static void test_getCaseData_returnsAccountAndContact() {
        Case seedCase = [SELECT Id FROM Case WHERE Subject = 'Workspace Integration Error' LIMIT 1];
        Test.startTest();
        AgentConsoleWorkspaceService.CaseDataWrapper result =
            AgentConsoleWorkspaceService.getCaseData(seedCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.accountRecord, 'Account should be populated');
        System.assertEquals('Keneland Test Corp', result.accountRecord.Name, 'Account name should match');
        System.assertNotEquals(null, result.contactRecord, 'Contact should be populated');
        System.assertEquals('Agent Tester', result.contactRecord.Name, 'Contact name should match');
    }

    @isTest
    static void test_getCaseData_withRecommendations() {
        Case seedCase = [SELECT Id FROM Case WHERE Subject = 'Workspace Integration Error' LIMIT 1];
        Test.startTest();
        AgentConsoleWorkspaceService.CaseDataWrapper result =
            AgentConsoleWorkspaceService.getCaseData(seedCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.recommendations, 'Recommendations should not be null');
        System.assertEquals(1, result.recommendations.size(), 'Should have 1 recommendation');
        System.assertEquals(
            'Restart Middleware',
            result.recommendations[0].Recommended_Resolution__c,
            'Recommendation resolution should match'
        );
    }

    @isTest
    static void test_getCaseData_nullId_throws() {
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getCaseData(null);
            System.assert(false, 'Expected AuraHandledException for null caseId');
        } catch (AuraHandledException ex) {
            System.assert(true, 'AuraHandledException correctly thrown for null caseId');
        }
        Test.stopTest();
    }

    // ─── getPreviousInteractions Tests ────────────────────────────────────────

    @isTest
    static void test_getPreviousInteractions_withContact() {
        Case seedCase = [SELECT Id, ContactId FROM Case WHERE Subject = 'Workspace Integration Error' LIMIT 1];
        Test.startTest();
        AgentConsoleWorkspaceService.InteractionWrapper result =
            AgentConsoleWorkspaceService.getPreviousInteractions(seedCase.Id, seedCase.ContactId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'InteractionWrapper should not be null');
        System.assertEquals(1, result.emails.size(), 'Should find 1 seeded email');
        System.assertEquals(1, result.tasks.size(), 'Should find 1 seeded task');
        System.assertEquals(1, result.priorCases.size(), 'Should find 1 prior closed case');
    }

    @isTest
    static void test_getPreviousInteractions_noContact() {
        Case seedCase = [SELECT Id FROM Case WHERE Subject = 'Workspace Integration Error' LIMIT 1];
        Test.startTest();
        AgentConsoleWorkspaceService.InteractionWrapper result =
            AgentConsoleWorkspaceService.getPreviousInteractions(seedCase.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'InteractionWrapper should not be null');
        System.assertEquals(0, result.priorCases.size(), 'Prior cases should be empty with null contactId');
    }

    @isTest
    static void test_getPreviousInteractions_nullId_throws() {
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getPreviousInteractions(null, null);
            System.assert(false, 'Expected AuraHandledException for null caseId');
        } catch (AuraHandledException ex) {
            System.assert(true, 'AuraHandledException correctly thrown for null caseId');
        }
        Test.stopTest();
    }

    // ─── searchKnowledge Tests ────────────────────────────────────────────────

    @isTest
    static void test_searchKnowledge_returnsWrapper() {
        Test.startTest();
        AgentConsoleWorkspaceService.KnowledgeResultWrapper result =
            AgentConsoleWorkspaceService.searchKnowledge('integration error');
        Test.stopTest();

        System.assertNotEquals(null, result, 'KnowledgeResultWrapper should not be null');
        System.assertNotEquals(null, result.articles, 'Articles list should not be null');
    }

    @isTest
    static void test_searchKnowledge_blankTerm_returnsEmpty() {
        Test.startTest();
        AgentConsoleWorkspaceService.KnowledgeResultWrapper result =
            AgentConsoleWorkspaceService.searchKnowledge('');
        Test.stopTest();

        System.assertEquals(0, result.articles.size(), 'Empty search term should return empty list');
    }

    @isTest
    static void test_searchKnowledge_shortTerm_returnsEmpty() {
        Test.startTest();
        AgentConsoleWorkspaceService.KnowledgeResultWrapper result =
            AgentConsoleWorkspaceService.searchKnowledge('X');
        Test.stopTest();

        System.assertEquals(0, result.articles.size(), 'Single-char term should return empty list');
    }

    // ─── markWorkspaceOpened Tests ────────────────────────────────────────────

    @isTest
    static void test_markWorkspaceOpened_stampsFields() {
        Case seedCase = [SELECT Id, Workspace_Used__c FROM Case WHERE Subject = 'Workspace Integration Error' LIMIT 1];
        System.assertEquals(false, seedCase.Workspace_Used__c, 'Workspace_Used__c should start false');

        Test.startTest();
        AgentConsoleWorkspaceService.markWorkspaceOpened(seedCase.Id);
        Test.stopTest();

        Case updated = [SELECT Workspace_Used__c, Workspace_Opened_At__c FROM Case WHERE Id = :seedCase.Id];
        System.assertEquals(true, updated.Workspace_Used__c, 'Workspace_Used__c should be true after open');
        System.assertNotEquals(null, updated.Workspace_Opened_At__c, 'Workspace_Opened_At__c should be stamped');
    }

    @isTest
    static void test_markWorkspaceOpened_idempotent() {
        Case seedCase = [SELECT Id FROM Case WHERE Subject = 'Workspace Integration Error' LIMIT 1];
        Test.startTest();
        AgentConsoleWorkspaceService.markWorkspaceOpened(seedCase.Id);
        Datetime firstStamp = [SELECT Workspace_Opened_At__c FROM Case WHERE Id = :seedCase.Id].Workspace_Opened_At__c;
        AgentConsoleWorkspaceService.markWorkspaceOpened(seedCase.Id);
        Test.stopTest();

        Datetime secondStamp = [SELECT Workspace_Opened_At__c FROM Case WHERE Id = :seedCase.Id].Workspace_Opened_At__c;
        System.assertEquals(firstStamp, secondStamp, 'Timestamp should not change on second call');
    }

    @isTest
    static void test_markWorkspaceOpened_nullId_throws() {
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.markWorkspaceOpened(null);
            System.assert(false, 'Expected AuraHandledException for null caseId');
        } catch (AuraHandledException ex) {
            System.assert(true, 'AuraHandledException correctly thrown for null caseId');
        }
        Test.stopTest();
    }

    // ─── Bulk Test ────────────────────────────────────────────────────────────

    @isTest
    static void test_getCaseData_recommendationCapApplied() {
        Account bulkAcct = new Account(Name = 'Bulk Account');
        insert bulkAcct;

        Case bulkCase = new Case(
            Subject = 'Bulk Test Case',
            Status = 'New',
            AccountId = bulkAcct.Id
        );
        insert bulkCase;

        List<Case_Recommendation__c> recs = new List<Case_Recommendation__c>();
        for (Integer i = 0; i < 15; i++) {
            recs.add(new Case_Recommendation__c(
                Case__c = bulkCase.Id,
                Recommendation_Text__c = 'Bulk Rec ' + i,
                Recommended_Resolution__c = 'Resolution ' + i,
                Confidence_Score__c = 0.5,
                Recommendation_Status__c = 'Active'
            ));
        }
        insert recs;

        Test.startTest();
        AgentConsoleWorkspaceService.CaseDataWrapper result =
            AgentConsoleWorkspaceService.getCaseData(bulkCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Bulk wrapper should not be null');
        System.assert(result.recommendations.size() <= 10, 'Recommendations should be capped at 10');
    }
}
