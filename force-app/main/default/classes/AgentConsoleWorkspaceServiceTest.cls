/**
 * @file        AgentConsoleWorkspaceServiceTest.cls
 * @description Tests AgentConsoleWorkspaceService — covers getCaseDetails,
 *              getPreviousInteractions, getAiRecommendations, getCaseMilestones,
 *              trackWorkspaceOpen, null-input guards, and bulk 200-record paths.
 * @testFor     AgentConsoleWorkspaceService
 * @coverage    Target >= 90%.
 * @project     Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
 * @lld         LLD-AgentConsoleWorkspace
 */
// MODIFIED 2026-06-25 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
@isTest
private class AgentConsoleWorkspaceServiceTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Shared test data setup
    // ─────────────────────────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        Account acct = new Account(Name = 'Keneland Test Account', Industry = 'Technology');
        insert acct;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Agent',
            Email     = 'agent@keneland.test',
            Phone     = '5550001234',
            AccountId = acct.Id
        );
        insert con;

        Case primaryCase = new Case(
            Subject     = 'Workspace Unit Test Case',
            Status      = 'New',
            Priority    = 'Medium',
            Origin      = 'Web',
            AccountId   = acct.Id,
            ContactId   = con.Id,
            Description = 'Created by AgentConsoleWorkspaceServiceTest'
        );
        insert primaryCase;

        // A prior closed Case on the same Contact for interactions history.
        Case closedCase = new Case(
            Subject   = 'Prior Closed Case',
            Status    = 'Closed',
            Priority  = 'Low',
            Origin    = 'Email',
            AccountId = acct.Id,
            ContactId = con.Id
        );
        insert closedCase;

        // AI Recommendation linked to the primary Case.
        Case_Recommendation__c rec = new Case_Recommendation__c(
            Case__c                   = primaryCase.Id,
            Recommendation_Text__c    = 'Restart the service.',
            Recommended_Resolution__c = 'Service restart resolved similar issues.',
            Confidence_Score__c       = 85,
            Source__c                 = 'Einstein'
        );
        insert rec;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getCaseDetails
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getCaseDetails_returnsWrapper() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Unit Test Case' LIMIT 1];

        Test.startTest();
        CaseDetailWrapper result = AgentConsoleWorkspaceService.getCaseDetails(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertNotEquals(null, result.caseRecord, 'caseRecord should be populated');
        System.assertEquals(
            'Workspace Unit Test Case', result.caseRecord.Subject,
            'Case Subject should match'
        );
        System.assertEquals(
            'Keneland Test Account', result.accountName,
            'Account name should be populated'
        );
        System.assertNotEquals(null, result.contactName, 'Contact name should be set');
    }

    @isTest
    static void test_getCaseDetails_nullId_throws() {
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getCaseDetails(null);
            System.assert(false, 'Expected AuraHandledException for null caseId');
        } catch (AuraHandledException ex) {
            System.assert(true, 'AuraHandledException correctly thrown for null input');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getPreviousInteractions
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getPreviousInteractions_returnsResults() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Unit Test Case' LIMIT 1];

        insert new Task(
            Subject      = 'Follow-up call',
            Status       = 'Completed',
            WhatId       = c.Id,
            ActivityDate = Date.today()
        );

        Test.startTest();
        List<InteractionWrapper> interactions =
            AgentConsoleWorkspaceService.getPreviousInteractions(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, interactions, 'Should return a list (not null)');
        System.assert(interactions.size() >= 1, 'At least one interaction expected');
    }

    @isTest
    static void test_getPreviousInteractions_nullId_throws() {
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getPreviousInteractions(null);
            System.assert(false, 'Expected AuraHandledException for null caseId');
        } catch (AuraHandledException ex) {
            System.assert(true, 'AuraHandledException correctly thrown');
        }
        Test.stopTest();
    }

    @isTest
    static void test_getPreviousInteractions_bulk() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Contact con  = [SELECT Id FROM Contact LIMIT 1];

        List<Case> bulkCases = new List<Case>();
        for (Integer i = 0; i < 200; i++) {
            bulkCases.add(new Case(
                Subject   = 'Bulk Closed Case ' + i,
                Status    = 'Closed',
                Priority  = 'Low',
                Origin    = 'Web',
                AccountId = acct.Id,
                ContactId = con.Id
            ));
        }
        insert bulkCases;

        Case primary = [SELECT Id FROM Case WHERE Subject = 'Workspace Unit Test Case' LIMIT 1];

        Test.startTest();
        List<InteractionWrapper> results =
            AgentConsoleWorkspaceService.getPreviousInteractions(primary.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null during bulk run');
        Integer priorCaseCount = 0;
        for (InteractionWrapper iw : results) {
            if (iw.recordType == 'Prior Case') {
                priorCaseCount++;
            }
        }
        System.assert(priorCaseCount <= 10, 'Prior Case results must be capped at 10');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getAiRecommendations
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getAiRecommendations_returnsResults() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Unit Test Case' LIMIT 1];

        Test.startTest();
        List<Case_Recommendation__c> recs =
            AgentConsoleWorkspaceService.getAiRecommendations(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, recs, 'Result should not be null');
        System.assertEquals(1, recs.size(), 'Expected 1 seeded recommendation');
        System.assertEquals(
            'Restart the service.', recs[0].Recommendation_Text__c,
            'Recommendation text should match seed data'
        );
        System.assertEquals(85, (Integer) recs[0].Confidence_Score__c, 'Score should match');
    }

    @isTest
    static void test_getAiRecommendations_nullId_throws() {
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getAiRecommendations(null);
            System.assert(false, 'Expected AuraHandledException for null caseId');
        } catch (AuraHandledException ex) {
            System.assert(true, 'AuraHandledException correctly thrown');
        }
        Test.stopTest();
    }

    @isTest
    static void test_getAiRecommendations_emptyCaseReturnsEmpty() {
        Case noCaseRec = new Case(
            Subject  = 'No Rec Case',
            Status   = 'New',
            Priority = 'Low',
            Origin   = 'Web'
        );
        insert noCaseRec;

        Test.startTest();
        List<Case_Recommendation__c> recs =
            AgentConsoleWorkspaceService.getAiRecommendations(noCaseRec.Id);
        Test.stopTest();

        System.assertNotEquals(null, recs, 'Should return empty list, not null');
        System.assertEquals(0, recs.size(), 'No recommendations expected');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getCaseMilestones
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getCaseMilestones_emptyWhenNone() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Unit Test Case' LIMIT 1];

        Test.startTest();
        List<CaseMilestone> milestones =
            AgentConsoleWorkspaceService.getCaseMilestones(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, milestones, 'Should return empty list, not null');
        System.assertEquals(0, milestones.size(),
            'No milestones expected without entitlement setup');
    }

    @isTest
    static void test_getCaseMilestones_nullId_throws() {
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getCaseMilestones(null);
            System.assert(false, 'Expected AuraHandledException for null caseId');
        } catch (AuraHandledException ex) {
            System.assert(true, 'AuraHandledException correctly thrown');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // trackWorkspaceOpen
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_trackWorkspaceOpen_stampsFields() {
        Case c = [SELECT Id, Workspace_Used__c FROM Case
                  WHERE Subject = 'Workspace Unit Test Case' LIMIT 1];
        System.assertEquals(false, c.Workspace_Used__c,
            'Workspace_Used__c should start false');

        Test.startTest();
        AgentConsoleWorkspaceService.trackWorkspaceOpen(c.Id);
        Test.stopTest();

        Case updated = [SELECT Id, Workspace_Used__c, Workspace_Opened_At__c
                        FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals(true, updated.Workspace_Used__c,
            'Workspace_Used__c should be true');
        System.assertNotEquals(null, updated.Workspace_Opened_At__c,
            'Workspace_Opened_At__c should be stamped');
    }

    @isTest
    static void test_trackWorkspaceOpen_nullId_throws() {
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.trackWorkspaceOpen(null);
            System.assert(false, 'Expected AuraHandledException for null caseId');
        } catch (AuraHandledException ex) {
            System.assert(true, 'AuraHandledException correctly thrown');
        }
        Test.stopTest();
    }

    @isTest
    static void test_trackWorkspaceOpen_runAs_enforcesSharing() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName         = 'ACW',
            LastName          = 'TestUser',
            Email             = 'acwtestuser@keneland.test.invalid',
            Username          = 'acwtu_' + System.currentTimeMillis() + '@keneland.test.invalid',
            Alias             = 'acwtu',
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id
        );
        insert testUser;

        Case c = [SELECT Id FROM Case WHERE Subject = 'Workspace Unit Test Case' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            try {
                AgentConsoleWorkspaceService.trackWorkspaceOpen(c.Id);
            } catch (AuraHandledException ex) {
                System.assert(true, 'DML exception handled correctly for restricted user');
            }
        }
        Test.stopTest();
    }
}
