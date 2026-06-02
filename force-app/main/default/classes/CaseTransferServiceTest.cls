@isTest
private class CaseTransferServiceTest {
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
            Subject = 'Transfer Service Test Case',
            Status = 'New',
            Origin = 'Phone'
        );
        insert testCase;
    }

    private static Id createContentVersionAndLink(Id caseId) {
        ContentVersion cv = new ContentVersion(
            Title = 'log-file',
            PathOnClient = 'log-file.txt',
            VersionData = Blob.valueOf('test log content')
        );
        insert cv;

        ContentVersion storedVersion = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        ContentDocumentLink linkRecord = new ContentDocumentLink(
            LinkedEntityId = caseId,
            ContentDocumentId = storedVersion.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert linkRecord;
        return storedVersion.ContentDocumentId;
    }

    @isTest
    static void testValidateCaseTransferInvalid() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Transfer Service Test Case' LIMIT 1];

        Test.startTest();
        CaseTransferService.TransferValidationResult result = CaseTransferService.validateCaseTransfer(testCase.Id);
        Test.stopTest();

        System.assertEquals(false, result.isValid);
        System.assert(result.messages.contains(CaseTransferConstants.ERROR_ATTACHMENTS));
        System.assert(result.messages.contains(CaseTransferConstants.ERROR_REPRO_STEPS));
        System.assert(result.messages.contains(CaseTransferConstants.ERROR_TROUBLESHOOTING));
    }

    @isTest
    static void testSubmitTransferSuccess() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Transfer Service Test Case' LIMIT 1];
        createContentVersionAndLink(testCase.Id);

        Test.startTest();
        Id updatedCaseId = CaseTransferService.submitTransfer(
            testCase.Id,
            'Performed restart, cache clear, config review, and replicated behavior in sandbox.',
            new List<String>{ 'Always', 'Intermittent' }
        );
        Test.stopTest();

        Case updatedCase = [
            SELECT OwnerId, Troubleshooting_Steps__c, Reproduction_Steps__c, Transfer_Submitted_To_Engineering__c
            FROM Case
            WHERE Id = :updatedCaseId
        ];
        Id engineeringQueueId = CaseTransferService.getEngineeringQueueId();

        System.assertEquals(engineeringQueueId, updatedCase.OwnerId);
        System.assertEquals(true, updatedCase.Transfer_Submitted_To_Engineering__c);
        System.assert(updatedCase.Reproduction_Steps__c.contains('Always'));
    }

    @isTest
    static void testSubmitTransferMissingFilesThrows() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Transfer Service Test Case' LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            CaseTransferService.submitTransfer(
                testCase.Id,
                'Performed restart, cache clear, config review, and replicated behavior in sandbox.',
                new List<String>{ 'Always' }
            );
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('Please attach at least one relevant log file'));
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }
}
