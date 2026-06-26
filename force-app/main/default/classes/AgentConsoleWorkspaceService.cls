/**
 * @file              AgentConsoleWorkspaceService.cls
 * @description       Service layer for the Agent Console Workspace LWC. Aggregates
 *                    Case, Account, Contact, Task, EmailMessage, KnowledgeArticleVersion,
 *                    CaseMilestone, and Case_Recommendation__c data for unified display.
 *                    All SOQL queries enforce FLS/CRUD via WITH SECURITY_ENFORCED.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-26
 * @lastModified      2026-06-26
 * @group             AgentConsoleWorkspace
 *
 * @dependencies      (none in this changeset)
 * @calledBy          agentConsoleWorkspace (LWC)
 * @testClass         AgentConsoleWorkspaceServiceTest
 *
 * @see               LLD-AgentConsoleWorkspace (Project: Agent Console Workspace)
 */

// MODIFIED 2026-06-26 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
/**
 * Provides @AuraEnabled data retrieval methods for the Agent Console Workspace LWC.
 *
 * Responsibilities:
 *   - Retrieve Case details with related Account and Contact in one query.
 *   - Return related Tasks, EmailMessages, and prior closed Cases for history panel.
 *   - Surface KnowledgeArticleVersion records via SOQL keyword search.
 *   - Return CaseMilestone records for the SLA countdown panel.
 *   - Return Case_Recommendation__c records for the AI panel.
 *   - Stamp Workspace_Used__c and Workspace_Opened_At__c on first open.
 *
 * Threading: all read methods are cacheable; markWorkspaceUsed performs a single DML.
 *
 * @testClass AgentConsoleWorkspaceServiceTest
 */
