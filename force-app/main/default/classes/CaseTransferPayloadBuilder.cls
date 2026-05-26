/**
 * @file              CaseTransferPayloadBuilder.cls
 * @description       Converts aggregated case data into a structured JSON string
 *                    suitable for LLM ingestion. Enforces a character-based size
 *                    ceiling (MAX_PAYLOAD_CHARS) to comply with LLM token limits;
 *                    truncation preserves the JSON prefix (metadata is always first
 *                    so it survives truncation). Sections: metadata, customerInteractions,
 *                    internalNotes, activityLog.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-25
 * @lastModified      2026-05-25
 * @group             CaseSummaryTransfer
 *
 * @dependencies      CaseDataAggregationService
 * @calledBy          CaseSummaryTransferQueueable
 * @testClass         CaseTransferPayloadBuilderTest
 *
 * @see               LLD-Case Summary Transfer 1.0 §2.3 Payload Builder
 */
public with sharing class CaseTransferPayloadBuilder {

    /** Maximum characters allowed in the LLM payload before truncation. */
    @TestVisible
    private static final Integer MAX_PAYLOAD_CHARS = 50000;

    /**
     * Builds a structured JSON string from the aggregated case data map produced
     * by CaseDataAggregationService.aggregateCaseData().
     *
     * Sections in output JSON:
     *   - metadata:             case ID, number, subject, description, status, priority, dates.
     *   - customerInteractions: list of inbound/outbound email exchanges in chronological order.
     *   - internalNotes:        private CaseComments (IsPublished = false) in chronological order.
     *   - activityLog:          CaseHistory entries showing field changes over time.
     *
     * Truncation strategy: if the serialised JSON exceeds MAX_PAYLOAD_CHARS, the string
     * is hard-truncated to MAX_PAYLOAD_CHARS. The LLM is expected to handle partial JSON
     * gracefully; metadata (inserted first) is always preserved.
     *
     * @param  aggregatedData  Map returned by CaseDataAggregationService.aggregateCaseData().
     *                         Required keys: caseRecord, emails, comments, history.
     * @return JSON string ≤ MAX_PAYLOAD_CHARS characters.
     *
     * @calledBy    CaseSummaryTransferQueueable.execute
     * @testMethods test_buildPayload_validData_returnsJsonString,
     *              test_buildPayload_largePayload_truncatesCorrectly
     */
    public static String buildPayload(Map<String, Object> aggregatedData) {
        Case caseRecord            = (Case)              aggregatedData.get('caseRecord');
        List<EmailMessage> emails  = (List<EmailMessage>) aggregatedData.get('emails');
        List<CaseComment> comments = (List<CaseComment>) aggregatedData.get('comments');
        List<CaseHistory> history  = (List<CaseHistory>) aggregatedData.get('history');

        // ── Metadata section ────────────────────────────────────────────────────
        Map<String, Object> metadata = new Map<String, Object>{
            'caseId'         => String.valueOf(caseRecord.Id),
            'caseNumber'     => caseRecord.CaseNumber,
            'subject'        => caseRecord.Subject,
            'description'    => caseRecord.Description,
            'status'         => caseRecord.Status,
            'priority'       => caseRecord.Priority,
            'createdDate'    => String.valueOf(caseRecord.CreatedDate),
            'lastModified'   => String.valueOf(caseRecord.LastModifiedDate)
        };

        // ── Customer interactions (emails) ───────────────────────────────────────
        List<Map<String, Object>> interactions = new List<Map<String, Object>>();
        for (EmailMessage em : emails) {
            interactions.add(new Map<String, Object>{
                'type'      => 'Email',
                'direction' => em.Incoming ? 'Inbound' : 'Outbound',
                'date'      => String.valueOf(em.MessageDate),
                'from'      => em.FromAddress,
                'to'        => em.ToAddress,
                'subject'   => em.Subject,
                'body'      => em.TextBody
            });
        }

        // ── Internal notes (private CaseComments) ───────────────────────────────
        List<Map<String, Object>> internalNotes = new List<Map<String, Object>>();
        for (CaseComment cc : comments) {
            if (!cc.IsPublished) {
                internalNotes.add(new Map<String, Object>{
                    'date' => String.valueOf(cc.CreatedDate),
                    'body' => cc.CommentBody
                });
            }
        }

        // ── Activity log (CaseHistory) ───────────────────────────────────────────
        List<Map<String, Object>> activityLog = new List<Map<String, Object>>();
        for (CaseHistory ch : history) {
            activityLog.add(new Map<String, Object>{
                'date'     => String.valueOf(ch.CreatedDate),
                'field'    => ch.Field,
                'oldValue' => String.valueOf(ch.OldValue),
                'newValue' => String.valueOf(ch.NewValue)
            });
        }

        Map<String, Object> payload = new Map<String, Object>{
            'metadata'             => metadata,
            'customerInteractions' => interactions,
            'internalNotes'        => internalNotes,
            'activityLog'          => activityLog
        };

        String jsonPayload = JSON.serialize(payload);

        if (jsonPayload.length() > MAX_PAYLOAD_CHARS) {
            jsonPayload = jsonPayload.substring(0, MAX_PAYLOAD_CHARS);
        }

        return jsonPayload;
    }
}