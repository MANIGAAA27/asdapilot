/**
  @file              CaseSummarizationInvocable.cls
  @description       Provides an invocable method for triggering the case summarization asynchronously through a queueable job. This class acts as a bridge between Flows and Asynchronous Apex processes.
  @dependencies      SummarizationQueueable
  @calledBy          Case_After_Update_Trigger_Summarization Flow
  @testClass         CaseSummarizationInvocableTest
 */
public with sharing class CaseSummarizationInvocable {
    @InvocableMethod
    public static void processCaseSummaries(List<Id> caseIds) {
        System.enqueueJob(new SummarizationQueueable(new Set<Id>(caseIds)));
    }
}