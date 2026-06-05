/**
 * @file              CaseSummaryGeneratorQueueable.cls
 * @description       Queueable Apex for asynchronous generation of case transfer
 *                    summaries. Implements the self-chaining chunking pattern
 *                    governed by CaseSummarySettings__mdt.Queueable_Chunk_Size__c
 *                    to stay within governor limits during bulk operations.
 *
 *                    Per execution:
 *                      1. Reads kill switch and chunk size from CaseSummarySettings__mdt.
 *                      2. Processes a configurable chunk of Case IDs.
 *                      3. For each Case: assembles payload, masks PII, calls LLM,
 *                         persists CaseTransferSummary__c, publishes platform event.
 *                      4. Self-chains with remaining IDs when the list exceeds chunk size.
 *
 *                    All SOQL is bulkified — no queries inside loops.
 *                    Implements HLD-CMP-004.
 *
 * @author            ASDA Dev Agent
 * @created           2026-06-05
 * @lastModified      2026-06-05
 * @group             CaseTransfer
 *
 * @dependencies      CaseTransferService, PIIMaskingService, LLMIntegrationService,
 *                    CaseSummarySettings__mdt, LLMPromptTemplate__mdt,
 *                    CaseSummaryGenerated__e
 * @calledBy          CaseTransferService.beginSummaryGeneration
 * @testClass         CaseSummaryGeneratorQueueableTest
 *
 * @see               HLD-CMP-004, HLD Section 5.3, HLD Section 10.4
 */
