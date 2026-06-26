/**
 * @file              AgentConsoleWorkspaceService.cls
 * @description       Aggregates and delivers all data required by the
 *                    agentConsoleWorkspace LWC: Case details, related Account
 *                    and Contact, interaction history (Tasks, Events, EmailMessages,
 *                    CaseComments, closed Cases), Knowledge articles, active
 *                    CaseMilestones, and AI-generated Case_Recommendation__c records.
 *                    Also stamps workspace usage tracking fields on Case load.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-26
 * @lastModified      2026-06-26
 * @group             AgentConsoleWorkspace
 *
 * @dependencies      (none in this changeset)
 * @calledBy          (none in this changeset)
 * @testClass         AgentConsoleWorkspaceServiceTest
 *
 * @see               LLD-AgentConsoleWorkspace (Feature: Agent Console Workspace)
 * @project           Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
 */

// MODIFIED 2026-06-26 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
/**
 * Service layer for the Agent Console Workspace LWC.
 *
 * Responsibilities:
 *   - Retrieve Case details including associated Account and Contact.
 *   - Return interaction history (Tasks, Events, EmailMessages, CaseComments,
 *     and prior closed Cases for the same Contact or Account).
 *   - Search KnowledgeArticleVersion records via SOSL.
 *   - Retrieve active CaseMilestone records with TargetDate information.
 *   - Return AI-generated Case_Recommendation__c records linked to a Case.
 *   - Stamp Workspace_Used__c and Workspace_Opened_At__c on Case when opened.
 *
 * Threading: read methods are cacheable=true; markWorkspaceOpened is non-cacheable DML.
 * Governor-limit budget: ≤10 SOQL queries per invocation, ≤5,000 rows per query.
 *
 * @testClass AgentConsoleWorkspaceServiceTest
 */
