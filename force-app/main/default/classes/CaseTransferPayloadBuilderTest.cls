/**
 * @file        CaseTransferPayloadBuilderTest.cls
 * @description Tests CaseTransferPayloadBuilder — verifies JSON structure and
 *              truncation behaviour at the MAX_PAYLOAD_CHARS boundary.
 * @testFor     CaseTransferPayloadBuilder
 * @coverage    Target ≥ 90%.
 */
@isTest
private class CaseTransferPayloadBuilderTest {

    @TestSetup
    static void setupTestData() {
        Account acc = TestDataFactory.createAccount('Payload Builder Test Account');
        TestDataFactory.createCase('Payload Builder Test Case', acc.Id, null);
    }

    @isTest
    static void test_buildPayload_validData_returnsJsonString() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Map<String, Object> aggregatedData = CaseDataAggregationService.aggregateCaseData(
            testCase.Id, System.now()
        );

        Test.startTest();
        String jsonPayload = CaseTransferPayloadBuilder.buildPayload(aggregatedData);
        Test.stopTest();

        System.assertNotEquals(null, jsonPayload,
            'buildPayload must return a non-null JSON string');
        System.assert(jsonPayload.length() > 0,
            'buildPayload must return a non-empty JSON string');
        System.assert(jsonPayload.contains('metadata'),
            'JSON must contain the metadata section');
        System.assert(jsonPayload.contains('customerInteractions'),
            'JSON must contain the customerInteractions section');
        System.assert(jsonPayload.contains('internalNotes'),
            'JSON must contain the internalNotes section');
        System.assert(jsonPayload.contains('activityLog'),
            'JSON must contain the activityLog section');
    }

    @isTest
    static void test_buildPayload_largePayload_truncatesCorrectly() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Insert a comment whose body alone exceeds MAX_PAYLOAD_CHARS
        CaseComment largeComment = new CaseComment(
            ParentId    = testCase.Id,
            CommentBody = 'x'.repeat(60000),
            IsPublished = false
        );
        insert largeComment;

        Map<String, Object> aggregatedData = CaseDataAggregationService.aggregateCaseData(
            testCase.Id, System.now()
        );

        Test.startTest();
        String jsonPayload = CaseTransferPayloadBuilder.buildPayload(aggregatedData);
        Test.stopTest();

        System.assert(jsonPayload.length() <= CaseTransferPayloadBuilder.MAX_PAYLOAD_CHARS,
            'buildPayload must truncate the JSON to MAX_PAYLOAD_CHARS (' +
            CaseTransferPayloadBuilder.MAX_PAYLOAD_CHARS + '); actual length: ' +
            jsonPayload.length());
    }

    @isTest
    static void test_buildPayload_metadataAlwaysPresent_inPayload() {
        Case testCase = [SELECT Id, CaseNumber FROM Case LIMIT 1];
        Map<String, Object> aggregatedData = CaseDataAggregationService.aggregateCaseData(
            testCase.Id, System.now()
        );

        Test.startTest();
        String jsonPayload = CaseTransferPayloadBuilder.buildPayload(aggregatedData);
        Test.stopTest();

        System.assert(jsonPayload.contains(testCase.CaseNumber),
            'Payload must include the CaseNumber in the metadata section');
    }
}