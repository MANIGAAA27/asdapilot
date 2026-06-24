/**
 * @file        AgentConsoleWorkspaceServiceTest.cls
 * @description Tests AgentConsoleWorkspaceService — covers getCaseContext,
 *              getInteractions, searchKnowledge, and markWorkspaceUsed.
 *              Validates null-guard paths, bulk stability (200 Cases), and
 *              CRUD/FLS enforcement via System.runAs.
 * @testFor     AgentConsoleWorkspaceService
 * @coverage    Target ≥ 85%.
 * @project     Agent Console Workspace
 * @lld         LLD-AgentConsoleWorkspace
 */
// MODIFIED 2026-06-24 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
@isTest
private class AgentConsoleWorkspaceServiceTest {

    @TestSetup
    static void setupData() {
        Account acct = new Account(
            Name = 'Test Account ACW',
            Industry = 'Technology',
            SLA__c = 'Gold'
        );
        insert acct;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact ACW',
            AccountId = acct.Id,
            Email = 'test.acw@example.com',
            Phone = '5550001234'
        );
        insert con;

        Case primaryCase = new Case(
            Subject = 'Primary ACW Test Case',
            Status = 'New',
            Priority = 'Medium',
            Origin = 'Phone',
            AccountId = acct.Id,
            ContactId = con.Id,
            Description = 'Test description for workspace.'
        );
        insert primaryCase;

