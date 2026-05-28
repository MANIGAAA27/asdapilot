/**
  @file              CaseSummarizationService.cls
  @description       Service class responsible for aggregating Case data and preparing payloads.
  @author            ASDA Dev Agent
  @lastModified      2023-10-31
  @dependencies      (none in this changeset)
  @calledBy          SummarizationQueueable
  @testClass         CaseSummarizationServiceTest
 */
public with sharing class CaseSummarizationService {
    /**
      Aggregates relevant case data for summarization.
      @param caseId The ID of the case to summarize.
      @return JSON payload of aggregated data.
      @throws AuraHandledException if data aggregation fails.
      @calledBy SummarizationQueueable.execute
      @testMethods test_aggregateCaseData_validId_returnsPayload,
                   test_aggregateCaseData_invalidId_throwsException
     */
    @AuraEnabled(cacheable=true)
    public static String aggregateCaseData(Id caseId) {
        try {
            List<Case> cases = [SELECT Id, Subject, Description, (SELECT Body FROM CaseComments), (SELECT Body FROM Emails)
                                FROM Case WHERE Id = :caseId WITH SECURITY_ENFORCED];
            if (cases.isEmpty()) {
                throw new AuraHandledException('No Case found for the given ID.');
            }
            
            // Simulate data aggregation for demonstration
            // Assume logic merges comments, emails, description, etc. into a JSON format
            String jsonPayload = JSON.serialize(cases[0]);
            return jsonPayload;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}