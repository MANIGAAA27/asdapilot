/**
  @file              SummarizationQueueable.cls
  @description       Queueable class for handling asynchronous summarization of Cases upon transfer event detection.
  @author            ASDA Dev Agent
  @lastModified      2023-10-31
  @dependencies      CaseSummarizationService
  @calledBy          Case_After_Update_Trigger_Summarization
  @testClass         SummarizationQueueableTest
 */
/* MODIFIED 2026-06-27 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA */
public with sharing class SummarizationQueueable implements Queueable, Database.AllowsCallouts {
    private Id caseId;

    public SummarizationQueueable(Id caseId) {
        this.caseId = caseId;
    }

    /**
     * Invocable entry point called by the Case_After_Update_Trigger_Summarization flow.
     * Accepts a list of Case Id strings (Flow always passes list types to @InvocableMethod)
     * and enqueues a SummarizationQueueable job for each.
     *
     * @param caseIds  List of Case Id strings passed by the invoking flow.
     */
    @InvocableMethod(label='Enqueue Summarization' description='Enqueues asynchronous case summarization jobs.')
    public static void enqueueSummarization(List<String> caseIds) {
        for (String caseIdStr : caseIds) {
            if (String.isNotBlank(caseIdStr)) {
                System.enqueueJob(new SummarizationQueueable((Id) caseIdStr));
            }
        }
    }

    public void execute(QueueableContext context) {
        try {
            String payload = CaseSummarizationService.aggregateCaseData(caseId);
            String summary = generateSummary(payload);
            Case_Transfer_Summary__c summaryRecord = new Case_Transfer_Summary__c(
                Case__c = caseId,
                Summary__c = summary,
                Generated_At__c = System.now()
            );
            insert summaryRecord;
        } catch (Exception e) {
            logError(e.getMessage());
        }
    }

    private void logError(String errorMsg) {
        try {
            Case_Transfer_Summary_Error__c errorRecord = new Case_Transfer_Summary_Error__c(
                Case__c = caseId,
                Error_Message__c = errorMsg,
                Timestamp__c = System.now()
            );
            insert errorRecord;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Failed to log summarization error: ' + ex.getMessage());
        }
    }

    private String generateSummary(String payload) {
        return 'Generated summary for payload: ' + payload;
    }
}
