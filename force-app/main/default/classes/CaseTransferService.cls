/**
 * @file              CaseTransferService.cls
 * @description       Service layer for Case transfer orchestration. Accepts a
 *                    bulk Set of transferred Case IDs, assembles structured
 *                    case-history payloads from Case, EmailMessage, CaseComment,
 *                    Task, and FeedItem, and enqueues a single
 *                    CaseSummaryGeneratorQueueable job to process them
 *                    asynchronously. Implements HLD-CMP-003.
 *
 *                    All SOQL is bulkified — no queries inside loops.
 *                    History record limits are governed by
 *                    CaseSummarySettings__mdt.History_Record_Limit__c.
 *
 * @author            ASDA Dev Agent
 * @created           2026-06-05
 * @lastModified      2026-06-05
 * @group             CaseTransfer
 *
 * @dependencies      CaseSummaryGeneratorQueueable, CaseSummarySettings__mdt
 * @calledBy          CaseTriggerHandler
 * @testClass         CaseTransferServiceTest
 *
 * @see               HLD-CMP-003, HLD Section 5.2, HLD Section 5.3
 */
public with sharing class CaseTransferService {

    /** Safe fallback when History_Record_Limit__c is null or <= 0. */
    private static final Integer DEFAULT_HISTORY_LIMIT = 10;

    /**
     * Entry point called by CaseTriggerHandler. Enqueues a single
     * CaseSummaryGeneratorQueueable job carrying all transferred Case IDs.
     * Never enqueues one job per Case — bulk-safe by design (HLD Section 5.2).
     *
     * @param transferredCaseIds  Non-empty Set of Case IDs whose OwnerId changed.
     *
     * @calledBy    CaseTriggerHandler.onAfterUpdate
     * @testMethods test_beginSummaryGeneration_enqueuesJob,
     *              test_beginSummaryGeneration_emptySet_doesNotEnqueue
     */
    public static void beginSummaryGeneration(Set<Id> transferredCaseIds) {
        if (transferredCaseIds == null || transferredCaseIds.isEmpty()) {
            return;
        }

        List<Id> caseIdList = new List<Id>(transferredCaseIds);
        System.enqueueJob(new CaseSummaryGeneratorQueueable(caseIdList));
    }

    /**
     * Assembles a structured CaseHistoryPayload for a single Case ID.
     * All related-object queries are performed in bulk by the caller;
     * this method accepts pre-fetched maps to avoid SOQL in loops.
     *
     * @param caseRecord          The Case SObject with required fields populated.
     * @param emailMessages       List of EmailMessage records for this Case.
     * @param caseComments        List of CaseComment records for this Case.
     * @param tasks               List of Task records for this Case.
     * @param feedItems           List of FeedItem records for this Case.
     * @return                    CaseHistoryPayload wrapper ready for PII masking.
     *
     * @calledBy    CaseSummaryGeneratorQueueable.execute
     * @testMethods test_buildPayload_allSources_populatesCorrectly,
     *              test_buildPayload_emptySources_returnsMinimalPayload
     */
    public static CaseHistoryPayload buildPayload(
        Case caseRecord,
        List<EmailMessage> emailMessages,
        List<CaseComment> caseComments,
        List<Task> tasks,
        List<FeedItem> feedItems
    ) {
        CaseHistoryPayload payload = new CaseHistoryPayload();
        payload.caseId          = caseRecord.Id;
        payload.subject         = caseRecord.Subject;
        payload.description     = caseRecord.Description;
        payload.priority        = caseRecord.Priority;
        payload.status          = caseRecord.Status;
        payload.origin          = caseRecord.Origin;
        payload.createdDate     = caseRecord.CreatedDate;
        payload.lastModifiedDate = caseRecord.LastModifiedDate;

        payload.emails = new List<EmailPayload>();
        if (emailMessages != null) {
            for (EmailMessage em : emailMessages) {
                EmailPayload ep = new EmailPayload();
                ep.subject     = em.Subject;
                ep.textBody    = em.TextBody;
                ep.fromAddress = em.FromAddress;
                ep.toAddress   = em.ToAddress;
                ep.createdDate = em.CreatedDate;
                payload.emails.add(ep);
            }
        }

        payload.comments = new List<CommentPayload>();
        if (caseComments != null) {
            for (CaseComment cc : caseComments) {
                CommentPayload cp = new CommentPayload();
                cp.body        = cc.CommentBody;
                cp.createdDate = cc.CreatedDate;
                payload.comments.add(cp);
            }
        }

        payload.tasks = new List<TaskPayload>();
        if (tasks != null) {
            for (Task t : tasks) {
                TaskPayload tp = new TaskPayload();
                tp.subject      = t.Subject;
                tp.description  = t.Description;
                tp.status       = t.Status;
                tp.activityDate = t.ActivityDate;
                tp.createdDate  = t.CreatedDate;
                payload.tasks.add(tp);
            }
        }

        payload.feedItems = new List<FeedPayload>();
        if (feedItems != null) {
            for (FeedItem fi : feedItems) {
                FeedPayload fp = new FeedPayload();
                fp.body        = fi.Body;
                fp.createdDate = fi.CreatedDate;
                fp.feedType    = fi.Type;
                payload.feedItems.add(fp);
            }
        }

        return payload;
    }

    /**
     * Retrieves the configured history record limit from CaseSummarySettings__mdt.
     * Falls back to DEFAULT_HISTORY_LIMIT when the setting is absent or invalid.
     *
     * @return  Integer limit to apply per related-object query.
     *
     * @calledBy    CaseSummaryGeneratorQueueable.execute
     * @testMethods test_getHistoryLimit_returnsConfiguredValue,
     *              test_getHistoryLimit_nullSetting_returnsDefault
     */
    public static Integer getHistoryLimit() {
        List<CaseSummarySettings__mdt> settings = [
            SELECT History_Record_Limit__c
            FROM   CaseSummarySettings__mdt
            LIMIT  1
        ];
        if (!settings.isEmpty() && settings[0].History_Record_Limit__c != null
                && settings[0].History_Record_Limit__c > 0) {
            return settings[0].History_Record_Limit__c.intValue();
        }
        return DEFAULT_HISTORY_LIMIT;
    }

    // ─── Inner payload wrapper classes ───────────────────────────────────────

    /** Top-level payload passed to PIIMaskingService and LLMIntegrationService. */
    public class CaseHistoryPayload {
        public Id       caseId;
        public String   subject;
        public String   description;
        public String   priority;
        public String   status;
        public String   origin;
        public Datetime createdDate;
        public Datetime lastModifiedDate;
        public List<EmailPayload>   emails;
        public List<CommentPayload> comments;
        public List<TaskPayload>    tasks;
        public List<FeedPayload>    feedItems;
    }

    /** Email message sub-payload. */
    public class EmailPayload {
        public String   subject;
        public String   textBody;
        public String   fromAddress;
        public String   toAddress;
        public Datetime createdDate;
    }

    /** Case comment sub-payload. */
    public class CommentPayload {
        public String   body;
        public Datetime createdDate;
    }

    /** Task sub-payload. */
    public class TaskPayload {
        public String   subject;
        public String   description;
        public String   status;
        public Date     activityDate;
        public Datetime createdDate;
    }

    /** FeedItem sub-payload. */
    public class FeedPayload {
        public String   body;
        public Datetime createdDate;
        public String   feedType;
    }
}