public without sharing class CaseSummaryGeneratorQueueable implements Queueable, Database.AllowsCallouts {

    private static final Integer DEFAULT_CHUNK_SIZE    = 5;
    private static final Integer DEFAULT_HISTORY_LIMIT = 10;
    private static final String  STATUS_IN_PROGRESS    = 'In Progress';
    private static final String  STATUS_SUCCESS        = 'Success';
    private static final String  STATUS_FAILED         = 'Failed';
    private static final String  PROMPT_TEMPLATE_NAME  = 'CaseTransferSummary';

    private List<Id> caseIds;

    /**
     * Constructs the Queueable with the full list of Case IDs to process.
     *
     * @param caseIds  List of Case IDs requiring summary generation.
     */
    public CaseSummaryGeneratorQueueable(List<Id> caseIds) {
        this.caseIds = caseIds;
    }

    /**
     * Main execute method. Reads settings, processes a chunk of Case IDs,
     * and self-chains for remaining IDs. Implements the chunking pattern
     * from HLD Section 5.3.
     *
     * @param context  QueueableContext provided by the platform.
     *
     * @calledBy    System (Queueable framework)
     * @testMethods test_execute_successPath_createsSummaryRecord,
     *              test_execute_killSwitch_inactive_doesNotProcess,
     *              test_execute_failedCallout_createsFailedRecord,
     *              test_execute_selfChains_whenRemainingIds
     */
    public void execute(QueueableContext context) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        CaseSummarySettingsWrapper settings = loadSettings();
        if (!settings.isActive) {
            return;
        }

        Integer chunkSize = settings.chunkSize;
        List<Id> currentChunk = new List<Id>();
        List<Id> remainingIds = new List<Id>();

        for (Integer i = 0; i < caseIds.size(); i++) {
            if (i < chunkSize) {
                currentChunk.add(caseIds[i]);
            } else {
                remainingIds.add(caseIds[i]);
            }
        }

        processChunk(currentChunk, settings.historyLimit);

        if (!remainingIds.isEmpty()) {
            System.enqueueJob(new CaseSummaryGeneratorQueueable(remainingIds));
        }
    }

    /**
     * Processes a chunk of Case IDs: queries all related data in bulk,
     * builds payloads, masks PII, calls LLM, and persists results.
     * No SOQL inside the per-Case loop — all queries are pre-fetched.
     *
     * @param chunkIds      List of Case IDs in this execution chunk.
     * @param historyLimit  Max related records to fetch per object type.
     */
    private void processChunk(List<Id> chunkIds, Integer historyLimit) {
        if (chunkIds == null || chunkIds.isEmpty()) {
            return;
        }

        Set<Id> chunkIdSet = new Set<Id>(chunkIds);

        // ── Bulk SOQL — all outside the loop ─────────────────────────────────
        Map<Id, Case> caseMap = new Map<Id, Case>([
            SELECT Id, Subject, Description, Priority, Status, Origin,
                   OwnerId, Owner.Name, CreatedDate, LastModifiedDate
            FROM   Case
            WHERE  Id IN :chunkIdSet
        ]);

        Map<Id, List<EmailMessage>> emailMap = buildEmailMap(chunkIdSet, historyLimit);
        Map<Id, List<CaseComment>>  commentMap = buildCommentMap(chunkIdSet, historyLimit);
        Map<Id, List<Task>>         taskMap = buildTaskMap(chunkIdSet, historyLimit);
        Map<Id, List<FeedItem>>     feedMap = buildFeedMap(chunkIdSet, historyLimit);

        List<CaseTransferSummary__c> summariesToInsert = new List<CaseTransferSummary__c>();
        List<CaseSummaryGenerated__e> eventsToPublish  = new List<CaseSummaryGenerated__e>();

        for (Id caseId : chunkIds) {
            Case caseRecord = caseMap.get(caseId);
            if (caseRecord == null) {
                continue;
            }

            String ownerName = caseRecord.Owner != null ? caseRecord.Owner.Name : '';

            List<EmailMessage> emails   = emailMap.containsKey(caseId)   ? emailMap.get(caseId)   : new List<EmailMessage>();
            List<CaseComment>  comments = commentMap.containsKey(caseId) ? commentMap.get(caseId) : new List<CaseComment>();
            List<Task>         tasks    = taskMap.containsKey(caseId)    ? taskMap.get(caseId)    : new List<Task>();
            List<FeedItem>     feeds    = feedMap.containsKey(caseId)    ? feedMap.get(caseId)    : new List<FeedItem>();

            CaseTransferService.CaseHistoryPayload payload = CaseTransferService.buildPayload(
                caseRecord, emails, comments, tasks, feeds
            );

            String maskedJson = maskPayload(payload);

            LLMIntegrationService.LLMResponse llmResponse =
                LLMIntegrationService.generateSummary(maskedJson, PROMPT_TEMPLATE_NAME);

            CaseTransferSummary__c summary = new CaseTransferSummary__c(
                Case__c               = caseId,
                GeneratedFor__c       = ownerName,
                GenerationTimestamp__c = System.now()
            );

            if (llmResponse.success) {
                summary.GenerationStatus__c = STATUS_SUCCESS;
                summary.SummaryText__c      = llmResponse.summaryText;
                summary.LLMResponseCode__c  = llmResponse.httpStatusCode;
                summary.LLMModelName__c     = llmResponse.modelName;
            } else {
                summary.GenerationStatus__c = STATUS_FAILED;
                summary.ErrorMessage__c     = llmResponse.errorMessage;
                summary.LLMResponseCode__c  = llmResponse.httpStatusCode;
            }

            summariesToInsert.add(summary);
        }

        if (!summariesToInsert.isEmpty()) {
            insert summariesToInsert;

            for (CaseTransferSummary__c inserted : summariesToInsert) {
                if (inserted.GenerationStatus__c == STATUS_SUCCESS) {
                    eventsToPublish.add(new CaseSummaryGenerated__e(
                        CaseId__c    = inserted.Case__c,
                        SummaryId__c = inserted.Id
                    ));
                }
            }

            if (!eventsToPublish.isEmpty()) {
                EventBus.publish(eventsToPublish);
            }
        }
    }

    /**
     * Serializes the payload to JSON and applies PIIMaskingService to all
     * text fields before the string is sent to the LLM.
     *
     * @param payload  Assembled CaseHistoryPayload.
     * @return         PII-masked JSON string.
     */
    private String maskPayload(CaseTransferService.CaseHistoryPayload payload) {
        String rawJson = JSON.serialize(payload);
        return PIIMaskingService.maskText(rawJson);
    }

    /**
     * Loads CaseSummarySettings__mdt configuration into a wrapper.
     * Applies safe defaults for null/invalid values.
     *
     * @return  CaseSummarySettingsWrapper with resolved values.
     */
    private CaseSummarySettingsWrapper loadSettings() {
        CaseSummarySettingsWrapper wrapper = new CaseSummarySettingsWrapper();
        List<CaseSummarySettings__mdt> settings = [
            SELECT Is_Active__c, Queueable_Chunk_Size__c, History_Record_Limit__c
            FROM   CaseSummarySettings__mdt
            LIMIT  1
        ];
        if (!settings.isEmpty()) {
            wrapper.isActive     = settings[0].Is_Active__c == true;
            Decimal chunkDecimal = settings[0].Queueable_Chunk_Size__c;
            wrapper.chunkSize    = (chunkDecimal != null && chunkDecimal >= 1)
                                   ? chunkDecimal.intValue()
                                   : DEFAULT_CHUNK_SIZE;
            Decimal histDecimal  = settings[0].History_Record_Limit__c;
            wrapper.historyLimit = (histDecimal != null && histDecimal >= 1)
                                   ? histDecimal.intValue()
                                   : DEFAULT_HISTORY_LIMIT;
        }
        return wrapper;
    }

    // ─── Bulk query helpers ───────────────────────────────────────────────────

    /** Builds a Map<CaseId, List<EmailMessage>> for the given Case IDs. */
    private Map<Id, List<EmailMessage>> buildEmailMap(Set<Id> caseIdSet, Integer lim) {
        Map<Id, List<EmailMessage>> result = new Map<Id, List<EmailMessage>>();
        for (EmailMessage em : [
            SELECT Id, Subject, TextBody, FromAddress, ToAddress, CreatedDate, ParentId
            FROM   EmailMessage
            WHERE  ParentId IN :caseIdSet
            ORDER BY CreatedDate DESC
            LIMIT  :lim
        ]) {
            if (!result.containsKey(em.ParentId)) {
                result.put(em.ParentId, new List<EmailMessage>());
            }
            result.get(em.ParentId).add(em);
        }
        return result;
    }

    /** Builds a Map<CaseId, List<CaseComment>> for the given Case IDs. */
    private Map<Id, List<CaseComment>> buildCommentMap(Set<Id> caseIdSet, Integer lim) {
        Map<Id, List<CaseComment>> result = new Map<Id, List<CaseComment>>();
        for (CaseComment cc : [
            SELECT Id, CommentBody, CreatedDate, ParentId
            FROM   CaseComment
            WHERE  ParentId IN :caseIdSet
            AND    IsPublished = true
            ORDER BY CreatedDate DESC
            LIMIT  :lim
        ]) {
            if (!result.containsKey(cc.ParentId)) {
                result.put(cc.ParentId, new List<CaseComment>());
            }
            result.get(cc.ParentId).add(cc);
        }
        return result;
    }

    /** Builds a Map<CaseId, List<Task>> for the given Case IDs. */
    private Map<Id, List<Task>> buildTaskMap(Set<Id> caseIdSet, Integer lim) {
        Map<Id, List<Task>> result = new Map<Id, List<Task>>();
        for (Task t : [
            SELECT Id, Subject, Description, Status, ActivityDate, CreatedDate, WhatId
            FROM   Task
            WHERE  WhatId IN :caseIdSet
            ORDER BY CreatedDate DESC
            LIMIT  :lim
        ]) {
            if (!result.containsKey(t.WhatId)) {
                result.put(t.WhatId, new List<Task>());
            }
            result.get(t.WhatId).add(t);
        }
        return result;
    }

    /** Builds a Map<CaseId, List<FeedItem>> for the given Case IDs. */
    private Map<Id, List<FeedItem>> buildFeedMap(Set<Id> caseIdSet, Integer lim) {
        Map<Id, List<FeedItem>> result = new Map<Id, List<FeedItem>>();
        for (FeedItem fi : [
            SELECT Id, Body, CreatedDate, Type, ParentId
            FROM   FeedItem
            WHERE  ParentId IN :caseIdSet
            ORDER BY CreatedDate DESC
            LIMIT  :lim
        ]) {
            if (!result.containsKey(fi.ParentId)) {
                result.put(fi.ParentId, new List<FeedItem>());
            }
            result.get(fi.ParentId).add(fi);
        }
        return result;
    }

    // ─── Settings wrapper ─────────────────────────────────────────────────────

    /** Internal wrapper for resolved CaseSummarySettings__mdt values. */
    private class CaseSummarySettingsWrapper {
        Boolean isActive     = true;
        Integer chunkSize    = DEFAULT_CHUNK_SIZE;
        Integer historyLimit = DEFAULT_HISTORY_LIMIT;
    }
}
