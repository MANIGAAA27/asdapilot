/**
  @file              CaseTransferController.cls
  @description       Handles logic for validating case transfer inputs for Case Transfer Flow.
  @author            ASDA Dev Agent
  @lastModified      2026-05-28
  @dependencies      None
  @calledBy          LWC caseTransferForm
  @testClass         CaseTransferControllerTest
 */
public with sharing class CaseTransferController {
    
    /**
      Validates inputs needed for transferring Case to Engineering.
      @param caseId ID of the Case being transferred.
      @param reproductionSteps Steps on how to reproduce the issue.
      @param troubleshootingSteps Steps already taken to troubleshoot.
      @throws AuraHandledException If validation fails.
      @calledBy caseTransferForm.handleSubmit
      @testMethods test_validateCaseTransfer_success, test_validateCaseTransfer_failure
     */
    @AuraEnabled
    public static void validateCaseTransfer(Id caseId, String reproductionSteps, String troubleshootingSteps) {
        try {
            // Basic validations
            if (String.isEmpty(reproductionSteps) || String.isEmpty(troubleshootingSteps) || troubleshootingSteps.length() < 20) {
                throw new AuraHandledException('All fields must be completed with sufficient detail.');
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
