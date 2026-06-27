/**
 * @file              AgentConsoleWorkspaceService.cls
 * @description       Provides data aggregation and retrieval for the Agent Console
 *                    Workspace LWC. Consolidates Case, Account, Contact, Activity,
 *                    EmailMessage, CaseMilestone, and Case_Recommendation__c data
 *                    into targeted @AuraEnabled methods that support lazy-loading of
 *                    workspace panels. Each method is scoped to a single data domain
 *                    to stay within the 10-SOQL-per-transaction budget.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-27
 * @lastModified      2026-06-27
 * @group             AgentConsoleWorkspace
 *
 * @dependencies      Case_Recommendation__c, CaseMilestone, Task, Event, EmailMessage
 * @calledBy          agentConsoleWorkspace (LWC)
 * @testClass         AgentConsoleWorkspaceServiceTest
 *
 * @see               LLD-AgentConsoleWorkspace (Feature: Agent Console Workspace)
 */
// MODIFIED 2026-06-27 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
public with sharing class AgentConsoleWorkspaceService {

    // ─── Inner Wrapper Classes ────────────────────────────────────────────────

    /**
     * Packages the Case record with its related Account and Contact for the
     * primary case panel. Avoids a second client-side round-trip.
     */
    public class CaseDataWrapper {
        @AuraEnabled public Case caseRecord    { get; set; }
        @AuraEnabled public Account accountRecord { get; set; }
        @AuraEnabled public Contact contactRecord { get; set; }
    }

    /**
     * Packages all interaction history (Tasks, Events, EmailMessages, prior Cases)
     * for the Previous Interactions panel.
     */
    public class InteractionsWrapper {
        @AuraEnabled public List<Task>         tasks      { get; set; }
        @AuraEnabled public List<Event>        events     { get; set; }
        @AuraEnabled public List<EmailMessage> emails     { get; set; }
        @AuraEnabled public List<Case>         priorCases { get; set; }
    }

    // ─── Public @AuraEnabled Methods ─────────────────────────────────────────

    /**
     * Returns the active Case with its related Account and Contact, including
     * all fields required by the workspace case-info and customer-profile panels.
     *
     * @param  caseId  Salesforce record Id of the Case to retrieve.
     * @return CaseDataWrapper containing Case, Account, and Contact. Never null.
     * @throws AuraHandledException when caseId is blank or no matching Case exists.
     *
     * @calledBy    agentConsoleWorkspace.js (connectedCallback — imperative)
     * @testMethods test_getCaseData_validId_returnsWrapper,
     *              test_getCaseData_blankId_throwsException,
     *              test_getCaseData_invalidId_throwsException
     */
    @AuraEnabled(cacheable=true)
    public static CaseDataWrapper getCaseData(String caseId) {
        if (String.isBlank(caseId)) {
            throw new AuraHandledException('caseId is required.');
        }
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Status, Priority, Origin,
                   Description, IsClosed, ClosedDate, IsEscalated,
                   CreatedDate, OwnerId, ContactId, AccountId,
                   Workspace_Used__c, Workspace_Opened_At__c,
                   Resolution_Time_Minutes__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            throw new AuraHandledException('Case not found for Id: ' + caseId);
        }
        Case c = cases[0];
        CaseDataWrapper wrapper = new CaseDataWrapper();
        wrapper.caseRecord = c;
        if (c.AccountId != null) {
            wrapper.accountRecord = fetchAccount(c.AccountId);
        }
        if (c.ContactId != null) {
            wrapper.contactRecord = fetchContact(c.ContactId);
        }
        return wrapper;
    }

    /**
     * Returns interaction history related to the Case: Tasks, Events,
     * EmailMessages, and prior closed Cases for the same Contact.
     *
     * @param  caseId     Id of the current Case (required).
     * @param  contactId  Contact associated with the Case (may be null).
     * @param  accountId  Account associated with the Case (may be null — reserved for future use).
     * @return InteractionsWrapper with populated collections. Never null.
     * @throws AuraHandledException when caseId is blank.
     *
     * @calledBy    agentConsoleWorkspace.js (handleLoadInteractions — imperative)
     * @testMethods test_getPreviousInteractions_withData_returnsRecords,
     *              test_getPreviousInteractions_noContactId_returnsEmptyPriorCases,
     *              test_getPreviousInteractions_blankId_throwsException
     */
    @AuraEnabled(cacheable=true)
    public static InteractionsWrapper getPreviousInteractions(
        String caseId,
        String contactId,
        String accountId
    ) {
        if (String.isBlank(caseId)) {
            throw new AuraHandledException('caseId is required.');
        }
        InteractionsWrapper wrapper = new InteractionsWrapper();
        wrapper.tasks = [
            SELECT Id, Subject, Status, ActivityDate, Description
            FROM Task
            WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 20
        ];
        wrapper.events = [
            SELECT Id, Subject, ActivityDate, Description, StartDateTime
            FROM Event
            WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT 20
        ];
        wrapper.emails = [
            SELECT Id, Subject, MessageDate, TextBody, FromAddress, ToAddress
            FROM EmailMessage
            WHERE RelatedToId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY MessageDate DESC NULLS LAST
            LIMIT 20
        ];
        if (String.isNotBlank(contactId)) {
            Id contactIdTyped = (Id) contactId;
            Id caseIdTyped    = (Id) caseId;
            wrapper.priorCases = [
                SELECT Id, CaseNumber, Subject, Status, ClosedDate, CreatedDate, Priority
                FROM Case
                WHERE ContactId = :contactIdTyped
                  AND IsClosed  = true
                  AND Id       != :caseIdTyped
                WITH SECURITY_ENFORCED
                ORDER BY ClosedDate DESC NULLS LAST
                LIMIT 10
            ];
        } else {
            wrapper.priorCases = new List<Case>();
        }
        return wrapper;
    }

    /**
     * Performs a SOSL search for published knowledge content relevant to the
     * given search term. Returns List<SObject> to remain compatible with orgs
     * where Salesforce Knowledge is not enabled (KnowledgeArticleVersion is
     * unavailable as a compiled type when the feature is disabled).
     *
     * @param  searchTerm  Term to search. Blank input returns empty list.
     * @return List of SObject (KnowledgeArticleVersion when Knowledge is on).
     *         Empty list when searchTerm is blank or Knowledge is unavailable.
     *
     * @calledBy    agentConsoleWorkspace.js (handleSearchKnowledge — imperative)
     * @testMethods test_getKnowledgeArticles_blankTerm_returnsEmpty,
     *              test_getKnowledgeArticles_validTerm_returnsWithoutError
     */
    @AuraEnabled(cacheable=true)
    public static List<SObject> getKnowledgeArticles(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return new List<SObject>();
        }
        String safeSearch = String.escapeSingleQuotes(searchTerm.trim());
        String sosl = 'FIND {' + safeSearch + '*} IN ALL FIELDS RETURNING '
            + 'KnowledgeArticleVersion(Id, Title, Summary, ArticleNumber, '
            + 'LastPublishedDate '
            + 'WHERE PublishStatus = \'Online\' '
            + 'AND Language = \'' + UserInfo.getLanguage() + '\') '
            + 'LIMIT 10';
        try {
            List<List<SObject>> results = Search.query(sosl);
            if (!results.isEmpty()) {
                return results[0];
            }
        } catch (Exception ex) {
            // Knowledge may not be enabled in all orgs; return empty gracefully.
            System.debug(LoggingLevel.WARN, 'Knowledge search unavailable: ' + ex.getMessage());
        }
        return new List<SObject>();
    }

    /**
     * Returns active CaseMilestone records for the given Case, including
     * TargetDate and completion status for the SLA countdown panel.
     *
     * @param  caseId  Id of the Case to retrieve milestones for.
     * @return List of CaseMilestone records. Empty when caseId is blank or
     *         Entitlements are not configured.
     *
     * @calledBy    agentConsoleWorkspace.js (_loadMilestones — imperative)
     * @testMethods test_getCaseMilestones_blankId_returnsEmpty,
     *              test_getCaseMilestones_validId_returnsWithoutError
     */
    @AuraEnabled(cacheable=true)
    public static List<CaseMilestone> getCaseMilestones(String caseId) {
        if (String.isBlank(caseId)) {
            return new List<CaseMilestone>();
        }
        try {
            return [
                SELECT Id, CaseId, MilestoneTypeId, TargetDate,
                       IsCompleted, IsViolated, CompletionDate
                FROM CaseMilestone
                WHERE CaseId = :caseId
                WITH SECURITY_ENFORCED
                ORDER BY TargetDate ASC NULLS LAST
                LIMIT 10
            ];
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'CaseMilestone query failed: ' + ex.getMessage());
            return new List<CaseMilestone>();
        }
    }

    /**
     * Returns Case_Recommendation__c records linked to the Case for display
     * in the AI Recommendations panel.
     *
     * @param  caseId  Id of the Case to retrieve recommendations for.
     * @return List of Case_Recommendation__c (up to 5). Empty when none exist.
     *
     * @calledBy    agentConsoleWorkspace.js (_loadRecommendations — imperative)
     * @testMethods test_getRecommendations_withData_returnsRecords,
     *              test_getRecommendations_noData_returnsEmpty,
     *              test_getRecommendations_blankId_returnsEmpty
     */
    @AuraEnabled(cacheable=true)
    public static List<Case_Recommendation__c> getRecommendations(String caseId) {
        if (String.isBlank(caseId)) {
            return new List<Case_Recommendation__c>();
        }
        return [
            SELECT Id, Name, Case__c, Recommendation_Text__c,
                   Recommendation_Type__c, Resolution_Summary__c, CreatedDate
            FROM Case_Recommendation__c
            WHERE Case__c = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
    }

    /**
     * Marks the Case workspace as used by setting Workspace_Used__c = true and
     * stamping Workspace_Opened_At__c. Called once on component load via an
     * imperative (non-cacheable) Apex call.
     *
     * @param  caseId  Id of the Case to update.
     * @throws AuraHandledException when caseId is blank or the DML update fails.
     *
     * @calledBy    agentConsoleWorkspace.js (connectedCallback — imperative)
     * @testMethods test_markWorkspaceUsed_setsFields,
     *              test_markWorkspaceUsed_blankId_throwsException
     */
    @AuraEnabled
    public static void markWorkspaceUsed(String caseId) {
        if (String.isBlank(caseId)) {
            throw new AuraHandledException('caseId is required.');
        }
        try {
            Case c = new Case(
                Id                   = (Id) caseId,
                Workspace_Used__c    = true,
                Workspace_Opened_At__c = System.now()
            );
            update c;
        } catch (DmlException ex) {
            throw new AuraHandledException('Failed to mark workspace used: ' + ex.getMessage());
        }
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────

    /** Fetches Account with fields needed by the customer profile panel. */
    private static Account fetchAccount(Id accountId) {
        List<Account> rows = [
            SELECT Id, Name, Industry, Phone, Website, Type,
                   BillingCity, BillingCountry
            FROM Account
            WHERE Id = :accountId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    /** Fetches Contact with fields needed by the customer profile panel. */
    private static Contact fetchContact(Id contactId) {
        List<Contact> rows = [
            SELECT Id, FirstName, LastName, Name, Email, Phone, Title
            FROM Contact
            WHERE Id = :contactId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }
}
