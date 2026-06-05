/**
 * @file              LLMIntegrationService.cls
 * @description       Integration layer for LLM API callouts. Constructs the
 *                    HTTP request using a prompt template from
 *                    LLMPromptTemplate__mdt and a PII-masked case history
 *                    payload, executes the callout via Named Credential
 *                    (Generative_AI_LLM_Service), and returns a structured
 *                    LLMResponse. Implements HLD-CMP-006.
 *
 *                    Callout timeout is set to 60 seconds per HLD Section 10.2.
 *                    On HTTP 4xx the failure is treated as permanent; on 5xx
 *                    or CalloutException the caller should treat it as transient.
 *
 * @author            ASDA Dev Agent
 * @created           2026-06-05
 * @lastModified      2026-06-05
 * @group             CaseTransfer
 *
 * @dependencies      LLMPromptTemplate__mdt, Named Credential: Generative_AI_LLM_Service
 * @calledBy          CaseSummaryGeneratorQueueable
 * @testClass         LLMIntegrationServiceTest
 *
 * @see               HLD-CMP-006, HLD Section 7
 */
public with sharing class LLMIntegrationService {

    private static final Integer CALLOUT_TIMEOUT_MS  = 60000;
    private static final String  DEFAULT_PROMPT_NAME  = 'CaseTransferSummary';
    private static final String  NAMED_CREDENTIAL     = 'callout:Generative_AI_LLM_Service';

    /**
     * Performs the LLM callout for a given masked payload string.
     * Retrieves the prompt template from LLMPromptTemplate__mdt, constructs
     * the request body, executes the HTTP callout, and returns an LLMResponse.
     *
     * @param maskedPayloadJson  JSON string of the PII-masked case history payload.
     * @param promptTemplateName API name of the LLMPromptTemplate__mdt record to use.
     *                           Defaults to DEFAULT_PROMPT_NAME when null/blank.
     * @return LLMResponse containing success flag, summary text, HTTP status code,
     *         model name, and any error message.
     *
     * @calledBy    CaseSummaryGeneratorQueueable.execute
     * @testMethods test_generateSummary_successResponse_returnsText,
     *              test_generateSummary_errorResponse_returnsFailure,
     *              test_generateSummary_calloutException_returnsFailure
     */
    public static LLMResponse generateSummary(String maskedPayloadJson, String promptTemplateName) {
        String templateName = String.isBlank(promptTemplateName) ? DEFAULT_PROMPT_NAME : promptTemplateName;

        String promptText = loadPromptTemplate(templateName);
        String requestBody = buildRequestBody(promptText, maskedPayloadJson);

        LLMResponse response = new LLMResponse();
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL + '/v1/chat/completions');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(CALLOUT_TIMEOUT_MS);
            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            response.httpStatusCode = String.valueOf(res.getStatusCode());

            if (res.getStatusCode() == 200) {
                response.success     = true;
                response.summaryText = parseSummaryFromResponse(res.getBody());
                response.modelName   = parseModelFromResponse(res.getBody());
            } else {
                response.success      = false;
                response.errorMessage = 'LLM API returned HTTP ' + res.getStatusCode()
                                        + ': ' + res.getBody();
            }
        } catch (CalloutException ex) {
            response.success      = false;
            response.errorMessage = 'Callout failed: ' + ex.getMessage();
            response.httpStatusCode = '0';
        }

        return response;
    }

    /**
     * Loads the prompt text from LLMPromptTemplate__mdt for the given template name.
     * Returns a generic fallback prompt when no matching record is found.
     *
     * @param templateName  DeveloperName of the LLMPromptTemplate__mdt record.
     * @return              Prompt text string.
     */
    private static String loadPromptTemplate(String templateName) {
        List<LLMPromptTemplate__mdt> templates = [
            SELECT Prompt_Text__c
            FROM   LLMPromptTemplate__mdt
            WHERE  DeveloperName = :templateName
            LIMIT  1
        ];
        if (!templates.isEmpty() && String.isNotBlank(templates[0].Prompt_Text__c)) {
            return templates[0].Prompt_Text__c;
        }
        return 'You are a helpful assistant. Summarize the following case history '
             + 'for a service agent who has just received a transferred case. '
             + 'Be concise, factual, and highlight key issues and actions taken. '
             + 'Case history: ';
    }

    /**
     * Constructs the JSON request body for the LLM API call.
     *
     * @param promptText        The prompt template text.
     * @param maskedPayloadJson The PII-masked case history JSON.
     * @return                  Serialized JSON request body string.
     */
    private static String buildRequestBody(String promptText, String maskedPayloadJson) {
        Map<String, Object> message = new Map<String, Object>{
            'role'    => 'user',
            'content' => promptText + '\n\n' + maskedPayloadJson
        };
        Map<String, Object> body = new Map<String, Object>{
            'model'       => 'gpt-4',
            'messages'    => new List<Object>{ message },
            'max_tokens'  => 1024,
            'temperature' => 0.3
        };
        return JSON.serialize(body);
    }

    /**
     * Parses the summary text from the LLM API JSON response body.
     *
     * @param responseBody  Raw JSON response string from the LLM API.
     * @return              Extracted summary text, or empty string on parse failure.
     */
    private static String parseSummaryFromResponse(String responseBody) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> choices = (List<Object>) parsed.get('choices');
            if (choices != null && !choices.isEmpty()) {
                Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
                Map<String, Object> messageObj  = (Map<String, Object>) firstChoice.get('message');
                if (messageObj != null) {
                    return (String) messageObj.get('content');
                }
            }
        } catch (Exception ex) {
            return '';
        }
        return '';
    }

    /**
     * Parses the model name from the LLM API JSON response body.
     *
     * @param responseBody  Raw JSON response string from the LLM API.
     * @return              Model name string, or empty string on parse failure.
     */
    private static String parseModelFromResponse(String responseBody) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            Object model = parsed.get('model');
            return model != null ? String.valueOf(model) : '';
        } catch (Exception ex) {
            return '';
        }
    }

    // ─── Response wrapper ────────────────────────────────────────────────────

    /** Structured response returned by generateSummary(). */
    public class LLMResponse {
        public Boolean success       = false;
        public String  summaryText   = '';
        public String  errorMessage  = '';
        public String  httpStatusCode = '';
        public String  modelName     = '';
    }
}
