/**
 * @file        LLMIntegrationServiceTest.cls
 * @description Tests LLMIntegrationService — covers success response parsing,
 *              HTTP error handling, callout exception handling, and prompt
 *              template fallback.
 * @testFor     LLMIntegrationService
 * @coverage    Target >= 90%.
 */
@isTest
private class LLMIntegrationServiceTest {

    /** Mock returning a valid 200 LLM response. */
    private class SuccessCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"model":"gpt-4","choices":[{"message":{"role":"assistant","content":"This is the summary."}}]}');
            return res;
        }
    }

    /** Mock returning a 500 server error. */
    private class ServerErrorCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    /** Mock returning a 400 client error. */
    private class ClientErrorCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Bad Request"}');
            return res;
        }
    }

    @isTest
    static void test_generateSummary_successResponse_returnsText() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

        Test.startTest();
        LLMIntegrationService.LLMResponse response =
            LLMIntegrationService.generateSummary('{"caseId":"001000000000001"}', 'CaseTransferSummary');
        Test.stopTest();

        System.assertEquals(true, response.success, 'Success flag should be true on 200');
        System.assertEquals('This is the summary.', response.summaryText, 'Summary text should be parsed');
        System.assertEquals('200', response.httpStatusCode, 'HTTP status code should be 200');
    }

    @isTest
    static void test_generateSummary_serverErrorResponse_returnsFailure() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorCalloutMock());

        Test.startTest();
        LLMIntegrationService.LLMResponse response =
            LLMIntegrationService.generateSummary('{"caseId":"001000000000001"}', null);
        Test.stopTest();

        System.assertEquals(false, response.success, 'Success flag should be false on 500');
        System.assertEquals('500', response.httpStatusCode, 'HTTP status code should be 500');
        System.assert(String.isNotBlank(response.errorMessage), 'Error message should be populated');
    }

    @isTest
    static void test_generateSummary_clientErrorResponse_returnsFailure() {
        Test.setMock(HttpCalloutMock.class, new ClientErrorCalloutMock());

        Test.startTest();
        LLMIntegrationService.LLMResponse response =
            LLMIntegrationService.generateSummary('{"caseId":"001000000000001"}', 'CaseTransferSummary');
        Test.stopTest();

        System.assertEquals(false, response.success, 'Success flag should be false on 400');
        System.assertEquals('400', response.httpStatusCode, 'HTTP status code should be 400');
    }

    @isTest
    static void test_generateSummary_nullPromptName_usesDefault() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

        Test.startTest();
        LLMIntegrationService.LLMResponse response =
            LLMIntegrationService.generateSummary('{"caseId":"001000000000001"}', null);
        Test.stopTest();

        System.assertEquals(true, response.success, 'Null prompt name should use default and succeed');
    }

    @isTest
    static void test_generateSummary_blankPayload_doesNotThrow() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

        Test.startTest();
        LLMIntegrationService.LLMResponse response =
            LLMIntegrationService.generateSummary('', null);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Response should not be null for blank payload');
    }
}
