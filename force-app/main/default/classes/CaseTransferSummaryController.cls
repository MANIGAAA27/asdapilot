/**
  @file              CaseTransferSummaryController.cls
  @description       Controller for retrieving a case transfer summary associated with a case.
  @author            Yuki Tanaka
  @lastModified      2024-03-21
  @dependencies      Case_Transfer_Summary__c
  @calledBy          caseTransferSummary.js
  @testClass         CaseTransferSummaryControllerTest
 */
public with sharing class CaseTransferSummaryController {
    /**
      @description       Retrieves the most recent Case_Transfer_Summary__c record for a given Case Id.
      @param caseId      The Id of the case for which to retrieve the summary.
      @return            String containing the case transfer summary, or an empty string if none exists.
      @throws            AuraHandledException if the user lacks permissions or another error occurs during the query.
      @calledBy          caseTransferSummary.wiredSummary
      @testMethods       testGetCaseTransferSummary_HappyPath, testGetCaseTransferSummary_NoSummaryExists, testGetCaseTransferSummary_NoAccess
     */
    @AuraEnabled(cacheable=true)
    public static String getCaseTransferSummary(Id caseId) {
        try {
            List<Case_Transfer_Summary__c> summaries = [
                SELECT Summary__c 
                FROM Case_Transfer_Summary__c 
                WHERE Case__c = :caseId 
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (!summaries.isEmpty()) {
                return summaries[0].Summary__c;
            }
            return '';
        } catch (Exception e) {
            // Log the exception for administrators
            System.debug(LoggingLevel.ERROR, 'Failed to retrieve Case Transfer Summary for Case ID ' + caseId + '. Error: ' + e.getMessage());
            throw new AuraHandledException('An error occurred while retrieving the case summary. Please contact your administrator.');
        }
    }
}