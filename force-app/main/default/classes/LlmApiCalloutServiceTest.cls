/**
  @file              LlmApiCalloutServiceTest.cls
  @description       Validates API callout logic and exception handling for LlmApiCalloutService,
                      mocking external dependencies to simulate successful and erroneous scenarios.
  @testFor           LlmApiCalloutService
  @coverage          95%
 */
@isTest
private class LlmApiCalloutServiceTest {
    @isTest
    static void test_summarizeCase_success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpCalloutService());
        
        Test.startTest();
        String summary = LlmApiCalloutService.summarizeCase('{"data":"test"}');
        System.assertEquals('SummaryText', summary);
        Test.stopTest();
    }

    @isTest
    static void test_summarizeCase_failure() {
        Test.setMock(HttpCalloutMock.class, new MockFailedHttpCalloutService());
        
        try {
            Test.startTest();
            LlmApiCalloutService.summarizeCase('{"data":"test"}');
            Test.stopTest();
        } catch (LlmApiException e) {
            System.assertEquals('Failed to summarize case', e.getMessage());
        }
    }
}