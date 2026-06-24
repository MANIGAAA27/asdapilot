/**
 * @file              AgentConsoleWorkspaceService.cls
 * @description       Server-side data aggregation service for the Agent Console
 *                    Workspace LWC. Provides @AuraEnabled methods to retrieve
 *                    Case details, related Account/Contact, prior interactions,
 *                    Case Milestones, AI recommendations, and Knowledge search.
 *                    Also exposes a write method to stamp workspace-usage fields.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-24
 * @lastModified      2026-06-24
 * @group             AgentConsoleWorkspace
 *
 * @dependencies      (none in this changeset)
 * @calledBy          agentConsoleWorkspace (LWC — imperative Apex calls)
 * @testClass         AgentConsoleWorkspaceServiceTest
 *
 * @see               LLD-AgentConsoleWorkspace (Feature: Agent Console Workspace)
 */

// MODIFIED 2026-06-24 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
/**
 * Service layer for the Agent Console Workspace feature.
 *
 * Responsibilities:
 *   - Aggregate Case + Account + Contact data in a single @AuraEnabled call.
 *   - Retrieve CaseMilestone records for SLA countdown rendering.
 *   - Query prior interactions (Task, EmailMessage, closed Cases by ContactId).
 *   - Surface Case_Recommendation__c records for AI panel display.
 *   - Perform dynamic SOSL search over Knowledge for the Knowledge panel.
 *   - Stamp Workspace_Used__c and Workspace_Opened_At__c on first open.
 *
 * Governor limits: max 10 SOQL queries per public method; rows capped at
 * 5 000 per query. Read methods are @AuraEnabled(cacheable=true).
 *
 * @testClass AgentConsoleWorkspaceServiceTest
 */
