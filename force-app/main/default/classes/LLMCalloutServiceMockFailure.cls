/**
 * @file        LLMCalloutServiceMockFailure.cls
 * @description HttpCalloutMock that simulates a 503 Service Unavailable error
 *              from the LLM endpoint. Used in negative test paths to verify that
 *              LLMCalloutServiceException is thrown and the transfer record is
 *              saved with Generation_Status__c = Failed.
 * @testFor     LLMCalloutService
 */
@isTest
global class LLMCalloutServiceMockFailure implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(503);
        res.setBody('{"error":{"message":"Service temporarily unavailable","type":"server_error"}}');
        return res;
    }
}