/**
 * @file              AgentConsoleWorkspaceService.cls
 * @description       Service layer for the agentConsoleWorkspace LWC. Aggregates Case,
 *                    Account/Contact, Milestones, AI Recommendations, interaction history
 *                    (EmailMessage, Task, prior Cases), and Knowledge article search.
 *                    Exposes markWorkspaceOpened to stamp tracking fields on Case.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-27
 * @lastModified      2026-06-27
 * @group             AgentConsoleWorkspace
 * @project           Agent Console Workspace
 * @lld               LLD-AgentConsoleWorkspace
 *
 * @dependencies      (none)
 * @calledBy          agentConsoleWorkspace (LWC)
 * @testClass         AgentConsoleWorkspaceServiceTest
 */
public with sharing class AgentConsoleWorkspaceService {

    // ─────────────────────────────────────────────────────────────────────────
    // Inner wrapper classes serialised to LWC via @AuraEnabled
    // ─────────────────────────────────────────────────────────────────────────

    /** Top-level workspace payload returned by getCaseWorkspaceData. */
    public class CaseWorkspaceData {
        @AuraEnabled public Case                          caseRecord       { get; set; }
        @AuraEnabled public Account                       accountRecord    { get; set; }
        @AuraEnabled public Contact                       contactRecord    { get; set; }
        @AuraEnabled public List<Case_Recommendation__c>  recommendations  { get; set; }
        /** Serialised milestone data (Id, TargetDate, IsCompleted, IsViolated). */
        @AuraEnabled public List<Map<String, Object>>     milestones       { get; set; }
    }

    /** Lazy-loaded interaction history returned by getPreviousInteractions. */
    public class InteractionData {
        @AuraEnabled public List<EmailMessage>   emails        { get; set; }
        @AuraEnabled public List<Task>           tasks         { get; set; }
        @AuraEnabled public List<Case>           relatedCases  { get; set; }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Read-only methods (cacheable=true)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Fetches the complete workspace payload for the given Case: Case record,
     * parent Account/Contact, active Milestones (dynamic SOQL — Entitlements
     * may be disabled), and AI Recommendations.
     * Total static SOQL: up to 4 (Case, Account, Contact, Recommendations).
     *
     * @param  caseId  Id of the Case record. Must not be null.
     * @return CaseWorkspaceData wrapper.
     * @throws AuraHandledException when caseId is null or Case not found.
     *
     * @calledBy agentConsoleWorkspace (LWC)
     * @testMethods test_getCaseWorkspaceData_caseOnly,
     *              test_getCaseWorkspaceData_withAccountAndContact,
     *              test_getCaseWorkspaceData_returnsRecommendations,
     *              test_getCaseWorkspaceData_nullCaseId_throws,
     *              test_getCaseWorkspaceData_invalidId_throws
     */
    @AuraEnabled(cacheable=true)
    public static CaseWorkspaceData getCaseWorkspaceData(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case ID is required.');
        }

        CaseWorkspaceData result = new CaseWorkspaceData();
        result.milestones     = new List<Map<String, Object>>();
        result.recommendations = new List<Case_Recommendation__c>();

        // Query 1: Case core display fields.
        // Tracking fields (Workspace_Used__c, Workspace_Opened_At__c,
        // Resolution_Time_Minutes__c) are omitted here because they have no
        // FLS in fresh orgs until the permission set is applied — and
        // WITH SECURITY_ENFORCED would throw Insufficient Permissions.
        // These fields are written (not read) by markWorkspaceOpened().
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Description, Status, Priority, Origin,
                   IsClosed, ClosedDate, IsEscalated, CreatedDate, OwnerId,
                   ContactId, AccountId
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            throw new AuraHandledException('Case not found or access denied.');
        }
        result.caseRecord = cases[0];

        // Query 2: Account
        if (result.caseRecord.AccountId != null) {
            List<Account> accts = [
                SELECT Id, Name, Industry, Phone, BillingCity, BillingState, BillingCountry
                FROM Account
                WHERE Id = :result.caseRecord.AccountId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (!accts.isEmpty()) {
                result.accountRecord = accts[0];
            }
        }

        // Query 3: Contact
        if (result.caseRecord.ContactId != null) {
            List<Contact> cons = [
                SELECT Id, Name, Email, Phone, Title
                FROM Contact
                WHERE Id = :result.caseRecord.ContactId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (!cons.isEmpty()) {
                result.contactRecord = cons[0];
            }
        }

        // Dynamic SOQL for CaseMilestone (Entitlements may not be enabled)
        try {
            String milestoneQuery =
                'SELECT Id, MilestoneTypeId, TargetDate, IsCompleted, CompletionDate, IsViolated ' +
                'FROM CaseMilestone ' +
                'WHERE CaseId = :caseId AND IsCompleted = false ' +
                'ORDER BY TargetDate ASC LIMIT 5';
            List<SObject> rawMilestones = Database.query(milestoneQuery);
            for (SObject ms : rawMilestones) {
                Map<String, Object> m = new Map<String, Object>{
                    'Id'             => ms.get('Id'),
                    'MilestoneTypeId'=> ms.get('MilestoneTypeId'),
                    'TargetDate'     => ms.get('TargetDate'),
                    'IsCompleted'    => ms.get('IsCompleted'),
                    'CompletionDate' => ms.get('CompletionDate'),
                    'IsViolated'     => ms.get('IsViolated')
                };
                result.milestones.add(m);
            }
        } catch (Exception ex) {
            result.milestones = new List<Map<String, Object>>();
        }

        // Query 4: AI Recommendations
        // Case_Recommendation__c is a newly-deployed custom object whose FLS may not yet be
        // provisioned in a fresh org. Use stripInaccessible (strips inaccessible fields instead
        // of throwing) rather than WITH SECURITY_ENFORCED (throws QueryException on missing FLS).
        List<Case_Recommendation__c> rawRecs = [
            SELECT Id, Name, Case__c, Recommendation_Text__c,
                   Recommendation_Type__c, Confidence_Score__c, CreatedDate
            FROM Case_Recommendation__c
            WHERE Case__c = :caseId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        SObjectAccessDecision recsDecision =
            Security.stripInaccessible(AccessType.READABLE, rawRecs);
        result.recommendations =
            (List<Case_Recommendation__c>) recsDecision.getRecords();

        return result;
    }

    /**
     * Lazy-loads previous interaction history: EmailMessage, Task, and prior
     * closed Cases for the same Contact or Account.
     * Total SOQL: up to 3 (emails, tasks, relatedCases).
     *
     * @param  caseId     Id of the active Case.
     * @param  contactId  Id of the related Contact (may be null).
     * @param  accountId  Id of the related Account (may be null).
     * @return InteractionData wrapper.
     * @throws AuraHandledException when caseId is null.
     *
     * @calledBy agentConsoleWorkspace (LWC)
     * @testMethods test_getPreviousInteractions_returnsEmailsAndTasks,
     *              test_getPreviousInteractions_nullCaseId_throws,
     *              test_getPreviousInteractions_withContactId,
     *              test_getPreviousInteractions_withAccountId
     */
    @AuraEnabled(cacheable=true)
    public static InteractionData getPreviousInteractions(Id caseId, Id contactId, Id accountId) {
        if (caseId == null) {
            throw new AuraHandledException('Case ID is required.');
        }

        InteractionData result = new InteractionData();

        // Query 5: EmailMessage on Case
        result.emails = [
            SELECT Id, Subject, TextBody, FromAddress, ToAddress, MessageDate, Incoming, CreatedDate
            FROM EmailMessage
            WHERE ParentId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY MessageDate DESC NULLS LAST
            LIMIT 20
        ];

        // Query 6: Tasks related to Case
        result.tasks = [
            SELECT Id, Subject, Status, ActivityDate, Description, OwnerId, CreatedDate
            FROM Task
            WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 20
        ];

        // Query 7: Prior closed Cases (Contact first, Account as fallback)
        if (contactId != null) {
            result.relatedCases = [
                SELECT Id, CaseNumber, Subject, Status, Priority, ClosedDate, CreatedDate
                FROM Case
                WHERE ContactId = :contactId
                  AND IsClosed = true
                  AND Id != :caseId
                WITH SECURITY_ENFORCED
                ORDER BY ClosedDate DESC NULLS LAST
                LIMIT 10
            ];
        } else if (accountId != null) {
            result.relatedCases = [
                SELECT Id, CaseNumber, Subject, Status, Priority, ClosedDate, CreatedDate
                FROM Case
                WHERE AccountId = :accountId
                  AND IsClosed = true
                  AND Id != :caseId
                WITH SECURITY_ENFORCED
                ORDER BY ClosedDate DESC NULLS LAST
                LIMIT 10
            ];
        } else {
            result.relatedCases = new List<Case>();
        }

        return result;
    }

    /**
     * SOSL knowledge-article search returning up to 10 matching
     * KnowledgeArticleVersion records (online, current user language).
     * Returns an empty list for blank search terms.
     *
     * @param  searchTerm  Free-text search string. Blank is a no-op.
     * @return List of matching SObjects. Never null.
     *
     * @calledBy agentConsoleWorkspace (LWC)
     * @testMethods test_searchKnowledgeArticles_blank_returnsEmpty,
     *              test_searchKnowledgeArticles_validTerm_doesNotThrow
     */
    @AuraEnabled(cacheable=true)
    public static List<SObject> searchKnowledgeArticles(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return new List<SObject>();
        }
        try {
            String cleanTerm = searchTerm.trim();
            List<List<SObject>> results = Search.query(
                'FIND :cleanTerm IN ALL FIELDS ' +
                'RETURNING KnowledgeArticleVersion(' +
                '  Id, Title, Summary, UrlName ' +
                '  WHERE PublishStatus = \'Online\' AND Language = \'en_US\'' +
                ') LIMIT 10'
            );
            return results.isEmpty() ? new List<SObject>() : results[0];
        } catch (Exception ex) {
            throw new AuraHandledException('Knowledge search failed: ' + ex.getMessage());
        }
    }

    /**
     * Returns the first SLA_Config__mdt record with warning/critical threshold hours
     * for the SLA countdown timer in the LWC. Returns null when no record exists.
     *
     * @return SLA_Config__mdt or null.
     *
     * @calledBy agentConsoleWorkspace (LWC)
     * @testMethods test_getSlaConfig_returnsNullOrRecord
     */
    @AuraEnabled(cacheable=true)
    public static SLA_Config__mdt getSlaConfig() {
        List<SLA_Config__mdt> cfgs = [
            SELECT Warning_Threshold_Hours__c, Critical_Threshold_Hours__c
            FROM SLA_Config__mdt
            LIMIT 1
        ];
        return cfgs.isEmpty() ? null : cfgs[0];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Write methods (NOT cacheable — perform DML)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Stamps workspace-usage tracking fields on the Case when the LWC loads.
     * Sets Workspace_Used__c = true and Workspace_Opened_At__c = now().
     * Idempotent — re-opening the workspace refreshes the timestamp.
     *
     * @param  caseId  Id of the Case to update.
     * @throws AuraHandledException when caseId is null, CRUD fails, or DML fails.
     *
     * @calledBy agentConsoleWorkspace (LWC — connectedCallback)
     * @testMethods test_markWorkspaceOpened_setsFields,
     *              test_markWorkspaceOpened_nullCaseId_throws
     */
    @AuraEnabled
    public static void markWorkspaceOpened(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case ID is required.');
        }
        if (!Schema.sObjectType.Case.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Case.');
        }
        Case rec = new Case(
            Id = caseId,
            Workspace_Used__c = true,
            Workspace_Opened_At__c = System.now()
        );
        try {
            update rec;
        } catch (DmlException ex) {
            throw new AuraHandledException('Failed to update workspace tracking: ' + ex.getMessage());
        }
    }
}