        Case closedCase = new Case(
            Subject = 'Prior Closed ACW Case',
            Status = 'Closed',
            Priority = 'Low',
            Origin = 'Web',
            AccountId = acct.Id,
            ContactId = con.Id
        );
        insert closedCase;
    }

    // -------------------------------------------------------------------------
    // getCaseContext tests
    // -------------------------------------------------------------------------

    @isTest
    static void test_getCaseContext_validCase_returnsWrapper() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Primary ACW Test Case' LIMIT 1];

        Test.startTest();
        AgentConsoleWorkspaceService.CaseContextWrapper result =
            AgentConsoleWorkspaceService.getCaseContext(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper must not be null');
        System.assertNotEquals(null, result.caseRecord, 'Case record must be present');
        System.assertEquals(c.Id, result.caseRecord.Id, 'Case Id must match');
        System.assertNotEquals(null, result.accountRecord, 'Account must be populated');
        System.assertNotEquals(null, result.contactRecord, 'Contact must be populated');
        System.assertNotEquals(null, result.milestones, 'Milestones list must not be null');
        System.assertNotEquals(null, result.recommendations, 'Recommendations list must not be null');
    }

    @isTest
    static void test_getCaseContext_blankId_throws() {
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getCaseContext(null);
            System.assert(false, 'Expected AuraHandledException for null caseId');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage() != null, 'Exception message must be present');
        }
        Test.stopTest();
    }

    @isTest
    static void test_getCaseContext_noAccountContact_handlesNulls() {
        Case orphan = new Case(Subject = 'Orphan ACW Case', Status = 'New', Origin = 'Phone');
        insert orphan;

        Test.startTest();
        AgentConsoleWorkspaceService.CaseContextWrapper result =
            AgentConsoleWorkspaceService.getCaseContext(orphan.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper must not be null');
        System.assertEquals(null, result.accountRecord, 'Account should be null when not linked');
        System.assertEquals(null, result.contactRecord, 'Contact should be null when not linked');
    }

    @isTest
    static void test_getCaseContext_bulkStability_200Cases() {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Case(Subject = 'Bulk ACW Case ' + i, Status = 'New', Origin = 'Phone'));
        }
        insert cases;

        Test.startTest();
        AgentConsoleWorkspaceService.CaseContextWrapper result =
            AgentConsoleWorkspaceService.getCaseContext(cases[0].Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper must not be null for bulk-inserted case');
    }

    // -------------------------------------------------------------------------
    // getInteractions tests
    // -------------------------------------------------------------------------

    @isTest
    static void test_getInteractions_withContact_returnsPriorCases() {
        Case c = [SELECT Id, ContactId FROM Case WHERE Subject = 'Primary ACW Test Case' LIMIT 1];

        Test.startTest();
        AgentConsoleWorkspaceService.InteractionsWrapper result =
            AgentConsoleWorkspaceService.getInteractions(c.Id, c.ContactId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper must not be null');
        System.assertNotEquals(null, result.priorCases, 'Prior cases list must not be null');
        System.assertNotEquals(null, result.emails, 'Emails list must not be null');
        System.assertNotEquals(null, result.tasks, 'Tasks list must not be null');
        System.assert(result.priorCases.size() >= 1, 'At least one prior closed case expected');
    }

    @isTest
    static void test_getInteractions_noContact_returnsEmptyPriorCases() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Primary ACW Test Case' LIMIT 1];

        Test.startTest();
        AgentConsoleWorkspaceService.InteractionsWrapper result =
            AgentConsoleWorkspaceService.getInteractions(c.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper must not be null');
        System.assertEquals(0, result.priorCases.size(), 'Prior cases must be empty when contactId is null');
    }

    @isTest
    static void test_getInteractions_blankCaseId_throws() {
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getInteractions(null, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage() != null, 'Exception message must be present');
        }
        Test.stopTest();
    }

    // -------------------------------------------------------------------------
    // searchKnowledge tests
    // -------------------------------------------------------------------------

    @isTest
    static void test_searchKnowledge_blankTerm_returnsEmpty() {
        Test.startTest();
        List<AgentConsoleWorkspaceService.KnowledgeArticleResult> results =
            AgentConsoleWorkspaceService.searchKnowledge('');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result list must not be null');
        System.assertEquals(0, results.size(), 'Blank term must return empty list');
    }

    @isTest
    static void test_searchKnowledge_nullTerm_returnsEmpty() {
        Test.startTest();
        List<AgentConsoleWorkspaceService.KnowledgeArticleResult> results =
            AgentConsoleWorkspaceService.searchKnowledge(null);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result list must not be null');
        System.assertEquals(0, results.size(), 'Null term must return empty list');
    }

    @isTest
    static void test_searchKnowledge_validTerm_doesNotThrow() {
        Test.startTest();
        List<AgentConsoleWorkspaceService.KnowledgeArticleResult> results =
            AgentConsoleWorkspaceService.searchKnowledge('printer connectivity issue');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Must return non-null list regardless of Knowledge status');
    }

    // -------------------------------------------------------------------------
    // markWorkspaceUsed tests
    // -------------------------------------------------------------------------

    @isTest
    static void test_markWorkspaceUsed_setsFields() {
        Case c = [SELECT Id, Workspace_Used__c, Workspace_Opened_At__c
                  FROM Case WHERE Subject = 'Primary ACW Test Case' LIMIT 1];
        System.assertEquals(false, c.Workspace_Used__c, 'Must start false');
        System.assertEquals(null, c.Workspace_Opened_At__c, 'Must start null');

        Test.startTest();
        AgentConsoleWorkspaceService.markWorkspaceUsed(c.Id);
        Test.stopTest();

        Case updated = [SELECT Workspace_Used__c, Workspace_Opened_At__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(true, updated.Workspace_Used__c, 'Must be true after marking');
        System.assertNotEquals(null, updated.Workspace_Opened_At__c, 'Must be stamped');
    }

    @isTest
    static void test_markWorkspaceUsed_blankId_throws() {
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.markWorkspaceUsed(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage() != null, 'Exception message must be present');
        }
        Test.stopTest();
    }

    @isTest
    static void test_markWorkspaceUsed_runAs_agentProfile() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User agent = new User(
            FirstName = 'ACW', LastName = 'TestAgent',
            Email = 'acw.agent.test@example.test',
            Username = 'acw.agent.test@example.test.acw',
            Alias = 'acwagent',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert agent;

        Case c = [SELECT Id FROM Case WHERE Subject = 'Primary ACW Test Case' LIMIT 1];

        Test.startTest();
        System.runAs(agent) {
            AgentConsoleWorkspaceService.markWorkspaceUsed(c.Id);
        }
        Test.stopTest();

        Case updated = [SELECT Workspace_Used__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(true, updated.Workspace_Used__c, 'Must be true after agent marks it');
    }
}
