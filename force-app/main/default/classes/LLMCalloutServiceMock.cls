/**
 * @file        LLMCalloutServiceMock.cls
 * @description HttpCalloutMock that simulates a successful LLM 200 response.
 *              Returns a minimal valid OpenAI-compatible chat-completions JSON body
 *              so that LLMCalloutService.extractContent() succeeds.
 * @testFor     LLMCalloutService
 */
@isTest
global class LLMCalloutServiceMock implements HttpCalloutMock {

    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        res.setBody(
            '{"choices":[{"message":{"role":"assistant","content":' +
            '"1. Customer Issue Summary: Customer reported login failure.\n' +
            '2. Key Actions Taken: Agent reset password and verified account.\n' +
            '3. Current Status: Awaiting customer confirmation.\n' +
            '4. Open Questions: Did customer receive reset email?"}}]}'
        );
        return res;
    }
}