@isTest
private class CaseTransferFlowTriggerTest {
    @testSetup
    static void setupData() {
        Group engineeringQueue = new Group(
            Name = 'Engineering',
            Type = 'Queue'
        );
        insert engineeringQueue;

        QueueSobject queueCase = new QueueSobject(
            QueueId = engineeringQueue.Id,
            SobjectType = 'Case'
        );
        insert queueCase;

        Case testCase = new Case(
            Subject = 'Trigger Test Case',
            Status = 'New',
            Origin = 'Phone'
        );
        insert testCase;
    }

    private static void attachFile(Id caseId) {
        ContentVersion cv = new ContentVersion(
            Title = 'trigger-log',
            PathOnClient = 'trigger-log.txt',
            VersionData = Blob.valueOf('trigger log content')
        );
        insert cv;

        ContentVersion storedVersion = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        insert new ContentDocumentLink(
            LinkedEntityId = caseId,
            ContentDocumentId = storedVersion.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    @isTest
    static void testEngineeringQueueTriggerBlocksIncompleteTransfer() {
        Case testCase = [SELECT Id, OwnerId FROM Case WHERE Subject = 'Trigger Test Case' LIMIT 1];
        Id engineeringQueueId = CaseTransferService.getEngineeringQueueId();

        Test.startTest();
        testCase.OwnerId = engineeringQueueId;
        Database.SaveResult saveResult = Database.update(testCase, false);
        Test.stopTest();

        System.assertEquals(false, saveResult.isSuccess());
        System.assert(saveResult.getErrors()[0].getMessage().contains('Please attach at least one relevant log file'));
    }

    @isTest
    static void testEngineeringQueueTriggerAllowsCompleteTransfer() {
        Case testCase = [SELECT Id, OwnerId FROM Case WHERE Subject = 'Trigger Test Case' LIMIT 1];
        attachFile(testCase.Id);
        Id engineeringQueueId = CaseTransferService.getEngineeringQueueId();

        testCase.Reproduction_Steps__c = 'Always';
        testCase.Troubleshooting_Steps__c = 'Performed several steps including restart, log review, and sandbox validation.';
        testCase.Transfer_Submitted_To_Engineering__c = true;
        testCase.OwnerId = engineeringQueueId;

        Test.startTest();
        update testCase;
        Test.stopTest();

        Case updatedCase = [SELECT OwnerId FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(engineeringQueueId, updatedCase.OwnerId);
    }
}
