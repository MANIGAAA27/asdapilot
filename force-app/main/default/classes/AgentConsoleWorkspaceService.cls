/**
 * @file              AgentConsoleWorkspaceService.cls
 * @description       Provides data aggregation and retrieval for the agentConsoleWorkspace
 *                    LWC. Consolidates Case core data, related Account/Contact, activity
 *                    history, knowledge articles, SLA milestones, and AI recommendations
 *                    into a minimal number of SOQL queries per invocation (within the
 *                    10-query budget defined in the LLD).
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-24
 * @lastModified      2026-06-24
 * @group             AgentConsoleWorkspace
 *
 * @dependencies      (none in this changeset)
 * @calledBy          agentConsoleWorkspace (LWC — via @AuraEnabled methods)
 * @testClass         AgentConsoleWorkspaceServiceTest
 *
 * @see               LLD-AgentConsoleWorkspace (Feature: Agent Console Workspace)
 * @project           Agent Console Workspace
 * @lld               LLD-AgentConsoleWorkspace
 */

// MODIFIED 2026-06-24 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
/**
 * Service layer for the Agent Console Workspace.
 *
 * Responsibilities:
 *   - Return a complete CaseContextWrapper with nested Account, Contact, Milestone,
 *     and Recommendation data in a single AuraEnabled call.
 *   - Return prior interaction history (recent closed Cases, EmailMessage, Task).
 *   - Return matching knowledge articles via dynamic SOSL (guarded for orgs
 *     without Salesforce Knowledge enabled).
 *   - Mark workspace usage by updating Case.Workspace_Used__c and
 *     Case.Workspace_Opened_At__c.
 *
 * Governor limits: no more than 10 SOQL queries per getCaseContext() invocation;
 * row caps enforced via LIMIT clauses (max 5,000 rows per the LLD constraint).
 *
 * @testClass AgentConsoleWorkspaceServiceTest
 */
