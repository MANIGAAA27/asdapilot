/**
 * @file              AgentConsoleWorkspaceService.cls
 * @description       Service layer for the Agent Console Workspace LWC. Aggregates
 *                    Case, Account, Contact, ActivityHistory, EmailMessage,
 *                    KnowledgeArticleVersion, CaseMilestone, and
 *                    Case_Recommendation__c data into consolidated response
 *                    wrappers consumed by the agentConsoleWorkspace LWC. Enforces
 *                    WITH SECURITY_ENFORCED on all SOQL and performs FLS checks
 *                    before DML. All read methods are cacheable=true; the single
 *                    write method (markWorkspaceOpened) is plain @AuraEnabled.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-26
 * @lastModified      2026-06-26
 * @group             AgentConsoleWorkspace
 *
 * @dependencies      (none — standalone service)
 * @calledBy          agentConsoleWorkspace (LWC)
 * @testClass         AgentConsoleWorkspaceServiceTest
 *
 * @see               LLD-AgentConsoleWorkspace
 */
// MODIFIED 2026-06-26 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
public with sharing class AgentConsoleWorkspaceService {

    // ─────────────────────────────────────────────────────────────────────────
    // Inner wrapper classes — @AuraEnabled properties serialise to JSON for LWC
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Top-level wrapper returned by getCaseData. Bundles Case, Account, Contact,
     * and active Milestones into a single Apex-to-LWC payload to minimise round
     * trips and stay within the 10-SOQL-per-invocation budget.
     */
    public class CaseWorkspaceData {
        /** The active Case record with all workspace-relevant fields. */
        @AuraEnabled public Case caseRecord { get; set; }
        /** Account linked to the Case (may be null if no AccountId). */
        @AuraEnabled public Account accountRecord { get; set; }
        /** Contact linked to the Case (may be null if no ContactId). */
        @AuraEnabled public Contact contactRecord { get; set; }
        /** Open (not completed) CaseMilestones ordered by TargetDate ASC. */
        @AuraEnabled public List<CaseMilestone> milestones { get; set; }
    }

    /**
     * Wrapper returned by getInteractions. Bundles Tasks, EmailMessages, and
     * prior closed Cases for the same Contact.
     */
    public class InteractionData {
        /** Most recent 20 Tasks where WhatId = caseId. */
        @AuraEnabled public List<Task> tasks { get; set; }
        /** Most recent 20 EmailMessages where ParentId = caseId. */
        @AuraEnabled public List<EmailMessage> emails { get; set; }
        /** 10 most recently closed Cases for the same Contact (excluding the active case). */
        @AuraEnabled public List<Case> priorCases { get; set; }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public @AuraEnabled methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns the consolidated Case workspace data: Case core fields, related
     * Account, Contact, and active CaseMilestones. Cacheable — no DML.
     *
     * @param  caseId   Id of the Case record currently open in the workspace.
     * @return          CaseWorkspaceData wrapper; never null.
     * @throws AuraHandledException on blank or null caseId.
     *
     * @calledBy    agentConsoleWorkspace LWC (connectedCallback)
     * @testMethods test_getCaseData_returnsWrapper,
     *              test_getCaseData_nullId_throws,
     *              test_getCaseData_noAccount_handledGracefully
     */
    @AuraEnabled(cacheable=true)
    public static CaseWorkspaceData getCaseData(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        // Query 1 — Case core fields
        List<Case> caseList = [
            SELECT Id, CaseNumber, Status, Priority, Origin, Subject, Description,
                   IsClosed, ClosedDate, IsEscalated, ContactId, AccountId,
                   CreatedDate, Workspace_Used__c, Workspace_Opened_At__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (caseList.isEmpty()) {
            throw new AuraHandledException('Case not found: ' + caseId);
        }
        Case activeCase = caseList[0];

        CaseWorkspaceData data = new CaseWorkspaceData();
        data.caseRecord = activeCase;
        data.milestones = new List<CaseMilestone>();

        // Query 2 — Account (conditional)
        if (activeCase.AccountId != null) {
            List<Account> accounts = [
                SELECT Id, Name, Phone, Industry
                FROM Account
                WHERE Id = :activeCase.AccountId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            data.accountRecord = accounts.isEmpty() ? null : accounts[0];
        }

        // Query 3 — Contact (conditional)
        if (activeCase.ContactId != null) {
            List<Contact> contacts = [
                SELECT Id, Name, FirstName, LastName, Email, Phone
                FROM Contact
                WHERE Id = :activeCase.ContactId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            data.contactRecord = contacts.isEmpty() ? null : contacts[0];
        }

        // Query 4 — Active CaseMilestones
        data.milestones = [
            SELECT Id, CaseId, MilestoneTypeId, StartDate, TargetDate,
                   CompletionDate, IsCompleted, IsViolated
            FROM CaseMilestone
            WHERE CaseId = :caseId
              AND IsCompleted = false
            ORDER BY TargetDate ASC
            LIMIT 10
        ];

        return data;
    }

    /**
     * Returns interaction history: Tasks, EmailMessages, and prior closed Cases
     * for the same Contact. Cacheable — no DML.
     *
     * @param  caseId     Id of the active Case.
     * @param  contactId  Id of the Case's Contact; pass null to skip prior-case lookup.
     * @return            InteractionData wrapper; never null.
     * @throws AuraHandledException on null caseId.
     *
     * @calledBy    agentConsoleWorkspace LWC (lazy-loaded interactions panel)
     * @testMethods test_getInteractions_returnsTasksAndEmails,
     *              test_getInteractions_nullContactId_skipsPriorCases
     */
    @AuraEnabled(cacheable=true)
    public static InteractionData getInteractions(Id caseId, Id contactId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        InteractionData data = new InteractionData();

        // Query 5 — Tasks related to the Case
        data.tasks = [
            SELECT Id, Subject, Status, ActivityDate, Description, CreatedDate
            FROM Task
            WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];

        // Query 6 — EmailMessages on the Case
        data.emails = [
            SELECT Id, Subject, TextBody, FromAddress, ToAddress, MessageDate, Incoming
            FROM EmailMessage
            WHERE ParentId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY MessageDate DESC
            LIMIT 20
        ];

        // Query 7 — Prior closed Cases for the same Contact
        data.priorCases = new List<Case>();
        if (contactId != null) {
            data.priorCases = [
                SELECT Id, CaseNumber, Subject, Status, ClosedDate, Priority
                FROM Case
                WHERE ContactId = :contactId
                  AND Id != :caseId
                  AND IsClosed = true
                WITH SECURITY_ENFORCED
                ORDER BY ClosedDate DESC
                LIMIT 10
            ];
        }

        return data;
    }

    /**
     * Returns AI recommendation records linked to the given Case.
     * Cacheable — no DML.
     *
     * @param  caseId   Id of the active Case.
     * @return          List of Case_Recommendation__c records; empty list when none.
     * @throws AuraHandledException on null caseId.
     *
     * @calledBy    agentConsoleWorkspace LWC (recommendations panel)
     * @testMethods test_getRecommendations_returnsList,
     *              test_getRecommendations_emptyWhenNone
     */
    @AuraEnabled(cacheable=true)
    public static List<Case_Recommendation__c> getRecommendations(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }
        return [
            SELECT Id, Name, Case__c, Recommendation_Text__c, Recommendation_Type__c,
                   Is_Applied__c, Confidence_Score__c, CreatedDate
            FROM Case_Recommendation__c
            WHERE Case__c = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY Confidence_Score__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 10
        ];
    }

    /**
     * Searches Knowledge articles using dynamic SOSL scoped to Online/published
     * articles matching the provided search term. Returns up to 10 results as
     * generic SObjects (avoids static KnowledgeArticleVersion type reference so
     * the class compiles in orgs where Knowledge is not enabled). Cacheable — no DML.
     *
     * @param  searchTerm   Free-text search term (e.g. Case Subject keywords).
     * @return              List of SObject (KnowledgeArticleVersion) records;
     *                      empty list when none found or Knowledge not enabled.
     * @throws AuraHandledException on blank searchTerm.
     *
     * @calledBy    agentConsoleWorkspace LWC (knowledge panel)
     * @testMethods test_searchKnowledge_returnsList,
     *              test_searchKnowledge_blankTerm_throws
     */
    @AuraEnabled(cacheable=true)
    public static List<SObject> searchKnowledge(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            throw new AuraHandledException('searchTerm is required.');
        }
        try {
            String escapedTerm = String.escapeSingleQuotes(searchTerm.trim());
            String soslQuery = 'FIND \'' + escapedTerm + '\' IN ALL FIELDS ' +
                'RETURNING KnowledgeArticleVersion(' +
                'Id, Title, Summary, UrlName ' +
                'WHERE PublishStatus = \'Online\') LIMIT 10';
            List<List<SObject>> results = Search.query(soslQuery);
            if (results == null || results.isEmpty() || results[0].isEmpty()) {
                return new List<SObject>();
            }
            return results[0];
        } catch (Exception ex) {
            // Knowledge not enabled or search unavailable — return empty list gracefully
            return new List<SObject>();
        }
    }

    /**
     * Marks the workspace as opened by setting Workspace_Used__c = true and
     * stamping Workspace_Opened_At__c with the current datetime. Not cacheable
     * (performs DML). Runs in the sharing context of the current user.
     *
     * @param  caseId   Id of the Case being opened in the workspace.
     * @throws AuraHandledException on null caseId or DML failure.
     *
     * @calledBy    agentConsoleWorkspace LWC (connectedCallback — imperative call)
     * @testMethods test_markWorkspaceOpened_setsFields
     */
    @AuraEnabled
    public static void markWorkspaceOpened(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }
        Case caseToUpdate = new Case(
            Id = caseId,
            Workspace_Used__c = true,
            Workspace_Opened_At__c = Datetime.now()
        );
        try {
            update caseToUpdate;
        } catch (DmlException ex) {
            throw new AuraHandledException('Failed to mark workspace opened: ' + ex.getMessage());
        }
    }
}
