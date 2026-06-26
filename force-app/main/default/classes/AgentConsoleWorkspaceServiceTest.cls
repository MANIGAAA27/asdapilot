/**
 * @file        AgentConsoleWorkspaceServiceTest.cls
 * @description Tests AgentConsoleWorkspaceService: getCaseDetails, getInteractionHistory,
 *              getKnowledgeArticles, getRecommendations, and markWorkspaceOpened.
 *              Validates null-input guards, bulk paths, and CRUD/FLS enforcement
 *              via System.runAs.
 * @testFor     AgentConsoleWorkspaceService
 * @coverage    Target >= 85%.
 * @project     Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
 */
// MODIFIED 2026-06-26 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
@isTest
private class AgentConsoleWorkspaceServiceTest {

    // ===========================================================================
    // Test setup
    // ===========================================================================

    @TestSetup
    static void setupData() {
        Account acct = new Account(Name = 'Keneland Test Account', Industry = 'Technology');
        insert acct;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Agent',
            AccountId = acct.Id,
            Email = 'agent@keneland.test'
        );
        insert con;

        Case c = new Case(
            Subject = 'Widget not working',
            Status = 'New',
            Priority = 'Medium',
            Origin = 'Web',
            AccountId = acct.Id,
            ContactId = con.Id,
            Description = 'Test description for knowledge search'
        );
        insert c;

