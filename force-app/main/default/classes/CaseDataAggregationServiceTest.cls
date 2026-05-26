/**
 * @file        CaseDataAggregationServiceTest.cls
 * @description Tests CaseDataAggregationService — covers successful aggregation,
 *              timestamp-based exclusion, and missing-case failure path.
 * @testFor     CaseDataAggregationService
 * @coverage    Target ≥ 90%.
 */
@isTest
private class CaseDataAggregationServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acc = TestDataFactory.createAccount('Aggregation Test Account');
        Contact con = TestDataFactory.createContact('Jane', 'Smith', acc.Id);
        Case testCase = TestDataFactory.createCase('Aggregation Test Case', acc.Id, con.Id);

        CaseComment comment = new CaseComment(
            ParentId     = testCase.Id,
            CommentBody  = 'Internal agent note for aggregation testing.',
            IsPublished  = false
        );
        insert comment;
    }

    @isTest
    static void test_aggregateCaseData_validCaseId_returnsAggregatedData() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Map<String, Object> result = CaseDataAggregationService.aggregateCaseData(
            testCase.Id, System.now()
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Expected non-null result map');
        System.assert(result.containsKey('caseRecord'),  'Result must contain caseRecord');
        System.assert(result.containsKey('emails'),      'Result must contain emails');
        System.assert(result.containsKey('comments'),    'Result must contain comments');
        System.assert(result.containsKey('history'),     'Result must contain history');
        System.assertNotEquals(null, result.get('caseRecord'), 'caseRecord must not be null');
    }

    @isTest
    static void test_aggregateCaseData_excludesDataAfterTransfer_correctlyFilters() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        // Use a timestamp far in the past — the comment was inserted just now,
        // so it must be excluded.
        DateTime pastCutoff = DateTime.newInstance(2000, 1, 1, 0, 0, 0);

        Test.startTest();
        Map<String, Object> result = CaseDataAggregationService.aggregateCaseData(
            testCase.Id, pastCutoff
        );
        Test.stopTest();

        List<CaseComment> comments = (List<CaseComment>) result.get('comments');
        System.assertEquals(0, comments.size(),
            'Comments created after the cutoff must be excluded from the payload');
    }

    @isTest
    static void test_aggregateCaseData_invalidCaseId_throwsException() {
        // Use a fake but syntactically valid Case Id.
        Id fakeCaseId = '5000000000000001';

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            CaseDataAggregationService.aggregateCaseData(fakeCaseId, System.now());
        } catch (CaseDataAggregationService.CaseDataAggregationServiceException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown,
            'Expected CaseDataAggregationServiceException for non-existent Case Id');
    }
}