public with sharing class AgentConsoleWorkspaceService {

    // ─────────────────────────────────────────────────────────────────────────
    // Inner result wrappers
    // ─────────────────────────────────────────────────────────────────────────

    /** Wrapper returned by getCaseDetails, containing Case + related parent data. */
    public class CaseDetailWrapper {
        @AuraEnabled public Case caseRecord { get; set; }
        @AuraEnabled public Account accountRecord { get; set; }
        @AuraEnabled public Contact contactRecord { get; set; }
        @AuraEnabled public List<CaseMilestone> milestones { get; set; }
    }

    /** Wrapper for interaction history across multiple related objects. */
    public class InteractionHistoryWrapper {
        @AuraEnabled public List<Task> tasks { get; set; }
        @AuraEnabled public List<Event> events { get; set; }
        @AuraEnabled public List<EmailMessage> emailMessages { get; set; }
        @AuraEnabled public List<CaseComment> caseComments { get; set; }
        @AuraEnabled public List<Case> relatedCases { get; set; }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Read-only cacheable methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns Case core fields, related Account, Contact, and active CaseMilestones
     * for the provided Case Id in a single response to minimise SOQL invocations.
     *
     * @param  caseId  Id of the Case record to retrieve. Must not be null.
     * @return CaseDetailWrapper containing caseRecord, accountRecord, contactRecord,
     *         and milestones. AccountRecord and contactRecord are null when not related.
     * @throws AuraHandledException when caseId is blank or the Case is inaccessible.
     *
     * @calledBy    agentConsoleWorkspace LWC (imperative Apex call on connectedCallback)
     * @testMethods test_getCaseDetails_validCase_returnsWrapper,
     *              test_getCaseDetails_nullId_throws,
     *              test_getCaseDetails_bulk200_succeeds
     */
    @AuraEnabled(cacheable=true)
    public static CaseDetailWrapper getCaseDetails(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        // Query 1 of budget: Case + Account + Contact in one query via relationships
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Description, Status, Priority, Origin,
                   IsClosed, ClosedDate, CreatedDate, IsEscalated,
                   ContactId, AccountId,
                   Account.Name, Account.Industry, Account.Phone,
                   Contact.Name, Contact.Email, Contact.Phone,
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

        // Query 2 of budget: CaseMilestones
        List<CaseMilestone> milestones = [
            SELECT Id, MilestoneTypeId, MilestoneType.Name, TargetDate,
                   IsCompleted, CompletionDate, IsViolated, ElapsedTimeInMins
            FROM CaseMilestone
            WHERE CaseId = :caseId
            AND IsCompleted = false
            WITH SECURITY_ENFORCED
            ORDER BY TargetDate ASC
            LIMIT 10
        ];

        CaseDetailWrapper wrapper = new CaseDetailWrapper();
        wrapper.caseRecord = c;
        wrapper.milestones = milestones;

        // Build Account and Contact records from relationship fields
        if (c.AccountId != null) {
            wrapper.accountRecord = c.Account;
        }
        if (c.ContactId != null) {
            wrapper.contactRecord = c.Contact;
        }

        return wrapper;
    }

    /**
     * Returns interaction history for a Case: recent Tasks, Events, EmailMessages,
     * CaseComments, and the 10 most recently closed Cases for the same Contact.
     *
     * @param  caseId     Id of the Case record. Must not be null.
     * @param  contactId  Id of the related Contact (may be null).
     * @param  accountId  Id of the related Account (may be null).
     * @return InteractionHistoryWrapper containing lists for each interaction type.
     * @throws AuraHandledException when caseId is blank.
     *
     * @calledBy    agentConsoleWorkspace LWC
     * @testMethods test_getInteractionHistory_validCase_returnsHistory,
     *              test_getInteractionHistory_nullCase_throws
     */
    @AuraEnabled(cacheable=true)
    public static InteractionHistoryWrapper getInteractionHistory(
            Id caseId, Id contactId, Id accountId) {

        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        InteractionHistoryWrapper wrapper = new InteractionHistoryWrapper();

        // Query 3 of budget: Tasks related to this Case
        wrapper.tasks = [
            SELECT Id, Subject, Status, ActivityDate, Description,
                   OwnerId, Owner.Name, CreatedDate
            FROM Task
            WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];

        // Query 4 of budget: Events related to this Case
        wrapper.events = [
            SELECT Id, Subject, StartDateTime, EndDateTime, Description,
                   OwnerId, Owner.Name
            FROM Event
            WHERE WhatId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY StartDateTime DESC
            LIMIT 20
        ];

        // Query 5 of budget: EmailMessages on this Case
        wrapper.emailMessages = [
            SELECT Id, Subject, TextBody, FromAddress, ToAddress,
                   MessageDate, Status, Incoming
            FROM EmailMessage
            WHERE ParentId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY MessageDate DESC
            LIMIT 20
        ];

        // Query 6 of budget: CaseComments on this Case
        wrapper.caseComments = [
            SELECT Id, CommentBody, CreatedDate, CreatedById, CreatedBy.Name, IsPublished
            FROM CaseComment
            WHERE ParentId = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];

        // Query 7 of budget: Prior closed Cases for the same Contact or Account
        List<Case> relatedCases = new List<Case>();
        if (contactId != null) {
            relatedCases = [
                SELECT Id, CaseNumber, Subject, Status, Priority, ClosedDate, CreatedDate
                FROM Case
                WHERE ContactId = :contactId
                AND IsClosed = true
                AND Id != :caseId
                WITH SECURITY_ENFORCED
                ORDER BY ClosedDate DESC
                LIMIT 10
            ];
        } else if (accountId != null) {
            relatedCases = [
                SELECT Id, CaseNumber, Subject, Status, Priority, ClosedDate, CreatedDate
                FROM Case
                WHERE AccountId = :accountId
                AND IsClosed = true
                AND Id != :caseId
                WITH SECURITY_ENFORCED
                ORDER BY ClosedDate DESC
                LIMIT 10
            ];
        }
        wrapper.relatedCases = relatedCases;

        return wrapper;
    }

    /**
     * Searches Knowledge records via dynamic SOSL (Search.query) using the case
     * subject as the search term. Uses Search.query() rather than a static SOSL
     * literal so this class compiles in orgs where Salesforce Knowledge is not
     * enabled — the describe gate short-circuits before the search executes.
     *
     * @param  searchTerm  Text to search in knowledge articles. Must not be blank.
     * @return List of SObject KnowledgeArticleVersion records (up to 10), or empty
     *         list when Knowledge is not enabled or no articles match.
     * @throws AuraHandledException when searchTerm is blank.
     *
     * @calledBy    agentConsoleWorkspace LWC
     * @testMethods test_getKnowledgeArticles_validTerm_returnsList,
     *              test_getKnowledgeArticles_blankTerm_throws
     */
    @AuraEnabled(cacheable=true)
    public static List<SObject> getKnowledgeArticles(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            throw new AuraHandledException('searchTerm is required.');
        }

        // Sanitise: replace non-alphanumeric characters to prevent SOSL injection.
        // After replacement only [a-zA-Z0-9 ] remain, so no further escaping needed.
        String sanitised = searchTerm.replaceAll('[^a-zA-Z0-9 ]', ' ').trim();

        if (String.isBlank(sanitised)) {
            return new List<SObject>();
        }

        // Guard: return empty list when Knowledge is not enabled in this org.
        if (!Schema.getGlobalDescribe().containsKey('KnowledgeArticleVersion')) {
            return new List<SObject>();
        }

        // Dynamic SOSL via Search.query() — compiles in all org editions because
        // 'KnowledgeArticleVersion' is a runtime string, not a static SOSL literal.
        String sosl =
            'FIND \'' + sanitised + '\' IN ALL FIELDS '
            + 'RETURNING KnowledgeArticleVersion('
            + 'Id, Title, Summary, ArticleNumber, VersionNumber, '
            + 'PublishStatus, Language, LastPublishedDate '
            + 'WHERE PublishStatus = \'Online\') '
            + 'LIMIT 10';

        List<List<SObject>> results = Search.query(sosl);
        return results[0];
    }

    /**
     * Returns Case_Recommendation__c records linked to the given Case Id,
     * ordered by creation date descending.
     *
     * @param  caseId  Id of the Case record. Must not be null.
     * @return List of Case_Recommendation__c records, up to 10 results.
     * @throws AuraHandledException when caseId is blank.
     *
     * @calledBy    agentConsoleWorkspace LWC
     * @testMethods test_getRecommendations_validCase_returnsList,
     *              test_getRecommendations_nullCase_throws
     */
    @AuraEnabled(cacheable=true)
    public static List<Case_Recommendation__c> getRecommendations(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        return [
            SELECT Id, Name, Recommendation_Text__c, Resolution_Summary__c,
                   Confidence_Score__c, Source__c, Recommendation_Status__c,
                   Case__c, CreatedDate
            FROM Case_Recommendation__c
            WHERE Case__c = :caseId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Write methods (non-cacheable)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Stamps Workspace_Used__c = true and Workspace_Opened_At__c = now() on the
     * Case when the agentConsoleWorkspace component loads. Called imperatively;
     * only performs a single-record update.
     *
     * @param  caseId  Id of the Case to update. Must not be null.
     * @throws AuraHandledException on DML failure or missing access.
     *
     * @calledBy    agentConsoleWorkspace LWC (connectedCallback)
     * @testMethods test_markWorkspaceOpened_validCase_stampsFields,
     *              test_markWorkspaceOpened_nullId_throws
     */
    @AuraEnabled
    public static void markWorkspaceOpened(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required.');
        }

        // CRUD check before DML
        if (!Schema.sObjectType.Case.isUpdateable()) {
            throw new AuraHandledException('Insufficient access to update Case.');
        }
        if (!Schema.sObjectType.Case.fields.Workspace_Used__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient field access: Workspace_Used__c.');
        }

        Case caseToUpdate = new Case(
            Id = caseId,
            Workspace_Used__c = true,
            Workspace_Opened_At__c = Datetime.now()
        );

        try {
            update caseToUpdate;
        } catch (DmlException ex) {
            throw new AuraHandledException('Failed to update Case: ' + ex.getMessage());
        }
    }
}