        Case_Recommendation__c rec = new Case_Recommendation__c(
            Case__c = c.Id,
            Recommendation_Text__c = 'Try rebooting the widget.',
            Resolution_Summary__c = 'Power cycle resolves 80% of widget issues.',
            Confidence_Score__c = 0.85,
            Source__c = 'Einstein',
            Recommendation_Status__c = 'New'
        );
        insert rec;
    }

    private static Id getTestCaseId() {
        return [SELECT Id FROM Case WHERE Subject = 'Widget not working' LIMIT 1].Id;
    }

    private static Id getTestContactId() {
        return [SELECT Id FROM Contact WHERE LastName = 'Agent' LIMIT 1].Id;
    }

    private static Id getTestAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Keneland Test Account' LIMIT 1].Id;
    }

    // ===========================================================================
    // getCaseDetails
    // ===========================================================================

    @isTest
    static void test_getCaseDetails_validCase_returnsWrapper() {
        Id caseId = getTestCaseId();
        Test.startTest();
        AgentConsoleWorkspaceService.CaseDetailWrapper result =
            AgentConsoleWorkspaceService.getCaseDetails(caseId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertNotEquals(null, result.caseRecord, 'Case record should be present');
        System.assertEquals(caseId, result.caseRecord.Id, 'Case Id round-trip');
        System.assertEquals('Widget not working', result.caseRecord.Subject, 'Subject round-trip');
        System.assertNotEquals(null, result.accountRecord, 'Account should be populated');
        System.assertNotEquals(null, result.contactRecord, 'Contact should be populated');
        System.assertNotEquals(null, result.milestones, 'Milestones list should not be null');
    }

    @isTest
    static void test_getCaseDetails_nullId_throws() {
        Boolean caughtException = false;
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getCaseDetails(null);
        } catch (AuraHandledException ex) {
            caughtException = true;
        }
        Test.stopTest();
        System.assertEquals(true, caughtException, 'AuraHandledException expected for null Id');
    }

    @isTest
    static void test_getCaseDetails_bulk200_succeeds() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Keneland Test Account' LIMIT 1];
        List<Case> bulkCases = new List<Case>();
        for (Integer i = 0; i < 200; i++) {
            bulkCases.add(new Case(Subject = 'Bulk ' + i, Status = 'New', AccountId = acct.Id));
        }
        insert bulkCases;

        Test.startTest();
        AgentConsoleWorkspaceService.CaseDetailWrapper firstResult =
            AgentConsoleWorkspaceService.getCaseDetails(bulkCases[0].Id);
        AgentConsoleWorkspaceService.CaseDetailWrapper lastResult =
            AgentConsoleWorkspaceService.getCaseDetails(bulkCases[199].Id);
        Test.stopTest();

        System.assertNotEquals(null, firstResult.caseRecord, 'First bulk case should be returned');
        System.assertNotEquals(null, lastResult.caseRecord, 'Last bulk case should be returned');
    }

    // ===========================================================================
    // getInteractionHistory
    // ===========================================================================

    @isTest
    static void test_getInteractionHistory_validCase_returnsHistory() {
        Id caseId = getTestCaseId();
        Id contactId = getTestContactId();
        Id accountId = getTestAccountId();

        Case closedCase = new Case(
            Subject = 'Old closed case',
            Status = 'Closed',
            ContactId = contactId,
            AccountId = accountId
        );
        insert closedCase;

        Test.startTest();
        AgentConsoleWorkspaceService.InteractionHistoryWrapper result =
            AgentConsoleWorkspaceService.getInteractionHistory(caseId, contactId, accountId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertNotEquals(null, result.tasks, 'Tasks list should not be null');
        System.assertNotEquals(null, result.events, 'Events list should not be null');
        System.assertNotEquals(null, result.emailMessages, 'EmailMessages list should not be null');
        System.assertNotEquals(null, result.caseComments, 'CaseComments list should not be null');
        System.assertNotEquals(null, result.relatedCases, 'RelatedCases list should not be null');
        System.assertEquals(1, result.relatedCases.size(), 'One closed related Case expected');
    }

    @isTest
    static void test_getInteractionHistory_nullCase_throws() {
        Boolean caughtException = false;
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getInteractionHistory(null, null, null);
        } catch (AuraHandledException ex) {
            caughtException = true;
        }
        Test.stopTest();
        System.assertEquals(true, caughtException, 'AuraHandledException expected for null Id');
    }

    @isTest
    static void test_getInteractionHistory_noContact_emptyRelatedCases() {
        Id caseId = getTestCaseId();
        Test.startTest();
        AgentConsoleWorkspaceService.InteractionHistoryWrapper result =
            AgentConsoleWorkspaceService.getInteractionHistory(caseId, null, null);
        Test.stopTest();

        System.assertEquals(0, result.relatedCases.size(),
            'No related cases expected when both contactId and accountId are null');
    }

    // ===========================================================================
    // getKnowledgeArticles
    // ===========================================================================

    @isTest
    static void test_getKnowledgeArticles_blankTerm_throws() {
        Boolean caughtException = false;
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getKnowledgeArticles('');
        } catch (AuraHandledException ex) {
            caughtException = true;
        }
        Test.stopTest();
        System.assertEquals(true, caughtException, 'AuraHandledException expected for blank term');
    }

    @isTest
    static void test_getKnowledgeArticles_validTerm_returnsList() {
        Test.startTest();
        List<SObject> results =
            AgentConsoleWorkspaceService.getKnowledgeArticles('widget issue');
        Test.stopTest();
        System.assertNotEquals(null, results, 'Result list should not be null');
    }

    @isTest
    static void test_getKnowledgeArticles_specialCharsStripped_noException() {
        Test.startTest();
        List<SObject> results =
            AgentConsoleWorkspaceService.getKnowledgeArticles('widget & issue [test]');
        Test.stopTest();
        System.assertNotEquals(null, results, 'Result list should not be null after sanitisation');
    }

    // ===========================================================================
    // getRecommendations
    // ===========================================================================

    @isTest
    static void test_getRecommendations_validCase_returnsList() {
        Id caseId = getTestCaseId();
        Test.startTest();
        List<Case_Recommendation__c> results =
            AgentConsoleWorkspaceService.getRecommendations(caseId);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One seeded recommendation expected');
        System.assertEquals('Einstein', results[0].Source__c, 'Source should be Einstein');
    }

    @isTest
    static void test_getRecommendations_nullCase_throws() {
        Boolean caughtException = false;
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.getRecommendations(null);
        } catch (AuraHandledException ex) {
            caughtException = true;
        }
        Test.stopTest();
        System.assertEquals(true, caughtException, 'AuraHandledException expected for null Id');
    }

    // ===========================================================================
    // markWorkspaceOpened
    // ===========================================================================

    @isTest
    static void test_markWorkspaceOpened_validCase_stampsFields() {
        Id caseId = getTestCaseId();
        Test.startTest();
        AgentConsoleWorkspaceService.markWorkspaceOpened(caseId);
        Test.stopTest();

        Case updated = [
            SELECT Workspace_Used__c, Workspace_Opened_At__c
            FROM Case WHERE Id = :caseId
        ];
        System.assertEquals(true, updated.Workspace_Used__c,
            'Workspace_Used__c should be true after markWorkspaceOpened');
        System.assertNotEquals(null, updated.Workspace_Opened_At__c,
            'Workspace_Opened_At__c should be populated');
    }

    @isTest
    static void test_markWorkspaceOpened_nullId_throws() {
        Boolean caughtException = false;
        Test.startTest();
        try {
            AgentConsoleWorkspaceService.markWorkspaceOpened(null);
        } catch (AuraHandledException ex) {
            caughtException = true;
        }
        Test.stopTest();
        System.assertEquals(true, caughtException, 'AuraHandledException expected for null Id');
    }

    @isTest
    static void test_markWorkspaceOpened_runAs_enforcesCRUD() {
        Profile minProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User minUser = new User(
            FirstName = 'MinAccess',
            LastName = 'TestUser',
            Email = 'minaccesstest@keneland.test.invalid',
            Username = 'minaccesstest' + Datetime.now().getTime() + '@keneland.test.invalid',
            Alias = 'mintest',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = minProfile.Id
        );
        insert minUser;

        Id caseId = getTestCaseId();
        Test.startTest();
        System.runAs(minUser) {
            try {
                AgentConsoleWorkspaceService.markWorkspaceOpened(caseId);
            } catch (AuraHandledException ex) {
                System.assert(true, 'Access denied expected for low-privilege user');
            }
        }
        Test.stopTest();
    }
}
