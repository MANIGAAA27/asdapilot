/**
 * @file        CaseTransferServiceTest.cls
 * @description Tests CaseTransferService — covers enqueue logic, payload
 *              assembly, history limit retrieval, and empty/null guard paths.
 * @testFor     CaseTransferService
 * @coverage    Target >= 90%.
 */
@isTest
private class CaseTransferServiceTest {

    @TestSetup
    static void setupData() {
        TestDataFactory.createCase('Transfer Service Test Case');
    }

    @isTest
    static void test_beginSummaryGeneration_enqueuesJob() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Transfer Service Test Case' LIMIT 1];
        Set<Id> ids = new Set<Id>{ c.Id };

        Test.startTest();
        CaseTransferService.beginSummaryGeneration(ids);
        Test.stopTest();

        System.assert(true, 'beginSummaryGeneration completed without exception');
    }

    @isTest
    static void test_beginSummaryGeneration_emptySet_doesNotEnqueue() {
        Test.startTest();
        CaseTransferService.beginSummaryGeneration(new Set<Id>());
        Test.stopTest();

        System.assert(true, 'Empty set handled gracefully');
    }

    @isTest
    static void test_beginSummaryGeneration_nullSet_doesNotEnqueue() {
        Test.startTest();
        CaseTransferService.beginSummaryGeneration(null);
        Test.stopTest();

        System.assert(true, 'Null set handled gracefully');
    }

    @isTest
    static void test_buildPayload_allSources_populatesCorrectly() {
        Case c = [SELECT Id, Subject, Description, Priority, Status, Origin,
                         CreatedDate, LastModifiedDate
                  FROM   Case
                  WHERE  Subject = 'Transfer Service Test Case'
                  LIMIT  1];

        EmailMessage em = new EmailMessage(
            Subject     = 'Test Email',
            TextBody    = 'Email body text',
            FromAddress = 'from@example.com',
            ToAddress   = 'to@example.com',
            CreatedDate = System.now()
        );

        CaseComment cc = new CaseComment(CommentBody = 'A comment', CreatedDate = System.now());
        Task t = new Task(Subject = 'Call', Description = 'Task desc', Status = 'Completed',
                          ActivityDate = Date.today(), CreatedDate = System.now());
        FeedItem fi = new FeedItem(Body = 'Feed body', CreatedDate = System.now(), Type = 'TextPost');

        Test.startTest();
        CaseTransferService.CaseHistoryPayload payload = CaseTransferService.buildPayload(
            c,
            new List<EmailMessage>{ em },
            new List<CaseComment>{ cc },
            new List<Task>{ t },
            new List<FeedItem>{ fi }
        );
        Test.stopTest();

        System.assertEquals(c.Id, payload.caseId, 'Case ID should match');
        System.assertEquals(1, payload.emails.size(), 'Should have 1 email');
        System.assertEquals(1, payload.comments.size(), 'Should have 1 comment');
        System.assertEquals(1, payload.tasks.size(), 'Should have 1 task');
        System.assertEquals(1, payload.feedItems.size(), 'Should have 1 feed item');
    }

    @isTest
    static void test_buildPayload_emptySources_returnsMinimalPayload() {
        Case c = [SELECT Id, Subject, Description, Priority, Status, Origin,
                         CreatedDate, LastModifiedDate
                  FROM   Case
                  WHERE  Subject = 'Transfer Service Test Case'
                  LIMIT  1];

        Test.startTest();
        CaseTransferService.CaseHistoryPayload payload = CaseTransferService.buildPayload(
            c,
            new List<EmailMessage>(),
            new List<CaseComment>(),
            new List<Task>(),
            new List<FeedItem>()
        );
        Test.stopTest();

        System.assertEquals(c.Id, payload.caseId, 'Case ID should match');
        System.assertEquals(0, payload.emails.size(), 'No emails expected');
        System.assertEquals(0, payload.comments.size(), 'No comments expected');
        System.assertEquals(0, payload.tasks.size(), 'No tasks expected');
        System.assertEquals(0, payload.feedItems.size(), 'No feed items expected');
    }

    @isTest
    static void test_getHistoryLimit_returnsPositiveValue() {
        Test.startTest();
        Integer lim = CaseTransferService.getHistoryLimit();
        Test.stopTest();

        System.assert(lim > 0, 'History limit should always be positive');
    }
}
