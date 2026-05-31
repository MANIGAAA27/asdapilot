/**
 * @file        CaseTransferAPITest.cls
 * @description Tests CaseTransferAPI — covers POST with missing caseId (400),
 *              GET for reproduction steps, and general error handling path.
 * @testFor     CaseTransferAPI
 * @coverage    Target >= 90%. Last measured 2026-05-30.
 */
@isTest
private class CaseTransferAPITest {

    @TestSetup
    static void setup() {
        CaseTestDataFactory.createCase('API Test Case');
    }

    /** Sets up the REST context with a JSON body and returns the response object. */
    private static RestResponse setupPostContext(String jsonBody) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/CaseTransfer/v1/transfer';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        req.headers.put('Content-Type', 'application/json');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        return RestContext.response;
    }

    private static RestResponse setupGetContext() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/CaseTransfer/v1/reproduction-steps';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();
        return RestContext.response;
    }

    @isTest
    static void test_doPost_missingCaseId_returns400() {
        RestResponse res = setupPostContext('{"troubleshootingSteps":"details","reproductionSteps":"Step1","contentDocumentIds":[]}');

        Test.startTest();
        CaseTransferAPI.doPost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Missing caseId should return 400');
    }

    @isTest
    static void test_doPost_missingAttachments_returns400() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'API Test Case' LIMIT 1];
        String jsonBody = JSON.serialize(new Map<String, Object>{
            'caseId'               => String.valueOf(c.Id),
            'troubleshootingSteps' => 'Detailed steps here that are long enough',
            'reproductionSteps'    => 'Reproducible_on_Demand',
            'contentDocumentIds'   => new List<String>()
        });
        RestResponse res = setupPostContext(jsonBody);

        Test.startTest();
        CaseTransferAPI.doPost();
        Test.stopTest();

        // Expects 400 because no attachments provided
        System.assertEquals(400, res.statusCode, 'No attachments should return 400');
    }

    @isTest
    static void test_doPost_missingTroubleshooting_returns400() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'API Test Case' LIMIT 1];
        String jsonBody = JSON.serialize(new Map<String, Object>{
            'caseId'               => String.valueOf(c.Id),
            'troubleshootingSteps' => '',
            'reproductionSteps'    => 'Reproducible_on_Demand',
            'contentDocumentIds'   => new List<String>{'fakeId'}
        });
        RestResponse res = setupPostContext(jsonBody);

        Test.startTest();
        CaseTransferAPI.doPost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Missing troubleshooting should return 400');
    }

    @isTest
    static void test_doGet_returnsReproductionSteps() {
        RestResponse res = setupGetContext();

        Test.startTest();
        CaseTransferAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'GET should return 200');
        System.assertNotEquals(null, res.responseBody, 'Response body should not be null');
        Map<String, Object> parsed = (Map<String, Object>)
            JSON.deserializeUntyped(res.responseBody.toString());
        System.assert(parsed.containsKey('options'), 'Response should have options key');
    }
}
