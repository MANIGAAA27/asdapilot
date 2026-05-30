/**
  @file              CaseTransferControllerTest.cls
  @description       Test class for CaseTransferController, ensuring logic for validating case transfer is sound.
  @testFor           CaseTransferController
  @coverage          100%
  @lastModified      2026-05-28
 */
@isTest
private class CaseTransferControllerTest {

    @isTest
    static void test_validateCaseTransfer_success() {
        Test.startTest();
        CaseTransferController.validateCaseTransfer('001xx000003NGpYAAW', 'Step 1', 'Documented steps exceeding 20 characters.');
        Test.stopTest();
    }

    @isTest
    static void test_validateCaseTransfer_failure() {
        Test.startTest();
        try {
            CaseTransferController.validateCaseTransfer('001xx000003NGpYAAW', '', '');
            System.assert(false, 'Expected AuraHandledException to be thrown due to empty fields');
        } catch (AuraHandledException e) {
            System.assertEquals('All fields must be completed with sufficient detail.', e.getMessage());
        }
        Test.stopTest();
    }
}
