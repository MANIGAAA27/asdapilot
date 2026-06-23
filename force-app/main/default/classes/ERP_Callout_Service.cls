/**
 * @file              ERP_Callout_Service.cls
 * @description       Handles REST callouts to the external ERP system for the
 *                    Account 360 experience. Encapsulates authentication (via
 *                    Named Credential), timeout handling, and response parsing.
 *                    Returns a typed ERPResponse for clean error propagation to
 *                    the service layer.
 * @author            ASDA Dev Agent
 * @created           2026-06-23
 * @lastModified      2026-06-23
 * @group             Account360
 *
 * @dependencies      (Named Credential: ERP_Integration must exist in the org)
 * @calledBy          (none in this changeset — invoked by ERP_Initial_Sync_Queueable)
 * @testClass         ERP_Callout_ServiceTest
 *
 * @see               HLD-CMP-003: ERP_Callout_Service
 */

// MODIFIED 2026-06-23 — Project: Account 360 | CodeImplementation-Account360 | ASDA
/**
 * Integration service for outbound ERP REST callouts.
 *
 * Responsibilities:
 *   - Construct and send HTTP GET requests to the ERP financial-summary endpoint.
 *   - Parse HTTP responses into ERPResponse DTOs.
 *   - Handle callout exceptions (timeout, DNS failure) gracefully.
 *   - Log 4xx/5xx responses with status code and body for diagnostics.
 *
 * Threading: static methods, no instance state.
 *
 * @testClass ERP_Callout_ServiceTest
 */
public with sharing class ERP_Callout_Service {

    @TestVisible
    private static final String ERP_NAMED_CREDENTIAL = 'callout:ERP_Integration';
    @TestVisible
    private static final String ERP_ENDPOINT_PATH = '/api/v1/accounts/{0}/financial-summary';
    @TestVisible
    private static final Integer CALLOUT_TIMEOUT_MS = 10000;

    // ─────────────────────────────────────────────────────────────────
    // Inner DTO
    // ─────────────────────────────────────────────────────────────────

    /**
     * Typed response object for ERP callout results.
     * Callers check `success` first, then read `rawPayload` or `errorMessage`.
     */
    public class ERPResponse {
        @AuraEnabled public Boolean success     { get; set; }
        @AuraEnabled public String  rawPayload  { get; set; }
        @AuraEnabled public String  errorMessage { get; set; }
        @AuraEnabled public Integer statusCode  { get; set; }

        /** Constructs a success response from an HTTP 2xx reply. */
        public ERPResponse(Integer httpStatusCode, String body) {
            this.success      = true;
            this.statusCode   = httpStatusCode;
            this.rawPayload   = body;
            this.errorMessage = null;
        }

        /** Constructs an error response from a caught exception or non-2xx reply. */
        public ERPResponse(Integer httpStatusCode, String body, String errMsg) {
            this.success      = false;
            this.statusCode   = httpStatusCode;
            this.rawPayload   = body;
            this.errorMessage = errMsg;
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────

    /**
     * Fetches the financial summary for an ERP customer from the external API.
     * Uses a Named Credential for OAuth 2.0 token management.
     *
     * @param  erpCustomerId  External ERP customer identifier (Account.ERP_Customer_ID__c value).
     * @return                ERPResponse with success=true and rawPayload on HTTP 200–299,
     *                        or success=false and errorMessage on any failure.
     *                        Never returns null.
     *
     * @calledBy    (ERP_Initial_Sync_Queueable — not in this changeset)
     * @testMethods test_fetchERPData_success_returnsPayload,
     *              test_fetchERPData_serverError_returnsErrorResponse,
     *              test_fetchERPData_calloutException_returnsErrorResponse,
     *              test_fetchERPData_blankId_returnsErrorResponse
     */
    public static ERPResponse fetchERPData(String erpCustomerId) {
        if (String.isBlank(erpCustomerId)) {
            return new ERPResponse(0, null, 'ERP Customer ID is required.');
        }
        String endpointUrl = ERP_NAMED_CREDENTIAL
            + String.format(ERP_ENDPOINT_PATH, new List<Object>{ EncodingUtil.urlEncode(erpCustomerId, 'UTF-8') });
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpointUrl);
        req.setMethod('GET');
        req.setTimeout(CALLOUT_TIMEOUT_MS);
        req.setHeader('Accept', 'application/json');
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            Integer statusCode = res.getStatusCode();
            if (statusCode >= 200 && statusCode < 300) {
                return new ERPResponse(statusCode, res.getBody());
            }
            return new ERPResponse(
                statusCode,
                res.getBody(),
                'ERP returned HTTP ' + statusCode + ': ' + res.getStatus()
            );
        } catch (CalloutException ex) {
            return new ERPResponse(0, null, 'ERP callout failed: ' + ex.getMessage());
        }
    }
}
