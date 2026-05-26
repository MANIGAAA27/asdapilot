/**
 * @file        LLMCalloutServiceTest.cls
 * @description Tests LLMCalloutService — covers the success response path and
 *              the error (non-200) response path, verifying LLMCalloutServiceException
 *              is correctly thrown on HTTP failure.
 * @testFor     LLMCalloutService
 * @coverage    Target ≥ 90%.
 */
@isTest
private class LLMCalloutServiceTest {

    @isTest
    static void test_generateSummary_successResponse_returnsSummaryText() {
        Test.setMock(HttpCalloutMock.class, new LLMCalloutServiceMock());

        Test.startTest();
        String result = LLMCalloutService.generateSummary(
            '{"metadata":{"caseId":"5000000000000001","subject":"Login failure"}}'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'generateSummary must return non-null on success');
        System.assert(result.length() > 0, 'generateSummary must return non-empty text on success');
    }

    @isTest
    static void test_generateSummary_errorResponse_throwsException() {
        Test.setMock(HttpCalloutMock.class, new LLMCalloutServiceMockFailure());

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            LLMCalloutService.generateSummary('{"metadata":{"caseId":"5000000000000001"}}');
        } catch (LLMCalloutService.LLMCalloutServiceException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('503'),
                'Exception message should include the HTTP status code');
        }
        Test.stopTest();

        System.assert(exceptionThrown,
            'Expected LLMCalloutServiceException to be thrown when LLM returns 503');
    }

    @isTest
    static void test_generateSummary_emptyChoices_throwsException() {
        // Simulate a 200 response that contains no choices
        Test.setMock(HttpCalloutMock.class, new EmptyChoicesMock());

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            LLMCalloutService.generateSummary('{}');
        } catch (LLMCalloutService.LLMCalloutServiceException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown,
            'Expected LLMCalloutServiceException when choices array is empty');
    }

    // ── Inner mock for the empty-choices edge case ────────────────────────────
    private class EmptyChoicesMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[]}');
            return res;
        }
    }
}