public with sharing class AgentConsoleWorkspaceService {

    // -------------------------------------------------------------------------
    // Inner wrapper classes (defined in this file — NOT separate .cls files)
    // -------------------------------------------------------------------------

    /** Aggregated context returned to the LWC in a single round-trip. */
    public class CaseContextWrapper {
        @AuraEnabled public Case caseRecord { get; set; }
        @AuraEnabled public Account accountRecord { get; set; }
        @AuraEnabled public Contact contactRecord { get; set; }
        @AuraEnabled public List<CaseMilestone> milestones { get; set; }
        @AuraEnabled public List<Case_Recommendation__c> recommendations { get; set; }
    }

    /** Wrapper for previous customer interactions. */
    public class InteractionsWrapper {
        @AuraEnabled public List<Case> priorCases { get; set; }
        @AuraEnabled public List<EmailMessage> emails { get; set; }
        @AuraEnabled public List<Task> tasks { get; set; }
    }

    /**
     * Lightweight knowledge article wrapper. Used instead of KnowledgeArticleVersion
     * so the class compiles in orgs where Salesforce Knowledge is not enabled.
     */
    public class KnowledgeArticleResult {
        @AuraEnabled public String articleId { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String summary { get; set; }
        @AuraEnabled public String urlName { get; set; }
    }

    // -------------------------------------------------------------------------
    // Public AuraEnabled methods
    // -------------------------------------------------------------------------

    /**
     * Returns a consolidated CaseContextWrapper containing the Case with its
     * related Account, Contact, active CaseMilestones, and AI Recommendations.
     * Designed for the initial workspace load — all data in one call.
     *
     * @param  caseId  The Id of the Case record currently displayed on the page.
     * @return CaseContextWrapper populated with all related data. Never returns null.
     * @throws AuraHandledException when caseId is null or Case is not found.
     *
     * @calledBy agentConsoleWorkspace LWC (connectedCallback)
     * @testMethods test_getCaseContext_validCase_returnsWrapper,
     *              test_getCaseContext_blankId_throws,
     *              test_getCaseContext_bulkStability_200Cases
     */
    @AuraEnabled(cacheable=true)
    public static CaseContextWrapper getCaseContext(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        // Query 1 — Case core fields
        List<Case> cases = [
            SELECT Id, CaseNumber, Status, Priority, Origin, Subject, Description,
                   IsClosed, ClosedDate, IsEscalated, CreatedDate, OwnerId,
                   ContactId, AccountId,
                   Workspace_Used__c, Workspace_Opened_At__c, Resolution_Time_Minutes__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            throw new AuraHandledException('Case not found for Id: ' + caseId);
        }

        Case caseRecord = cases[0];
        CaseContextWrapper wrapper = new CaseContextWrapper();
        wrapper.caseRecord = caseRecord;

        // Query 2 — Account (only if linked)
        if (caseRecord.AccountId != null) {
            List<Account> accounts = [
                SELECT Id, Name, Type, Industry, Phone, SLA__c, SLAExpirationDate__c
                FROM Account
                WHERE Id = :caseRecord.AccountId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            wrapper.accountRecord = accounts.isEmpty() ? null : accounts[0];
        }

        // Query 3 — Contact (only if linked)
        if (caseRecord.ContactId != null) {
            List<Contact> contacts = [
                SELECT Id, Name, Email, Phone, MobilePhone, Title, Department
                FROM Contact
                WHERE Id = :caseRecord.ContactId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            wrapper.contactRecord = contacts.isEmpty() ? null : contacts[0];
        }

        // Query 4 — Active CaseMilestones (CaseMilestone is a standard Service Cloud object)
        wrapper.milestones = [
            SELECT Id, MilestoneTypeId, MilestoneType.Name, TargetDate,
                   IsCompleted, CompletionDate, IsViolated, ElapsedTimeInMins
            FROM CaseMilestone
            WHERE CaseId = :caseId
              AND IsCompleted = false
            WITH SECURITY_ENFORCED
            ORDER BY TargetDate ASC
            LIMIT 10
        ];

        // Query 5 — AI Recommendations
        wrapper.recommendations = [
            SELECT Id, Name, Recommendation_Text__c, Confidence_Score__c,
                   Resolution_Category__c, CreatedDate
            FROM Case_Recommendation__c
            WHERE Case__c = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY Confidence_Score__c DESC NULLS LAST
            LIMIT 5
        ];

        return wrapper;
    }

    /**
     * Returns previous interaction history for the customer associated with a Case.
     * Retrieves recent closed Cases for the same Contact, plus latest EmailMessages
     * and Tasks on the current Case.
     *
     * @param  caseId     The active Case Id.
     * @param  contactId  The Contact Id from the Case (may be null).
     * @return InteractionsWrapper with priorCases, emails, and tasks.
     *
     * @calledBy agentConsoleWorkspace LWC (lazy-loaded interactions panel)
     * @testMethods test_getInteractions_withContact_returnsPriorCases,
     *              test_getInteractions_noContact_returnsEmptyPriorCases
     */
    @AuraEnabled(cacheable=true)
    public static InteractionsWrapper getInteractions(Id caseId, Id contactId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        InteractionsWrapper wrapper = new InteractionsWrapper();

        // Query 6 — Prior closed Cases for the same Contact (up to 10)
        if (contactId != null) {
            wrapper.priorCases = [
                SELECT Id, CaseNumber, Subject, Status, Priority,
                       ClosedDate, CreatedDate, Origin, Description
                FROM Case
                WHERE ContactId = :contactId
                  AND IsClosed = true
                  AND Id != :caseId
                WITH SECURITY_ENFORCED
                ORDER BY ClosedDate DESC NULLS LAST
                LIMIT 10
            ];
        } else {
            wrapper.priorCases = new List<Case>();
        }

        // Query 7 — Latest EmailMessages on this Case (up to 20)
        wrapper.emails = [
            SELECT Id, Subject, FromAddress, ToAddress, TextBody, MessageDate, Incoming
            FROM EmailMessage
            WHERE ParentId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY MessageDate DESC
            LIMIT 20
        ];

        // Query 8 — Latest Tasks on this Case (up to 20)
        wrapper.tasks = [
            SELECT Id, Subject, Status, Priority, ActivityDate, Description,
                   OwnerId, Owner.Name
            FROM Task
            WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 20
        ];

        return wrapper;
    }

    /**
     * Searches for published knowledge articles relevant to the Case subject.
     * Uses dynamic SOSL guarded by a Schema describe check so the class
     * compiles and runs in orgs where Salesforce Knowledge is not enabled.
     * Returns List<KnowledgeArticleResult> wrapper (not KnowledgeArticleVersion)
     * to avoid compile-time failures on orgs without the Knowledge feature.
     *
     * @param  searchTerm  The search string (typically derived from Case.Subject).
     * @return List of KnowledgeArticleResult wrappers. Empty when Knowledge is
     *         not enabled or no articles match.
     *
     * @calledBy agentConsoleWorkspace LWC (lazy-loaded knowledge panel)
     * @testMethods test_searchKnowledge_blankTerm_returnsEmpty,
     *              test_searchKnowledge_nullTerm_returnsEmpty,
     *              test_searchKnowledge_validTerm_doesNotThrow
     */
    @AuraEnabled(cacheable=true)
    public static List<KnowledgeArticleResult> searchKnowledge(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return new List<KnowledgeArticleResult>();
        }

        // Guard: return empty if Knowledge is not enabled in this org
        if (!Schema.getGlobalDescribe().containsKey('KnowledgeArticleVersion')) {
            return new List<KnowledgeArticleResult>();
        }

        String sanitized = String.escapeSingleQuotes(searchTerm.trim());
        if (sanitized.length() > 100) {
            sanitized = sanitized.left(100);
        }

        String soslQuery =
            'FIND \'' + sanitized + '\'' +
            ' IN ALL FIELDS' +
            ' RETURNING KnowledgeArticleVersion(' +
            '  Id, Title, Summary, UrlName' +
            '  WHERE PublishStatus = \'Online\'' +
            '  AND Language = \'' + String.escapeSingleQuotes(UserInfo.getLanguage()) + '\'' +
            ')' +
            ' LIMIT 10';

        List<List<SObject>> soslResults = Search.query(soslQuery);
        List<KnowledgeArticleResult> results = new List<KnowledgeArticleResult>();

        if (!soslResults.isEmpty()) {
            for (SObject obj : soslResults[0]) {
                KnowledgeArticleResult r = new KnowledgeArticleResult();
                r.articleId = (String) obj.get('Id');
                r.title     = (String) obj.get('Title');
                r.summary   = (String) obj.get('Summary');
                r.urlName   = (String) obj.get('UrlName');
                results.add(r);
            }
        }

        return results;
    }

    /**
     * Marks the workspace as used by setting Case.Workspace_Used__c = true
     * and stamping Case.Workspace_Opened_At__c with the current datetime.
     * Called imperatively from the LWC connectedCallback. Uses a without-sharing
     * inner updater so agents who access Cases via sharing rules can still stamp
     * the usage fields. No cacheable — performs DML.
     *
     * @param  caseId  The Id of the Case being viewed.
     *
     * @calledBy agentConsoleWorkspace LWC (connectedCallback, imperative)
     * @testMethods test_markWorkspaceUsed_setsFields,
     *              test_markWorkspaceUsed_blankId_throws
     */
    @AuraEnabled
    public static void markWorkspaceUsed(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }
        new WorkspaceUsageUpdater().updateUsage(caseId);
    }

    // -------------------------------------------------------------------------
    // Inner class: without sharing updater for Workspace_Used__c
    // -------------------------------------------------------------------------

    /**
     * Updates Workspace_Used__c and Workspace_Opened_At__c without sharing
     * so that agents who have edit rights via a sharing rule (but whose OWD
     * is Private) can still stamp the usage fields on Case open.
     * Inner classes in Apex cannot have static methods; updateUsage is an
     * instance method called via new WorkspaceUsageUpdater().updateUsage().
     */
    private without sharing class WorkspaceUsageUpdater {
        /** Updates the two workspace tracking fields for the given Case Id. */
        void updateUsage(Id caseId) {
            Case caseToUpdate = new Case(
                Id = caseId,
                Workspace_Used__c = true,
                Workspace_Opened_At__c = Datetime.now()
            );
            try {
                update caseToUpdate;
            } catch (DmlException ex) {
                throw new AuraHandledException(
                    'Unable to mark workspace usage: ' + ex.getMessage()
                );
            }
        }
    }
}
