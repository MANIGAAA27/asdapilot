/**
  @file              AgentConsoleWorkspaceService.cls
  @description       Aggregates and retrieves data for the Agent Console Workspace LWC.
                     Consolidates Case, Account, Contact, EmailMessages, CaseComments,
                     Tasks, CaseMilestones, Knowledge Articles, and AI Recommendations
                     into a unified view for Service Managers and Support Agents.
  @author            Mike Dev (Senior Developer)
  @created           2026-06-25
  @lastModified      2026-06-26
  @group             AgentConsoleWorkspace
 
  @dependencies      Case_Recommendation__c custom object and its fields.
                     Case custom fields: Workspace_Used__c, Workspace_Opened_At__c.
  @calledBy          agentConsoleWorkspace LWC
  @testClass         AgentConsoleWorkspaceServiceTest
 
  @see               LLD-AgentConsoleWorkspace (Feature: Agent Console Workspace)
 */

// MODIFIED 2026-06-25 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
/**
  Service layer for the Agent Console Workspace.
 
  Responsibilities:
  - Retrieve Case core data with Account and Contact context.
  - Fetch recent interactions (EmailMessage, CaseComment, Task, prior Cases).
  - Surface active CaseMilestone records for SLA tracking.
  - Return Case_Recommendation__c records for AI guidance.
  - Search Knowledge Articles via SOSL.
  - Track workspace usage via Workspace_Used__c and Workspace_Opened_At__c.
 
  Governor limits strategy:
  - Maximum 10 SOQL queries per method invocation.
  - Row caps: 20 per interaction query, 10 milestones, 5 recommendations.
  - All reads use WITH SECURITY_ENFORCED for FLS compliance.
 
  @testClass AgentConsoleWorkspaceServiceTest
 */
public with sharing class AgentConsoleWorkspaceService {

    // ─────────────────────────────────────────────────────────────────────────
    // Inner Wrapper Classes
    // ─────────────────────────────────────────────────────────────────────────

    /**
      Wrapper returned by getCaseDetails containing Case, Account, and Contact data.
     */
    public class CaseWrapper {
        /** Core Case record including custom workspace tracking fields. */
        @AuraEnabled public Case caseRecord { get; set; }
        /** Account associated with the Case. Null if no AccountId on Case. */
        @AuraEnabled public Account accountRecord { get; set; }
        /** Contact associated with the Case. Null if no ContactId on Case. */
        @AuraEnabled public Contact contactRecord { get; set; }
    }

    /**
      Wrapper returned by getRecentInteractions containing interaction history.
     */
    public class InteractionWrapper {
        /** EmailMessage records linked to the Case, ordered by date DESC. */
        @AuraEnabled public List<EmailMessage> emails { get; set; }
        /** CaseComment records linked to the Case, ordered by date DESC. */
        @AuraEnabled public List<CaseComment> comments { get; set; }
        /** Prior closed Cases for the same Contact, ordered by ClosedDate DESC. */
        @AuraEnabled public List<Case> priorCases { get; set; }
        /** Task records linked to the Case (WhatId), ordered by date DESC. */
        @AuraEnabled public List<Task> tasks { get; set; }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public @AuraEnabled Methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
      Retrieves the Case record with its associated Account and Contact.
      Used by the LWC to populate the case header and customer profile panel.
     
      @param  caseId  The Id of the Case to retrieve. Must not be null.
      @return         CaseWrapper containing caseRecord, accountRecord, contactRecord.
      @throws         AuraHandledException when caseId is null or no Case is found.
     
      @calledBy    agentConsoleWorkspace LWC (connectedCallback)
      @testMethods test_getCaseDetails_returnsWrapper, test_getCaseDetails_nullId_throws,
                   test_getCaseDetails_withAccountAndContact
     */
    @AuraEnabled(cacheable=true)
    public static CaseWrapper getCaseDetails(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required.');
        }
        List<Case> cases = [
            SELECT Id, CaseNumber, Status, Priority, Origin, Subject, Description,
                   IsClosed, ClosedDate, IsEscalated, CreatedDate,
                   AccountId, Account.Name, Account.Phone, Account.Industry,
                   ContactId, Contact.Name, Contact.Email, Contact.Phone,
                   Workspace_Used__c, Workspace_Opened_At__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            throw new AuraHandledException('Case not found: ' + caseId);
        }
        Case c = cases[0];
        CaseWrapper wrapper = new CaseWrapper();
        wrapper.caseRecord = c;
        wrapper.accountRecord = c.Account;
        wrapper.contactRecord = c.Contact;
        return wrapper;
    }

    /**
      Retrieves recent interactions related to a Case.
      This includes emails, comments, tasks, and prior cases for the contact.
     
      @param  caseId     The Id of the current Case.
      @param  contactId  The Id of the Contact on the Case.
      @return            InteractionWrapper containing lists of related records.
     */
    @AuraEnabled(cacheable=true)
    public static InteractionWrapper getRecentInteractions(Id caseId, Id contactId) {
        InteractionWrapper wrapper = new InteractionWrapper();

        wrapper.emails = [
            SELECT Id, Subject, FromAddress, ToAddress, MessageDate, TextBody
            FROM EmailMessage WHERE ParentId = :caseId
            WITH SECURITY_ENFORCED ORDER BY MessageDate DESC LIMIT 20
        ];
        wrapper.comments = [
            SELECT Id, CommentBody, CreatedDate, CreatedBy.Name
            FROM CaseComment WHERE ParentId = :caseId
            WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 20
        ];
        wrapper.tasks = [
            SELECT Id, Subject, Status, ActivityDate, Description
            FROM Task WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED ORDER BY ActivityDate DESC, CreatedDate DESC LIMIT 20
        ];
        if (contactId != null) {
            wrapper.priorCases = [
                SELECT Id, CaseNumber, Subject, Status, ClosedDate
                FROM Case WHERE ContactId = :contactId AND IsClosed = true AND Id != :caseId
                WITH SECURITY_ENFORCED ORDER BY ClosedDate DESC LIMIT 10
            ];
        } else {
            wrapper.priorCases = new List<Case>();
        }

        return wrapper;
    }

    /**
      Retrieves AI-generated recommendations for a given Case.
     
      @param  caseId The Id of the Case.
      @return        A list of Case_Recommendation__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Case_Recommendation__c> getAIRecommendations(Id caseId) {
        return [
            SELECT Id, Recommendation_Text__c, Resolution_Summary__c, Source__c,
                   Confidence_Score__c, Is_Applied__c
            FROM Case_Recommendation__c
            WHERE Case__c = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY Confidence_Score__c DESC
            LIMIT 5
        ];
    }

    /**
      Imperatively updates a Case to track that the workspace has been used.
     
      @param  caseId  The Id of the Case to update.
      @return         String 'Success' on completion.
     */
    @AuraEnabled
    public static String trackWorkspaceUsage(Id caseId) {
        try {
            Case c = new Case(
                Id = caseId,
                Workspace_Used__c = true,
                Workspace_Opened_At__c = System.now()
            );
            update c;
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
