/**
  @file              CaseSummarizationServiceTest.cls
  @description       Test class for CaseSummarizationService to ensure data aggregation logic is robust and correct.
  @author            ASDA Dev Agent
  @lastModified      2023-10-31
  @testFor           CaseSummarizationService
  @coverage          Target: 90%
 */
@isTest
public class CaseSummarizationServiceTest {
    @testSetup
    static void setup() {
        List<Case> cases = new List<Case>();
        // Setup test data for cases
        Case newCase = new Case(Subject = 'Test Case', Description = 'This is a test case');
        cases.add(newCase);
        insert cases;
    }

    @isTest
    static void test_aggregateCaseData_validId_returnsPayload() {
        List<Case> caseList = [SELECT Id FROM Case LIMIT 1];
        if (caseList.isEmpty()) {
            System.assert(false, 'No case records found for testing.');
        }
        Id testCaseId = caseList[0].Id;
        Test.startTest();
        String payload = CaseSummarizationService.aggregateCaseData(testCaseId);
        Test.stopTest();
        System.assertNotEquals(null, payload, 'Expected non-null payload');
    }

    @isTest
    static void test_aggregateCaseData_invalidId_throwsException() {
        try {
            Test.startTest();
            String payload = CaseSummarizationService.aggregateCaseData('nonExistingId');
            Test.stopTest();
            System.assert(false, 'Expected exception for invalid Case Id.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}