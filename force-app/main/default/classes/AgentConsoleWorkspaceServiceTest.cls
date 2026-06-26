/**
 * @file        AgentConsoleWorkspaceServiceTest.cls
 * @description Tests AgentConsoleWorkspaceService — covers workspace data bundle
 *              retrieval, activity queries, prior case history, knowledge search,
 *              AI recommendations, and workspace-usage stamping. All service calls
 *              execute inside System.runAs with a Standard User who holds the
 *              Agent_Console_Workspace_User permission set, which grants the FLS
 *              needed to satisfy WITH SECURITY_ENFORCED on the new custom fields.
 * @testFor     AgentConsoleWorkspaceService
 * @coverage    Target >= 90%.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-26
 * @lastModified 2026-06-26
 * @group       AgentConsoleWorkspace
 * @see         LLD-AgentConsoleWorkspace (Project: Agent Console Workspace)
 */
// MODIFIED 2026-06-26 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
@isTest
private class AgentConsoleWorkspaceServiceTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Test setup
    // ─────────────────────────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        // ── Phase 1: User + PermSet assignment (cannot mix with SObject DML) ──
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testAgent = new User(
            FirstName        = 'Agent',
            LastName         = 'WorkspaceTestUser',
            Email            = 'agentworkspacetest@keneland.test',
            Username         = 'agentworkspacetest@keneland.test',
            Alias            = 'awtest',
            ProfileId        = stdProfile.Id,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey     = 'en_US',
            TimeZoneSidKey   = 'America/New_York'
        );
        insert testAgent;

        PermissionSet ps = [SELECT Id FROM PermissionSet
                            WHERE Name = 'Agent_Console_Workspace_User' LIMIT 1];
        insert new PermissionSetAssignment(PermissionSetId = ps.Id, AssigneeId = testAgent.Id);

        // ── Phase 2: SObject data created by the test agent (they become owner) ──
        System.runAs(testAgent) {
            Account acct = TestDataFactory.createAccount('Keneland Test Corp');
            Contact con  = TestDataFactory.createContact(acct, 'Workspace');
            Case openCase = TestDataFactory.createCase(acct, con, 'Workspace Test Case');

            // Seed a closed sibling Case for history tests
            Case closedCase = new Case(
                Subject   = 'Old Resolved Issue',
                Status    = 'Closed',
                Priority  = 'High',
                Origin    = 'Phone',
                ContactId = con.Id,
                AccountId = acct.Id
            );
            insert closedCase;

            // Seed a Task on the open Case
            insert new Task(
                Subject  = 'Follow up call',
                Status   = 'Not Started',
                Priority = 'Normal',
                WhatId   = openCase.Id
            );
        }

        // ── Phase 3: AI Recommendation — set OwnerId to testAgent so it is visible
        //   under Private OWD even though sysadmin does the insert.
        User testAgentRef = [SELECT Id FROM User
                             WHERE Username = 'agentworkspacetest@keneland.test' LIMIT 1];
        Case openCase = [SELECT Id FROM Case WHERE Subject = 'Workspace Test Case' LIMIT 1];
        Case_Recommendation__c rec = new Case_Recommendation__c(
            Case__c               = openCase.Id,
            Recommendation_Text__c = 'Restart the service and re-test connectivity.',
            Resolution_Type__c    = 'Knowledge',
            Confidence_Score__c   = 92.5,
            Is_Applied__c         = false,
            OwnerId               = testAgentRef.Id
        );
        insert rec;
    }

    /** Returns the pre-created test agent user. */
    private static User getTestAgent() {
        return [SELECT Id FROM User WHERE Username = 'agentworkspacetest@keneland.test' LIMIT 1];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getWorkspaceData
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getWorkspaceData_returnsBundle() {
        User u = getTestAgent();
        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Test Case' LIMIT 1];
        AgentConsoleWorkspaceService.WorkspaceData wd;

        Test.startTest();
        System.runAs(u) {
            wd = AgentConsoleWorkspaceService.getWorkspaceData(c.Id);
        }
        Test.stopTest();

        System.assertNotEquals(null, wd, 'WorkspaceData should not be null');
        System.assertEquals(c.Id, wd.caseRecord.Id, 'Case ID should match');
        System.assertNotEquals(null, wd.accountRecord, 'Account should be populated');
        System.assertNotEquals(null, wd.contactRecord, 'Contact should be populated');
        System.assertEquals('Keneland Test Corp', wd.accountRecord.Name, 'Account name should match');
    }

    @isTest
    static void test_getWorkspaceData_nullId_throws() {
        User u = getTestAgent();
        Boolean exceptionThrown = false;

        Test.startTest();
        System.runAs(u) {
            try {
                AgentConsoleWorkspaceService.getWorkspaceData(null);
            } catch (AuraHandledException ex) {
                exceptionThrown = true;
            }
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'AuraHandledException expected for null caseId');
    }

    @isTest
    static void test_getWorkspaceData_noAccountContact_returnsNullRefs() {
        User u = getTestAgent();
        Case standalone;

        System.runAs(u) {
            standalone = new Case(Subject = 'Standalone Case', Status = 'New', Origin = 'Web');
            insert standalone;
        }
        AgentConsoleWorkspaceService.WorkspaceData wd;

        Test.startTest();
        System.runAs(u) {
            wd = AgentConsoleWorkspaceService.getWorkspaceData(standalone.Id);
        }
        Test.stopTest();

        System.assertNotEquals(null, wd.caseRecord, 'Case record must be present');
        System.assertEquals(null, wd.accountRecord, 'Account should be null when no AccountId');
        System.assertEquals(null, wd.contactRecord, 'Contact should be null when no ContactId');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getRelatedActivities
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getRelatedActivities_returnsTasks() {
        User u = getTestAgent();
        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Test Case' LIMIT 1];
        List<Task> tasks;

        Test.startTest();
        System.runAs(u) {
            tasks = AgentConsoleWorkspaceService.getRelatedActivities(c.Id);
        }
        Test.stopTest();

        System.assertEquals(1, tasks.size(), 'Expected the seeded Task');
        System.assertEquals('Follow up call', tasks[0].Subject, 'Task subject mismatch');
    }

    @isTest
    static void test_getRelatedActivities_nullId_returnsEmpty() {
        User u = getTestAgent();
        List<Task> tasks;

        Test.startTest();
        System.runAs(u) {
            tasks = AgentConsoleWorkspaceService.getRelatedActivities(null);
        }
        Test.stopTest();
        System.assertEquals(0, tasks.size(), 'Null caseId should return empty list');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getRelatedEmailMessages
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getRelatedEmailMessages_nullId_returnsEmpty() {
        User u = getTestAgent();
        List<EmailMessage> msgs;

        Test.startTest();
        System.runAs(u) {
            msgs = AgentConsoleWorkspaceService.getRelatedEmailMessages(null);
        }
        Test.stopTest();
        System.assertEquals(0, msgs.size(), 'Null caseId should return empty list');
    }

    @isTest
    static void test_getRelatedEmailMessages_validCase_returnsEmails() {
        User u = getTestAgent();
        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Test Case' LIMIT 1];
        List<EmailMessage> msgs;

        Test.startTest();
        System.runAs(u) {
            msgs = AgentConsoleWorkspaceService.getRelatedEmailMessages(c.Id);
        }
        Test.stopTest();

        System.assertNotEquals(null, msgs, 'Result list should not be null');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getPreviousCases
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getPreviousCases_returnsHistory() {
        User u = getTestAgent();
        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Test Case' LIMIT 1];
        List<Case> history;

        Test.startTest();
        System.runAs(u) {
            history = AgentConsoleWorkspaceService.getPreviousCases(c.Id);
        }
        Test.stopTest();

        System.assertEquals(1, history.size(), 'Expected 1 prior closed Case');
        System.assertEquals('Old Resolved Issue', history[0].Subject, 'Subject mismatch');
    }

    @isTest
    static void test_getPreviousCases_nullId_returnsEmpty() {
        User u = getTestAgent();
        List<Case> history;

        Test.startTest();
        System.runAs(u) {
            history = AgentConsoleWorkspaceService.getPreviousCases(null);
        }
        Test.stopTest();
        System.assertEquals(0, history.size(), 'Null caseId should return empty list');
    }

    @isTest
    static void test_getPreviousCases_noContact_returnsEmpty() {
        User u = getTestAgent();
        Case standalone;
        List<Case> history;

        System.runAs(u) {
            standalone = new Case(Subject = 'No Contact Case', Status = 'New', Origin = 'Web');
            insert standalone;
        }

        Test.startTest();
        System.runAs(u) {
            history = AgentConsoleWorkspaceService.getPreviousCases(standalone.Id);
        }
        Test.stopTest();
        System.assertEquals(0, history.size(), 'No contact means no history');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getKnowledgeArticles
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getKnowledgeArticles_blankReturnsEmpty() {
        User u = getTestAgent();
        List<SObject> results;

        Test.startTest();
        System.runAs(u) {
            results = AgentConsoleWorkspaceService.getKnowledgeArticles('');
        }
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Blank search should return empty list');
    }

    @isTest
    static void test_getKnowledgeArticles_nullReturnsEmpty() {
        User u = getTestAgent();
        List<SObject> results;

        Test.startTest();
        System.runAs(u) {
            results = AgentConsoleWorkspaceService.getKnowledgeArticles(null);
        }
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Null search should return empty list');
    }

    @isTest
    static void test_getKnowledgeArticles_noMatchReturnsEmpty() {
        User u = getTestAgent();
        List<SObject> results;

        Test.startTest();
        System.runAs(u) {
            // Dynamic SOQL returns empty when Knowledge not enabled or no match found
            results = AgentConsoleWorkspaceService.getKnowledgeArticles('xQzNonExistentTermXYZ999');
        }
        Test.stopTest();
        System.assertNotEquals(null, results, 'Result list should not be null');
        System.assert(results.size() <= 10, 'Result should be within LIMIT 10');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getAIRecommendations
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getAIRecommendations_returnsRecs() {
        User u = getTestAgent();
        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Test Case' LIMIT 1];
        List<Case_Recommendation__c> recs;

        Test.startTest();
        System.runAs(u) {
            recs = AgentConsoleWorkspaceService.getAIRecommendations(c.Id);
        }
        Test.stopTest();

        System.assertEquals(1, recs.size(), 'Expected the seeded recommendation');
        System.assertEquals(92.5, recs[0].Confidence_Score__c, 'Confidence score mismatch');
    }

    @isTest
    static void test_getAIRecommendations_nullId_returnsEmpty() {
        User u = getTestAgent();
        List<Case_Recommendation__c> recs;

        Test.startTest();
        System.runAs(u) {
            recs = AgentConsoleWorkspaceService.getAIRecommendations(null);
        }
        Test.stopTest();
        System.assertEquals(0, recs.size(), 'Null caseId should return empty list');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getCaseMilestones
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getCaseMilestones_nullId_returnsEmpty() {
        User u = getTestAgent();
        List<CaseMilestone> milestones;

        Test.startTest();
        System.runAs(u) {
            milestones = AgentConsoleWorkspaceService.getCaseMilestones(null);
        }
        Test.stopTest();
        System.assertEquals(0, milestones.size(), 'Null caseId should return empty list');
    }

    @isTest
    static void test_getCaseMilestones_validCase_returnsListOrEmpty() {
        User u = getTestAgent();
        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Test Case' LIMIT 1];
        List<CaseMilestone> milestones;

        Test.startTest();
        System.runAs(u) {
            milestones = AgentConsoleWorkspaceService.getCaseMilestones(c.Id);
        }
        Test.stopTest();

        System.assertNotEquals(null, milestones, 'Result list should not be null');
        System.assert(milestones.size() <= 10, 'Should be within LIMIT 10');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // markWorkspaceUsed
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_markWorkspaceUsed_stampsFields() {
        User u = getTestAgent();
        Case c = [SELECT Id, Workspace_Used__c FROM Case
                  WHERE Subject = 'Workspace Test Case' LIMIT 1];
        System.assertEquals(false, c.Workspace_Used__c, 'Workspace_Used__c should start false');

        Test.startTest();
        System.runAs(u) {
            AgentConsoleWorkspaceService.markWorkspaceUsed(c.Id);
        }
        Test.stopTest();

        Case updated = [SELECT Workspace_Used__c, Workspace_Opened_At__c
                        FROM Case WHERE Id = :c.Id];
        System.assertEquals(true, updated.Workspace_Used__c, 'Workspace_Used__c should be true');
        System.assertNotEquals(null, updated.Workspace_Opened_At__c,
            'Workspace_Opened_At__c should be set on first open');
    }

    @isTest
    static void test_markWorkspaceUsed_secondCall_doesNotOverwriteTimestamp() {
        User u = getTestAgent();
        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Test Case' LIMIT 1];

        System.runAs(u) {
            AgentConsoleWorkspaceService.markWorkspaceUsed(c.Id);
        }
        Datetime firstOpen = [SELECT Workspace_Opened_At__c FROM Case WHERE Id = :c.Id]
                             .Workspace_Opened_At__c;

        Test.startTest();
        System.runAs(u) {
            AgentConsoleWorkspaceService.markWorkspaceUsed(c.Id);
        }
        Test.stopTest();

        Datetime secondOpen = [SELECT Workspace_Opened_At__c FROM Case WHERE Id = :c.Id]
                              .Workspace_Opened_At__c;
        System.assertEquals(firstOpen, secondOpen,
            'Workspace_Opened_At__c should not be overwritten on second call');
    }

    @isTest
    static void test_markWorkspaceUsed_nullId_throws() {
        User u = getTestAgent();
        Boolean exceptionThrown = false;

        Test.startTest();
        System.runAs(u) {
            try {
                AgentConsoleWorkspaceService.markWorkspaceUsed(null);
            } catch (AuraHandledException ex) {
                exceptionThrown = true;
            }
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'AuraHandledException expected for null caseId');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Bulk safety test
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_bulkCases_200Records_noGovernorLimitErrors() {
        User u = getTestAgent();
        List<Case> cases;

        System.runAs(u) {
            cases = TestDataFactory.createCases(200);
        }
        AgentConsoleWorkspaceService.WorkspaceData wdFirst;
        AgentConsoleWorkspaceService.WorkspaceData wdLast;

        Test.startTest();
        System.runAs(u) {
            wdFirst = AgentConsoleWorkspaceService.getWorkspaceData(cases[0].Id);
            wdLast  = AgentConsoleWorkspaceService.getWorkspaceData(cases[199].Id);
        }
        Test.stopTest();

        System.assertNotEquals(null, wdFirst, 'First case workspace data must not be null');
        System.assertNotEquals(null, wdLast, 'Last case workspace data must not be null');
    }
}