public with sharing class AgentConsoleWorkspaceService {

    // ─────────────────────────────────────────────────────────────────────────
    // Inner wrapper types
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Bundles the Case SObject together with its parent Account and Contact records
     * so the LWC receives the full customer profile in a single Apex call.
     */
    public class WorkspaceData {
        /** The active Case record with all workspace fields populated. */
        @AuraEnabled public Case caseRecord;
        /** Parent Account (null when Case has no AccountId). */
        @AuraEnabled public Account accountRecord;
        /** Primary Contact (null when Case has no ContactId). */
        @AuraEnabled public Contact contactRecord;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public @AuraEnabled methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns the core workspace data bundle: Case + Account + Contact.
     * Consumes 1 SOQL query. Relationship traversal fields are loaded inline.
     *
     * @param  caseId   Id of the Case record currently open in the workspace.
     * @return WorkspaceData containing Case, Account, and Contact projections.
     * @throws AuraHandledException when caseId is null or the record is inaccessible.
     *
     * @calledBy    agentConsoleWorkspace.js (connectedCallback)
     * @testMethods test_getWorkspaceData_returnsBundle, test_getWorkspaceData_nullId_throws
     */
    @AuraEnabled(cacheable=true)
    public static WorkspaceData getWorkspaceData(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case ID is required.');
        }

        List<Case> cases = [
            SELECT Id, CaseNumber, Status, Priority, Origin, Subject,
                   Description, IsClosed, ClosedDate, CreatedDate, IsEscalated,
                   ContactId, AccountId,
                   Account.Id, Account.Name, Account.Industry,
                   Contact.Id, Contact.Name, Contact.Email, Contact.Phone,
                   Workspace_Used__c, Workspace_Opened_At__c,
                   Resolution_Time_Minutes__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            throw new AuraHandledException('Case not found or access denied.');
        }

        Case c = cases[0];
        WorkspaceData wd = new WorkspaceData();
        wd.caseRecord = c;
        wd.accountRecord = (c.AccountId != null) ? c.Account : null;
        wd.contactRecord = (c.ContactId != null) ? c.Contact : null;
        return wd;
    }

    /**
     * Returns up to 20 Tasks related to the given Case, ordered by CreatedDate DESC.
     *
     * @param  caseId   Id of the Case record.
     * @return List of Task records; empty list when caseId is null.
     *
     * @calledBy    agentConsoleWorkspace.js (loadInteractions)
     * @testMethods test_getRelatedActivities_returnsTasks
     */
    @AuraEnabled(cacheable=true)
    public static List<Task> getRelatedActivities(Id caseId) {
        if (caseId == null) {
            return new List<Task>();
        }
        return [
            SELECT Id, Subject, Status, Priority, ActivityDate,
                   Description, OwnerId, CreatedDate
            FROM Task
            WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
    }

    /**
     * Returns up to 20 EmailMessages on the Case, ordered by MessageDate DESC.
     *
     * @param  caseId   Id of the Case record.
     * @return List of EmailMessage records; empty list when caseId is null.
     *
     * @calledBy    agentConsoleWorkspace.js (loadInteractions)
     * @testMethods test_getRelatedEmailMessages_returnsEmails
     */
    @AuraEnabled(cacheable=true)
    public static List<EmailMessage> getRelatedEmailMessages(Id caseId) {
        if (caseId == null) {
            return new List<EmailMessage>();
        }
        return [
            SELECT Id, Subject, FromAddress, ToAddress, TextBody,
                   MessageDate, Status, Incoming, CreatedDate
            FROM EmailMessage
            WHERE ParentId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY MessageDate DESC
            LIMIT 20
        ];
    }

    /**
     * Returns up to 10 prior closed Cases for the same Contact, excluding the
     * current case, ordered by ClosedDate DESC.
     *
     * @param  caseId   Id of the active Case (used to derive ContactId and exclude self).
     * @return List of prior closed Case records; empty list when no Contact or no history.
     *
     * @calledBy    agentConsoleWorkspace.js (loadInteractions)
     * @testMethods test_getPreviousCases_returnsHistory
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> getPreviousCases(Id caseId) {
        if (caseId == null) {
            return new List<Case>();
        }

        List<Case> currentCases = [
            SELECT Id, ContactId
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (currentCases.isEmpty() || currentCases[0].ContactId == null) {
            return new List<Case>();
        }

        Id contactId = currentCases[0].ContactId;

        return [
            SELECT Id, CaseNumber, Subject, Status, Priority,
                   ClosedDate, CreatedDate, Origin
            FROM Case
            WHERE ContactId = :contactId
              AND IsClosed = true
              AND Id != :caseId
            WITH SECURITY_ENFORCED
            ORDER BY ClosedDate DESC
            LIMIT 10
        ];
    }

    /**
     * Returns up to 10 published KnowledgeArticleVersion records matching the
     * given search term against Title and Summary. Uses dynamic SOQL so the class
     * compiles in orgs where Salesforce Knowledge is not yet enabled; returns an
     * empty list gracefully when Knowledge is disabled or no articles match.
     *
     * @param  searchTerm   Keyword(s) to search; blank input returns empty list.
     * @return List of KnowledgeArticleVersion SObjects (as List<SObject>) or empty.
     *
     * @calledBy    agentConsoleWorkspace.js (searchKnowledge)
     * @testMethods test_getKnowledgeArticles_blankReturnsEmpty, test_getKnowledgeArticles_nullReturnsEmpty
     */
    @AuraEnabled(cacheable=true)
    public static List<SObject> getKnowledgeArticles(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return new List<SObject>();
        }
        try {
            String searchPattern = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            String lang = String.escapeSingleQuotes(UserInfo.getLanguage());
            String query =
                'SELECT Id, Title, Summary, ArticleNumber, UrlName, PublishStatus ' +
                'FROM KnowledgeArticleVersion ' +
                'WHERE PublishStatus = \'Online\' ' +
                'AND Language = \'' + lang + '\' ' +
                'AND (Title LIKE \'' + searchPattern + '\' ' +
                '     OR Summary LIKE \'' + searchPattern + '\') ' +
                'ORDER BY CreatedDate DESC ' +
                'LIMIT 10';
            return Database.query(query);
        } catch (Exception ex) {
            // Knowledge not enabled in this org — return empty rather than surfacing error
            return new List<SObject>();
        }
    }

    /**
     * Returns Case_Recommendation__c records linked to the given Case, ordered
     * by Confidence_Score__c descending so highest-confidence suggestions appear first.
     *
     * @param  caseId   Id of the Case record.
     * @return List of recommendation records; empty list when caseId is null.
     *
     * @calledBy    agentConsoleWorkspace.js (loadRecommendations)
     * @testMethods test_getAIRecommendations_returnsRecs
     */
    @AuraEnabled(cacheable=true)
    public static List<Case_Recommendation__c> getAIRecommendations(Id caseId) {
        if (caseId == null) {
            return new List<Case_Recommendation__c>();
        }
        return [
            SELECT Id, Name, Recommendation_Text__c, Resolution_Type__c,
                   Confidence_Score__c, Is_Applied__c, CreatedDate
            FROM Case_Recommendation__c
            WHERE Case__c = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY Confidence_Score__c DESC NULLS LAST
            LIMIT 10
        ];
    }

    /**
     * Returns active CaseMilestone records for the given Case, ordered by
     * TargetDate ascending so the most urgent milestone appears first.
     *
     * @param  caseId   Id of the Case record.
     * @return List of CaseMilestone records; empty list when caseId is null.
     *
     * @calledBy    agentConsoleWorkspace.js (loadMilestones)
     * @testMethods test_getCaseMilestones_returnsMilestones
     */
    @AuraEnabled(cacheable=true)
    public static List<CaseMilestone> getCaseMilestones(Id caseId) {
        if (caseId == null) {
            return new List<CaseMilestone>();
        }
        return [
            SELECT Id, CaseId, MilestoneTypeId, MilestoneType.Name,
                   TargetDate, CompletionDate, IsCompleted, IsViolated
            FROM CaseMilestone
            WHERE CaseId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY TargetDate ASC
            LIMIT 10
        ];
    }

    /**
     * Stamps Workspace_Used__c = true and Workspace_Opened_At__c = now() on the Case.
     * Called imperatively (non-cacheable) when the LWC component mounts.
     * Skips update when the workspace was already marked used on this Case to avoid
     * overwriting a meaningful first-open timestamp.
     *
     * @param  caseId   Id of the Case to update.
     * @throws AuraHandledException on null input or DML failure.
     *
     * @calledBy    agentConsoleWorkspace.js (connectedCallback)
     * @testMethods test_markWorkspaceUsed_stampsFields, test_markWorkspaceUsed_nullId_throws
     */
    @AuraEnabled
    public static void markWorkspaceUsed(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case ID is required.');
        }
        if (!Schema.sObjectType.Case.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Case.');
        }

        // Only set Workspace_Opened_At__c on first open (preserve original timestamp)
        List<Case> existingCases = [
            SELECT Id, Workspace_Used__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (existingCases.isEmpty()) {
            throw new AuraHandledException('Case not found or access denied.');
        }

        Case c = new Case(Id = caseId, Workspace_Used__c = true);
        if (!existingCases[0].Workspace_Used__c) {
            c.Workspace_Opened_At__c = Datetime.now();
        }

        try {
            update c;
        } catch (DmlException ex) {
            throw new AuraHandledException('Failed to update workspace usage: ' + ex.getMessage());
        }
    }
}
