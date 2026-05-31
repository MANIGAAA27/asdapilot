/**
  @file              CaseTransferController.cls
  @description       Apex controller for handling case transfer operations from the LWC front-end component.
  @author            ASDA Dev Agent
  @lastModified      2026-05-28
  @dependencies      CaseTransferService
  @calledBy          CaseTransferForm LWC
  @testClass         CaseTransferControllerTest
 */
public with sharing class CaseTransferController {
    /**
      Submits the case transfer request after performing necessary validations.
      
      @param recordId Id of the Case to be transferred.
      @param reproductionSteps Selected reproduction steps.
      @param troubleshootingSteps Entered troubleshooting steps.
      @throws AuraHandledException if any errors occur during processing.
      @calledBy CaseTransferForm.handleSubmit
      @testMethods testSubmitCaseTransferSuccess, testSubmitCaseTransferValidationFailure
     */
    @AuraEnabled
    public static void submitCaseTransfer(Id recordId, List<String> reproductionSteps, String troubleshootingSteps) {
        try {
            CaseTransferService transferService = new CaseTransferService();
            transferService.transferCaseToEngineering(recordId, reproductionSteps, troubleshootingSteps);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
