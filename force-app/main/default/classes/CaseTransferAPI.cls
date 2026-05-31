/**
 * @file              CaseTransferAPI.cls
 * @description       REST API exposing endpoints to initiate case transfers and retrieve
 *                    reproduction step options. Designed for external system integration
 *                    in Phase 2+. Uses urlMapping '/CaseTransfer/v1/*' with method-level
 *                    routing via the HTTP verb and URL suffix.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             CaseTransfer
 *
 * @dependencies      CaseTransferService, CaseTransferController, CaseTransferException,
 *                    ErrorLogger
 * @calledBy          (none in this changeset — external API consumers)
 * @testClass         CaseTransferAPITest
 *
 * @see               LLD Case Transfer Flow — API Design §6
 */

/**
 * REST resource for Case Transfer operations.
 *
 * Endpoints:
 *   POST /services/apexrest/CaseTransfer/v1/transfer
 *     Body: { caseId, troubleshootingSteps, reproductionSteps, contentDocumentIds[] }
 *     Returns: { success, message, caseId }
 *
 *   GET /services/apexrest/CaseTransfer/v1/reproduction-steps
 *     Returns: { options: [{label, value}] }
 *
 * @testClass CaseTransferAPITest
 */
@RestResource(urlMapping='/CaseTransfer/v1/*')
global with sharing class CaseTransferAPI {

    /**
     * Handles POST requests to initiate a case transfer.
     * Parses the JSON body, validates inputs, and delegates to CaseTransferService.
     *
     * Expected JSON body:
     * {
     *   "caseId": "500xx...",
     *   "troubleshootingSteps": "...",
     *   "reproductionSteps": "Step1;Step2",
     *   "contentDocumentIds": ["069xx...", ...]
     * }
     *
     * @return  Serialised Map with 'success' (Boolean), 'message' (String), 'caseId' (String).
     *
     * @calledBy   External API consumers
     * @testMethods test_doPost_missingRequiredFields_returns400,
     *              test_doPost_validPayload_returns200
     */
    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        Map<String, Object> responseBody = new Map<String, Object>();
        try {
            Map<String, Object> payload = (Map<String, Object>)
                JSON.deserializeUntyped(req.requestBody.toString());

            String caseId             = (String) payload.get('caseId');
            String troubleshootingSteps = (String) payload.get('troubleshootingSteps');
            String reproductionSteps  = (String) payload.get('reproductionSteps');
            List<Object> rawDocIds    = (List<Object>) payload.get('contentDocumentIds');

            if (String.isBlank(caseId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'message' => 'caseId is required'
                }));
                return;
            }

            List<String> contentDocumentIds = new List<String>();
            if (rawDocIds != null) {
                for (Object docId : rawDocIds) {
                    contentDocumentIds.add(String.valueOf(docId));
                }
            }

            CaseTransferService svc = new CaseTransferService();
            svc.executeTransfer(
                (Id) caseId,
                troubleshootingSteps,
                reproductionSteps,
                contentDocumentIds
            );

            responseBody.put('success', true);
            responseBody.put('message', System.Label.CaseTransfer_SuccessMessages);
            responseBody.put('caseId', caseId);
            res.statusCode = 200;
        } catch (CaseTransferException ex) {
            ErrorLogger.logException(ex, 'CaseTransferAPI.doPost');
            res.statusCode = 400;
            responseBody.put('success', false);
            responseBody.put('message', ex.getMessage());
        } catch (Exception ex) {
            ErrorLogger.logException(ex, 'CaseTransferAPI.doPost');
            res.statusCode = 500;
            responseBody.put('success', false);
            responseBody.put('message', System.Label.CaseTransfer_ErrorMessages);
        }
        res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
    }

    /**
     * Handles GET requests to retrieve the list of available reproduction steps.
     * Delegates to CaseTransferController.getReproductionStepOptions for schema-driven data.
     *
     * @return  Serialised Map with 'options' (List of {label, value} maps).
     *
     * @calledBy   External API consumers
     * @testMethods test_doGet_returnsReproductionSteps
     */
    @HttpGet
    global static void doGet() {
        RestResponse res = RestContext.response;
        Map<String, Object> responseBody = new Map<String, Object>();
        try {
            List<Map<String, String>> options = CaseTransferController.getReproductionStepOptions();
            responseBody.put('options', options);
            res.statusCode = 200;
        } catch (Exception ex) {
            ErrorLogger.logException(ex, 'CaseTransferAPI.doGet');
            res.statusCode = 500;
            responseBody.put('success', false);
            responseBody.put('message', System.Label.CaseTransfer_ErrorMessages);
        }
        res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
    }
}
