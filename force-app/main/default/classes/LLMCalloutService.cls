/**
 * @file              LLMCalloutService.cls
 * @description       Sends a structured JSON payload to the configured LLM
 *                    endpoint via a Named Credential ('LLMEndpoint') and returns
 *                    the generated summary text. Validates that the response
 *                    is non-empty before returning per FR13. The calling context
 *                    (CaseSummaryTransferQueueable) is already async, satisfying
 *                    the non-blocking requirement.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-25
 * @lastModified      2026-05-25
 * @group             CaseSummaryTransfer
 *
 * @dependencies      (none — uses Named Credential 'LLMEndpoint')
 * @calledBy          CaseSummaryTransferQueueable
 * @testClass         LLMCalloutServiceTest
 *
 * @see               LLD-Case Summary Transfer 1.0 §2.4 LLM Service
 */
public with sharing class LLMCalloutService {

    /** Named Credential configured for the LLM endpoint (admin-configurable). */
    @TestVisible
    private static final String NAMED_CREDENTIAL = 'LLMEndpoint';

    /** API path appended to the Named Credential base URL. */
    private static final String API_PATH = '/v1/chat/completions';

    /** Default model identifier; admin can override via Custom Metadata. */
    @TestVisible
    private static final String DEFAULT_MODEL = 'gpt-4';

    /** Token limit for the generated summary. */
    private static final Integer MAX_RESPONSE_TOKENS = 1000;

    /** HTTP timeout in milliseconds (30 s). */
    private static final Integer TIMEOUT_MS = 30000;

    /**
     * System prompt instructing the LLM to produce a structured transfer summary.
     * The structure mirrors FR12: customer issue, key actions, status, open questions.
     */
    private static final String SYSTEM_PROMPT =
        'You are a support case transfer assistant. ' +
        'Given the JSON case data below, produce a concise structured summary with exactly four sections:\n' +
        '1. Customer Issue Summary\n' +
        '2. Key Actions Taken\n' +
        '3. Current Status\n' +
        '4. Open Questions / Pending Actions\n' +
        'Be factual. Do not invent information not present in the data.';

    /**
     * Sends the JSON payload to the LLM and returns the generated summary text.
     *
     * @param  jsonPayload  Structured JSON string produced by CaseTransferPayloadBuilder.
     * @return Non-empty summary text from the LLM.
     * @throws LLMCalloutServiceException when the HTTP call fails, the response
     *         status is not 200, or the returned content is blank.
     *
     * @calledBy    CaseSummaryTransferQueueable.execute
     * @testMethods test_generateSummary_successResponse_returnsSummaryText,
     *              test_generateSummary_errorResponse_throwsException
     */
    public static String generateSummary(String jsonPayload) {
        HttpRequest req = buildRequest(jsonPayload);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (System.CalloutException ex) {
            throw new LLMCalloutServiceException(
                'LLM callout failed (network/timeout): ' + ex.getMessage()
            );
        }

        if (res.getStatusCode() != 200) {
            throw new LLMCalloutServiceException(
                'LLM API returned HTTP ' + res.getStatusCode() +
                ': ' + res.getBody()
            );
        }

        return extractContent(res.getBody());
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /** Constructs the HTTP request for the chat-completions endpoint. */
    private static HttpRequest buildRequest(String jsonPayload) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'model'    => DEFAULT_MODEL,
            'messages' => new List<Object>{
                new Map<String, Object>{
                    'role'    => 'system',
                    'content' => SYSTEM_PROMPT
                },
                new Map<String, Object>{
                    'role'    => 'user',
                    'content' => jsonPayload
                }
            },
            'max_tokens' => MAX_RESPONSE_TOKENS
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + API_PATH);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(TIMEOUT_MS);
        req.setBody(JSON.serialize(requestBody));
        return req;
    }

    /** Parses the LLM response JSON and extracts the text content. */
    private static String extractContent(String responseBody) {
        Map<String, Object> parsed =
            (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        List<Object> choices = (List<Object>) parsed.get('choices');
        if (choices == null || choices.isEmpty()) {
            throw new LLMCalloutServiceException(
                'LLM API response contained no choices: ' + responseBody
            );
        }

        Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
        Map<String, Object> message     = (Map<String, Object>) firstChoice.get('message');
        String content = (String) message.get('content');

        if (String.isBlank(content)) {
            throw new LLMCalloutServiceException(
                'LLM API returned blank content in response.'
            );
        }
        return content;
    }

    /** Custom exception for all LLM callout failures. */
    public class LLMCalloutServiceException extends Exception {}
}