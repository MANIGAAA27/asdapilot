/**
 * @file              AgentConsoleWorkspaceService.cls
 * @description       Service class providing data aggregation and retrieval for the
 *                    Agent Console Workspace LWC. Consolidates Case, Account, Contact,
 *                    Activity, AI Recommendation, and CaseMilestone data into structured
 *                    wrapper responses for efficient LWC consumption.
 *                    Max 10 SOQL queries per invocation; max 5,000 rows per transaction.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-25
 * @lastModified      2026-06-25
 * @group             AgentConsoleWorkspace
 *
 * @dependencies      CaseDetailWrapper, InteractionWrapper
 * @calledBy          agentConsoleWorkspace LWC
 * @testClass         AgentConsoleWorkspaceServiceTest
 *
 * @project           Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
 * @lld               LLD-AgentConsoleWorkspace
 */
// MODIFIED 2026-06-25 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
public with sharing class AgentConsoleWorkspaceService {

    /**
     * Service layer for Agent Console Workspace data aggregation.
     *
     * Responsibilities:
     *   - Retrieve Case details with related Account and Contact.
     *   - Fetch previous interactions: EmailMessages, Tasks, prior closed Cases.
     *   - Surface AI recommendations from Case_Recommendation__c.
     *   - Query active CaseMilestone records for SLA countdown tracking.
     *   - Track workspace usage via Workspace_Used__c and Workspace_Opened_At__c.
     *
     * Governor limits: max 10 SOQL queries per invocation, max 5,000 rows returned.
     * Security: all SOQL uses WITH SECURITY_ENFORCED; DML uses Case SObject directly.
     *
     * @testClass AgentConsoleWorkspaceServiceTest
     */

    // ─────────────────────────────────────────────────────────────────────────
    // Read methods — @AuraEnabled(cacheable=true), no DML
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Retrieves the Case record with related Account and Contact data for the
     * workspace header panel. Uses 1 SOQL query.
     *
     * @param  caseId  The Id of the active Case being handled. Must not be null.
     * @return CaseDetailWrapper containing Case, Account and Contact details,
     *         or null when the record is not found or not accessible.
     * @throws AuraHandledException when caseId is null or a data access error occurs.
     *
     * @calledBy    agentConsoleWorkspace LWC (wire)
     * @testMethods test_getCaseDetails_returnsWrapper, test_getCaseDetails_nullId_throws
     */
    @AuraEnabled(cacheable=true)
    public static CaseDetailWrapper getCaseDetails(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Description, Status, Priority, Origin,
                   IsClosed, ClosedDate, CreatedDate, IsEscalated,
                   AccountId, Account.Name,
                   ContactId, Contact.Name, Contact.Email, Contact.Phone,
                   Workspace_Used__c, Workspace_Opened_At__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return null;
        }
        Case c = cases[0];
        CaseDetailWrapper wrapper = new CaseDetailWrapper();
        wrapper.caseRecord        = c;
        if (c.AccountId != null) {
            wrapper.accountName  = c.Account.Name;
        }
        if (c.ContactId != null) {
            wrapper.contactName  = c.Contact.Name;
            wrapper.contactEmail = c.Contact.Email;
            wrapper.contactPhone = c.Contact.Phone;
        }
        return wrapper;
    }

    /**
     * Retrieves previous interactions for a Case: the latest 20 EmailMessages,
     * 20 Tasks, and 10 closed prior Cases related by ContactId. Uses 4 SOQL queries.
     *
     * @param  caseId  The Id of the active Case. Must not be null.
     * @return List of InteractionWrapper objects. Empty list when no prior interactions
     *         exist. Never returns null.
     * @throws AuraHandledException when caseId is null.
     *
     * @calledBy    agentConsoleWorkspace LWC (imperative)
     * @testMethods test_getPreviousInteractions_returnsResults,
     *              test_getPreviousInteractions_nullId_throws,
     *              test_getPreviousInteractions_bulk
     */
    @AuraEnabled(cacheable=true)
    public static List<InteractionWrapper> getPreviousInteractions(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        // Fetch parent Case to obtain ContactId for prior-case lookup (1 query).
        List<Case> parentCases = [
            SELECT Id, ContactId
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (parentCases.isEmpty()) {
            return new List<InteractionWrapper>();
        }
        Id contactId = parentCases[0].ContactId;

        List<InteractionWrapper> interactions = new List<InteractionWrapper>();

        // EmailMessages on this Case (1 query).
        for (EmailMessage em : [
            SELECT Id, Subject, TextBody, FromAddress, CreatedDate
            FROM EmailMessage
            WHERE ParentId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 20
        ]) {
            InteractionWrapper iw = new InteractionWrapper();
            iw.recordType   = 'Email';
            iw.subject      = em.Subject;
            iw.fromAddress  = em.FromAddress;
            iw.activityDate = em.CreatedDate;
            iw.description  = em.TextBody != null ? em.TextBody.abbreviate(500) : '';
            interactions.add(iw);
        }

        // Tasks linked to this Case (1 query).
        for (Task t : [
            SELECT Id, Subject, Status, Description, CreatedDate
            FROM Task
            WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 20
        ]) {
            InteractionWrapper iw = new InteractionWrapper();
            iw.recordType   = 'Task';
            iw.subject      = t.Subject;
            iw.status       = t.Status;
            iw.activityDate = t.CreatedDate;
            iw.description  = t.Description != null ? t.Description.abbreviate(500) : '';
            interactions.add(iw);
        }

        // Prior closed Cases related by ContactId (1 query — only when Contact exists).
        if (contactId != null) {
            for (Case pc : [
                SELECT Id, CaseNumber, Subject, Status, ClosedDate, Priority
                FROM Case
                WHERE ContactId = :contactId
                  AND Id != :caseId
                  AND IsClosed = true
                WITH SECURITY_ENFORCED
                ORDER BY ClosedDate DESC
                LIMIT 10
            ]) {
                InteractionWrapper iw = new InteractionWrapper();
                iw.recordType   = 'Prior Case';
                iw.caseNumber   = pc.CaseNumber;
                iw.subject      = pc.Subject;
                iw.status       = pc.Status;
                iw.activityDate = pc.ClosedDate;
                interactions.add(iw);
            }
        }
        return interactions;
    }

    /**
     * Retrieves AI-recommended resolutions from Case_Recommendation__c records
     * linked to the specified Case, ordered by Confidence_Score__c descending.
     * Uses 1 SOQL query.
     *
     * @param  caseId  The Id of the active Case. Must not be null.
     * @return List of up to 10 Case_Recommendation__c records. Empty list when none
     *         exist. Never returns null.
     * @throws AuraHandledException when caseId is null.
     *
     * @calledBy    agentConsoleWorkspace LWC (wire)
     * @testMethods test_getAiRecommendations_returnsResults,
     *              test_getAiRecommendations_nullId_throws,
     *              test_getAiRecommendations_emptyCaseReturnsEmpty
     */
    @AuraEnabled(cacheable=true)
    public static List<Case_Recommendation__c> getAiRecommendations(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }
        return [
            SELECT Id, Name, Recommendation_Text__c, Recommended_Resolution__c,
                   Confidence_Score__c, Source__c
            FROM Case_Recommendation__c
            WHERE Case__c = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY Confidence_Score__c DESC NULLS LAST
            LIMIT 10
        ];
    }

    /**
     * Retrieves active (not yet completed) CaseMilestone records for the SLA
     * countdown timer panel in the workspace. Uses 1 SOQL query.
     *
     * @param  caseId  The Id of the active Case. Must not be null.
     * @return List of CaseMilestone records ordered by TargetDate ascending.
     *         Returns empty list when no active milestones exist. Never null.
     * @throws AuraHandledException when caseId is null.
     *
     * @calledBy    agentConsoleWorkspace LWC (wire)
     * @testMethods test_getCaseMilestones_emptyWhenNone, test_getCaseMilestones_nullId_throws
     */
    @AuraEnabled(cacheable=true)
    public static List<CaseMilestone> getCaseMilestones(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }
        return [
            SELECT Id, CaseId, MilestoneTypeId, MilestoneType.Name,
                   TargetDate, IsCompleted, IsViolated, CompletionDate
            FROM CaseMilestone
            WHERE CaseId = :caseId
              AND IsCompleted = false
            WITH SECURITY_ENFORCED
            ORDER BY TargetDate ASC
            LIMIT 10
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Write method — plain @AuraEnabled (performs DML)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Records that the workspace was opened by setting Workspace_Used__c = true
     * and stamping Workspace_Opened_At__c on the Case. Called imperatively from
     * the LWC connectedCallback (not cacheable — performs a single DML update).
     *
     * @param  caseId  The Id of the active Case. Must not be null.
     * @throws AuraHandledException when caseId is null or the DML update fails.
     *
     * @calledBy    agentConsoleWorkspace LWC (imperative, connectedCallback)
     * @testMethods test_trackWorkspaceOpen_stampsFields, test_trackWorkspaceOpen_nullId_throws
     */
    @AuraEnabled
    public static void trackWorkspaceOpen(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }
        try {
            Case c = new Case(
                Id                     = caseId,
                Workspace_Used__c      = true,
                Workspace_Opened_At__c = System.now()
            );
            update c;
        } catch (DmlException ex) {
            throw new AuraHandledException(
                'Failed to track workspace open: ' + ex.getMessage()
            );
        }
    }
}
