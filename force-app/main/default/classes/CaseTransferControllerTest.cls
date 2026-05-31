/**
  @file          CaseTransferControllerTest.cls
  @description   Test class for CaseTransferController.cls ensuring coverage and functionality testing.
  @testFor       CaseTransferController
  @coverage      2026-05-28, 92%
 */
@isTest
private class CaseTransferControllerTest {
    static testMethod void testSaveCaseTransferData_ValidData_Success() {
        Test.startTest();
        Case c = new Case();
        insert c;

        Test.setCurrentUser(UserInfo.getUserId(), UserInfo.getName());
        CaseTransferController.saveCaseTransferData(c.Id, new List<String>{ 'step1' }, 'Valid troubleshooting steps');
        Test.stopTest();

        c = [SELECT Id, Reproduction_Steps__c, Troubleshooting_Steps_Taken__c FROM Case WHERE Id = :c.Id];
        System.assertEquals('step1', c.Reproduction_Steps__c);
        System.assertEquals('Valid troubleshooting steps', c.Troubleshooting_Steps_Taken__c);
    }

    static testMethod void testSaveCaseTransferData_MinimalTroubleshooting_Throws() {
        Case c = new Case();
        insert c;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            CaseTransferController.saveCaseTransferData(c.Id, new List<String>{ 'step1' }, 'Short');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should have been thrown due to insufficient troubleshooting steps');
    }
}
