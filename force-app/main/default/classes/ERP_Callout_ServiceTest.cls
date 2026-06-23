/**
 * @file        ERP_Callout_ServiceTest.cls
 * @description Tests ERP_Callout_Service — covers success, HTTP 500,
 *              blank customer ID, and callout exception paths using
 *              inner HttpCalloutMock implementations.
 * @testFor     ERP_Callout_Service
 * @coverage    Target ≥ 90%.
 */
// MODIFIED 2026-06-23 — Project: Account 360 | CodeImplementation-Account360 | ASDA
@isTest
private class ERP_Callout_ServiceTest {

    // ─────────────────────────────────────────────────────────────────
    // Inner mock classes (all HttpCalloutMock implementations must be
    // inner classes or separate .cls files — inner is preferred here
    // to keep test-specific logic co-located)
    // ─────────────────────────────────────────────────────────────────

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"accountId":"ERP-CUST-001","outstandingBalance":15000.00,"invoiceStatus":"Sent"}');
            return res;
        }
    }

    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error":"Internal server error"}');
            return res;
        }
    }

    private class NotFoundMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setStatus('Not Found');
            res.setBody('{"error":"Customer not found"}');
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // Tests
    // ─────────────────────────────────────────────────────────────────

    @isTest
    static void test_fetchERPData_success_returnsPayload() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        ERP_Callout_Service.ERPResponse response = ERP_Callout_Service.fetchERPData('ERP-CUST-001');
        Test.stopTest();
        System.assertEquals(true, response.success, 'Success flag should be true for HTTP 200');
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
        System.assertNotEquals(null, response.rawPayload, 'Raw payload should not be null');
        System.assert(response.rawPayload.contains('ERP-CUST-001'), 'Payload should contain customer ID');
    }

    @isTest
    static void test_fetchERPData_serverError_returnsErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());
        Test.startTest();
        ERP_Callout_Service.ERPResponse response = ERP_Callout_Service.fetchERPData('ERP-CUST-002');
        Test.stopTest();
        System.assertEquals(false, response.success, 'Success flag should be false for HTTP 500');
        System.assertEquals(500, response.statusCode, 'Status code should be 500');
        System.assertNotEquals(null, response.errorMessage, 'Error message should be populated');
    }

    @isTest
    static void test_fetchERPData_notFound_returnsErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new NotFoundMock());
        Test.startTest();
        ERP_Callout_Service.ERPResponse response = ERP_Callout_Service.fetchERPData('UNKNOWN-CUST');
        Test.stopTest();
        System.assertEquals(false, response.success, 'Success flag should be false for HTTP 404');
        System.assertEquals(404, response.statusCode, 'Status code should be 404');
    }

    @isTest
    static void test_fetchERPData_blankId_returnsErrorResponse() {
        Test.startTest();
        ERP_Callout_Service.ERPResponse response = ERP_Callout_Service.fetchERPData('');
        Test.stopTest();
        System.assertEquals(false, response.success, 'Success should be false for blank customer ID');
        System.assertEquals(0, response.statusCode, 'Status code should be 0 for validation error');
        System.assertNotEquals(null, response.errorMessage, 'Error message should be populated');
    }

    @isTest
    static void test_fetchERPData_nullId_returnsErrorResponse() {
        Test.startTest();
        ERP_Callout_Service.ERPResponse response = ERP_Callout_Service.fetchERPData(null);
        Test.stopTest();
        System.assertEquals(false, response.success, 'Success should be false for null customer ID');
        System.assertNotEquals(null, response.errorMessage, 'Error message should describe the issue');
    }

    @isTest
    static void test_fetchERPData_erpResponseConstructors_populatedCorrectly() {
        // Test success constructor
        ERP_Callout_Service.ERPResponse successResp = new ERP_Callout_Service.ERPResponse(200, '{"ok":true}');
        System.assertEquals(true,   successResp.success,       'Success constructor: success should be true');
        System.assertEquals(200,    successResp.statusCode,    'Success constructor: statusCode should be 200');
        System.assertEquals('{"ok":true}', successResp.rawPayload, 'Success constructor: payload should match');
        System.assertEquals(null,   successResp.errorMessage,  'Success constructor: errorMessage should be null');

        // Test error constructor
        ERP_Callout_Service.ERPResponse errorResp = new ERP_Callout_Service.ERPResponse(500, null, 'Server down');
        System.assertEquals(false,       errorResp.success,       'Error constructor: success should be false');
        System.assertEquals(500,         errorResp.statusCode,    'Error constructor: statusCode should be 500');
        System.assertEquals('Server down', errorResp.errorMessage, 'Error constructor: errorMessage should match');
    }
}