public with sharing class AgentConsoleWorkspaceService {

    // ─── Inner Wrapper Classes ────────────────────────────────────────────────

    /** Carries Case + Account + Contact + Milestones + Recommendations. */
    public class CaseDataWrapper {
        @AuraEnabled public Case caseRecord { get; set; }
        @AuraEnabled public Account accountRecord { get; set; }
        @AuraEnabled public Contact contactRecord { get; set; }
        @AuraEnabled public List<CaseMilestone> milestones { get; set; }
        @AuraEnabled public List<Case_Recommendation__c> recommendations { get; set; }
    }

    /** Carries email, task, and prior-case interaction lists. */
    public class InteractionWrapper {
        @AuraEnabled public List<EmailMessage> emails { get; set; }
        @AuraEnabled public List<Task> tasks { get; set; }
        @AuraEnabled public List<Case> priorCases { get; set; }
    }

    /** Carries dynamic SOSL Knowledge results and optional error message. */
    public class KnowledgeResultWrapper {
        @AuraEnabled public List<SObject> articles { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    // ─── Public Read Methods ──────────────────────────────────────────────────

    /**
     * Returns a CaseDataWrapper containing the Case, its related Account and
     * Contact, active CaseMilestone records, and AI recommendations. Designed
     * to be called once on LWC component mount to minimise round trips.
     *
     * @param  caseId   Id of the active Case record. Must not be null.
     * @return CaseDataWrapper with all aggregated data. Never returns null.
     * @throws AuraHandledException on null caseId or SOQL errors.
     *
     * @calledBy    agentConsoleWorkspace LWC (connectedCallback imperative call)
     * @testMethods test_getCaseData_returnsCase,
     *              test_getCaseData_nullId_throws,
     *              test_getCaseData_withRecommendations
     */
    @AuraEnabled(cacheable=true)
    public static CaseDataWrapper getCaseData(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        List<Case> caseList = [
            SELECT Id, CaseNumber, Status, Priority, Origin, Subject,
                   Description, IsClosed, ClosedDate, IsEscalated,
                   CreatedDate, AccountId, ContactId,
                   Workspace_Used__c, Workspace_Opened_At__c,
                   Resolution_Time_Minutes__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (caseList.isEmpty()) {
            throw new AuraHandledException('Case not found: ' + caseId);
        }

        Case caseRecord = caseList[0];
        CaseDataWrapper wrapper = new CaseDataWrapper();
        wrapper.caseRecord = caseRecord;
        wrapper.milestones = new List<CaseMilestone>();
        wrapper.recommendations = new List<Case_Recommendation__c>();

        if (caseRecord.AccountId != null) {
            List<Account> accounts = [
                SELECT Id, Name, Industry, Phone, Website
                FROM Account
                WHERE Id = :caseRecord.AccountId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            wrapper.accountRecord = accounts.isEmpty() ? null : accounts[0];
        }

        if (caseRecord.ContactId != null) {
            List<Contact> contacts = [
                SELECT Id, Name, Email, Phone, Title, Department
                FROM Contact
                WHERE Id = :caseRecord.ContactId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            wrapper.contactRecord = contacts.isEmpty() ? null : contacts[0];
        }

        wrapper.milestones = [
            SELECT Id, CaseId, MilestoneTypeId, TargetDate,
                   IsCompleted, IsViolated, CompletionDate
            FROM CaseMilestone
            WHERE CaseId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY TargetDate ASC
            LIMIT 50
        ];

        wrapper.recommendations = [
            SELECT Id, Name, Case__c, Recommendation_Text__c,
                   Recommended_Resolution__c, Confidence_Score__c,
                   Recommendation_Status__c
            FROM Case_Recommendation__c
            WHERE Case__c = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY Confidence_Score__c DESC NULLS LAST
            LIMIT 10
        ];

        return wrapper;
    }

    /**
     * Returns prior interactions for the case: recent EmailMessages, Tasks,
     * and closed Cases related to the same Contact.
     *
     * @param  caseId     Id of the active Case record.
     * @param  contactId  Id of the Contact associated with the Case (may be null).
     * @return InteractionWrapper with email, task, and prior-case lists.
     * @throws AuraHandledException on null caseId.
     *
     * @calledBy    agentConsoleWorkspace LWC (lazy-load on interaction panel expand)
     * @testMethods test_getPreviousInteractions_withContact,
     *              test_getPreviousInteractions_noContact,
     *              test_getPreviousInteractions_nullId_throws
     */
    @AuraEnabled(cacheable=true)
    public static InteractionWrapper getPreviousInteractions(Id caseId, Id contactId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        InteractionWrapper wrapper = new InteractionWrapper();
        wrapper.emails = new List<EmailMessage>();
        wrapper.tasks = new List<Task>();
        wrapper.priorCases = new List<Case>();

        wrapper.emails = [
            SELECT Id, Subject, FromAddress, ToAddress, TextBody,
                   MessageDate, Status
            FROM EmailMessage
            WHERE ParentId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY MessageDate DESC
            LIMIT 20
        ];

        wrapper.tasks = [
            SELECT Id, Subject, Status, Priority, ActivityDate,
                   Description, OwnerId
            FROM Task
            WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 20
        ];

        if (contactId != null) {
            wrapper.priorCases = [
                SELECT Id, CaseNumber, Subject, Status, Priority,
                       ClosedDate, Origin, Resolution_Time_Minutes__c
                FROM Case
                WHERE ContactId = :contactId
                  AND IsClosed = true
                  AND Id != :caseId
                WITH SECURITY_ENFORCED
                ORDER BY ClosedDate DESC NULLS LAST
                LIMIT 10
            ];
        }

        return wrapper;
    }

    /**
     * Searches for Knowledge articles relevant to the Case using dynamic SOSL
     * to avoid compile-time dependency on KnowledgeArticleVersion (graceful
     * degradation when Knowledge is not enabled in the org).
     *
     * @param  searchTerm  Subject or keywords to search. Must not be blank.
     * @return KnowledgeResultWrapper with up to 10 matching articles.
     *
     * @calledBy    agentConsoleWorkspace LWC (Knowledge panel lazy-load)
     * @testMethods test_searchKnowledge_returnsWrapper,
     *              test_searchKnowledge_blankTerm_returnsEmpty
     */
    @AuraEnabled(cacheable=true)
    public static KnowledgeResultWrapper searchKnowledge(String searchTerm) {
        KnowledgeResultWrapper result = new KnowledgeResultWrapper();
        result.articles = new List<SObject>();
        result.errorMessage = null;

        if (String.isBlank(searchTerm)) {
            return result;
        }

        String sanitisedTerm = String.escapeSingleQuotes(searchTerm.trim());
        if (sanitisedTerm.length() < 2) {
            return result;
        }

        try {
            String soslQuery = 'FIND \'' + sanitisedTerm.replace('\'', '\\\'')
                + '\' IN ALL FIELDS RETURNING KnowledgeArticleVersion('
                + 'Id, Title, Summary, UrlName, ArticleNumber, PublishStatus, Language '
                + 'WHERE PublishStatus = \'Online\' LIMIT 10)';
            List<List<SObject>> soslResults = Search.query(soslQuery);

            if (!soslResults.isEmpty() && !soslResults[0].isEmpty()) {
                result.articles.addAll(soslResults[0]);
            }
        } catch (Exception ex) {
            result.errorMessage = 'Knowledge search unavailable: ' + ex.getMessage();
        }

        return result;
    }

    // ─── Public Write Method ─────────────────────────────────────────────────

    /**
     * Stamps Workspace_Used__c = true and Workspace_Opened_At__c = NOW() on
     * the Case when an agent first opens the workspace. Idempotent — no-ops
     * if Workspace_Used__c is already true.
     *
     * @param  caseId  Id of the Case to update. Must not be null.
     * @throws AuraHandledException on null caseId or DML failure.
     *
     * @calledBy    agentConsoleWorkspace LWC (connectedCallback, non-cacheable)
     * @testMethods test_markWorkspaceOpened_stampsFields,
     *              test_markWorkspaceOpened_idempotent,
     *              test_markWorkspaceOpened_nullId_throws
     */
    @AuraEnabled
    public static void markWorkspaceOpened(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        List<Case> existing = [
            SELECT Id, Workspace_Used__c, Workspace_Opened_At__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (existing.isEmpty()) {
            throw new AuraHandledException('Case not found: ' + caseId);
        }

        Case caseToUpdate = existing[0];
        if (caseToUpdate.Workspace_Used__c != true) {
            caseToUpdate.Workspace_Used__c = true;
            caseToUpdate.Workspace_Opened_At__c = Datetime.now();
            try {
                update caseToUpdate;
            } catch (DmlException ex) {
                throw new AuraHandledException(
                    'Failed to update workspace tracking: ' + ex.getMessage()
                );
            }
        }
    }
}
