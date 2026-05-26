/**
 * @file              CaseSummaryTransferQueueable.cls
 * @description       Asynchronous orchestrator for the case transfer summary
 *                    pipeline. Implements Queueable + Database.AllowsCallouts to
 *                    execute the full flow in a single async transaction:
 *                      1. Aggregate case data (CaseDataAggregationService)
 *                      2. Build LLM payload (CaseTransferPayloadBuilder)
 *                      3. Call LLM endpoint (LLMCalloutService)
 *                      4. Persist result (CaseSummaryPersistenceService)
 *                    On any exception the queueable persists a 'Failed' summary
 *                    record containing the error detail so the transfer is never
 *                    blocked (PRD NFR 7.2).
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-25
 * @lastModified      2026-05-25
 * @group             CaseSummaryTransfer
 *
 * @dependencies      CaseDataAggregationService, CaseTransferPayloadBuilder,
 *                    LLMCalloutService, CaseSummaryPersistenceService
 * @calledBy          CaseSummaryTransferService
 * @testClass         CaseSummaryTransferQueueableTest
 *
 * @see               LLD-Case Summary Transfer 1.0 §3.1 Trigger Mechanism
 */
public with sharing class CaseSummaryTransferQueueable implements Queueable, Database.AllowsCallouts {

    private static final String DEFAULT_MODEL_NAME    = 'gpt-4';
    private static final String DEFAULT_MODEL_VERSION = '1.0';

    private final Id       caseId;
    private final DateTime transferTimestamp;

    /**
     * Constructs the queueable with the case context required to run the pipeline.
     *
     * @param  caseId             Id of the transferred Case.
     * @param  transferTimestamp  Exact timestamp of the ownership change.
     */
    public CaseSummaryTransferQueueable(Id caseId, DateTime transferTimestamp) {
        this.caseId            = caseId;
        this.transferTimestamp = transferTimestamp;
    }

    /**
     * Executes the full summary-generation pipeline.
     * Always persists a record — Success on happy path, Failed on any exception.
     * Failures are silently logged rather than re-thrown to keep the case transfer
     * workflow unaffected.
     *
     * @param  context  Queueable execution context (provided by the platform).
     *
     * @calledBy    (platform — via System.enqueueJob from CaseSummaryTransferService)
     * @testMethods test_execute_successfulLLMResponse_createsSummaryRecord,
     *              test_execute_failedLLMResponse_createsFailedRecord
     */
    public void execute(QueueableContext context) {
        String generationStatus = 'Failed';
        String summaryText      = '';

        try {
            Map<String, Object> aggregatedData =
                CaseDataAggregationService.aggregateCaseData(caseId, transferTimestamp);

            String jsonPayload = CaseTransferPayloadBuilder.buildPayload(aggregatedData);

            summaryText      = LLMCalloutService.generateSummary(jsonPayload);
            generationStatus = 'Success';

        } catch (Exception ex) {
            summaryText = 'Summary generation failed: ' + ex.getMessage();
            System.debug(LoggingLevel.ERROR,
                'CaseSummaryTransferQueueable.execute — error for case ' +
                caseId + ': ' + ex.getMessage()
            );
        }

        try {
            CaseSummaryPersistenceService.createSummaryRecord(
                caseId,
                summaryText,
                transferTimestamp,
                DEFAULT_MODEL_NAME,
                DEFAULT_MODEL_VERSION,
                generationStatus
            );
        } catch (Exception ex) {
            // Persist failures are logged only; the case transfer must succeed.
            System.debug(LoggingLevel.ERROR,
                'CaseSummaryTransferQueueable.execute — failed to persist record for case ' +
                caseId + ': ' + ex.getMessage()
            );
        }
    }
}