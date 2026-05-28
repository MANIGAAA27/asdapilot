/**
 * FileServiceTest
 *
 * Unit tests for FileService. Covers happy-path file retrieval, error
 * handling, child-record aggregation, deduplication, and helper methods.
 * Minimum 90% line coverage target.
 */
@isTest
private class FileServiceTest {

    // -----------------------------------------------------------------------
    // Test data setup
    // -----------------------------------------------------------------------

    @TestSetup
    static void setupData() {
        // Parent Account
        Account acc = new Account(Name = 'File Viewer Test Account');
        insert acc;

        // File directly on the Account
        ContentVersion cv = new ContentVersion(
            Title       = 'Account Test File',
            PathOnClient = 'account_test.pdf',
            VersionData  = Blob.valueOf('Account file content'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion cvWithDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cvWithDocId.ContentDocumentId,
            LinkedEntityId    = acc.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert cdl;
    }

    // -----------------------------------------------------------------------
    // getRelatedFiles tests
    // -----------------------------------------------------------------------

    @isTest
    static void getRelatedFiles_returnsFilesForParentRecord() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'File Viewer Test Account' LIMIT 1];

        Test.startTest();
        List<FileService.FileWrapper> files = FileService.getRelatedFiles(acc.Id);
        Test.stopTest();

        System.assertEquals(1, files.size(), 'Expected exactly one file linked to the account');
        System.assertEquals('Account Test File', files[0].title, 'File title should match');
        System.assertNotEquals(null, files[0].contentDocumentId, 'ContentDocumentId should be populated');
        System.assertNotEquals(null, files[0].fileUrl,           'fileUrl should be populated');
        System.assertNotEquals(null, files[0].fileSizeFormatted, 'fileSizeFormatted should be populated');
        System.assertNotEquals(null, files[0].createdByName,     'createdByName should be populated');
        System.assertNotEquals(null, files[0].createdDate,       'createdDate should be populated');
    }

    @isTest
    static void getRelatedFiles_fileUrlContainsContentDocumentId() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'File Viewer Test Account' LIMIT 1];

        Test.startTest();
        List<FileService.FileWrapper> files = FileService.getRelatedFiles(acc.Id);
        Test.stopTest();

        System.assert(
            files[0].fileUrl.contains(files[0].contentDocumentId),
            'fileUrl should contain the ContentDocumentId'
        );
        System.assert(
            files[0].fileUrl.startsWith('/sfc/servlet.shepherd/document/download/'),
            'fileUrl should use the Salesforce file download path'
        );
    }

    @isTest
    static void getRelatedFiles_noFilesReturnsEmptyList() {
        // New Account with no files attached
        Account emptyAcc = new Account(Name = 'Empty Account No Files');
        insert emptyAcc;

        Test.startTest();
        List<FileService.FileWrapper> files = FileService.getRelatedFiles(emptyAcc.Id);
        Test.stopTest();

        System.assertEquals(0, files.size(), 'Expected empty list for account with no files');
    }

    @isTest
    static void getRelatedFiles_blankRecordIdThrowsException() {
        Test.startTest();
        try {
            FileService.getRelatedFiles('');
            System.assert(false, 'Expected AuraHandledException for blank record ID');
        } catch (AuraHandledException ex) {
            System.assert(true, 'AuraHandledException correctly thrown for blank record ID');
        }
        Test.stopTest();
    }

    @isTest
    static void getRelatedFiles_includesFilesFromChildContact() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'File Viewer Test Account' LIMIT 1];

        // Child Contact under the Account
        Contact con = new Contact(LastName = 'FileViewer Test Contact', AccountId = acc.Id);
        insert con;

        // File on the Contact
        ContentVersion cv = new ContentVersion(
            Title        = 'Contact Related File',
            PathOnClient = 'contact_file.docx',
            VersionData  = Blob.valueOf('Contact file content'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion cvWithDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cvWithDocId.ContentDocumentId,
            LinkedEntityId    = con.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        List<FileService.FileWrapper> files = FileService.getRelatedFiles(acc.Id);
        Test.stopTest();

        // Should include at minimum the account file (1) plus the contact file (1)
        System.assert(files.size() >= 2, 'Expected parent file plus child Contact file; found: ' + files.size());
    }

    @isTest
    static void getRelatedFiles_deduplicatesFilesLinkedToMultipleRecords() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'File Viewer Test Account' LIMIT 1];

        // The same ContentDocument linked to both Account and a Contact
        Contact con = new Contact(LastName = 'Dedup Test Contact', AccountId = acc.Id);
        insert con;

        ContentVersion cv = new ContentVersion(
            Title        = 'Shared File',
            PathOnClient = 'shared.pdf',
            VersionData  = Blob.valueOf('Shared content'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion cvWithDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        // Link to Account
        insert new ContentDocumentLink(
            ContentDocumentId = cvWithDocId.ContentDocumentId,
            LinkedEntityId    = acc.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        // Link same file to Contact
        insert new ContentDocumentLink(
            ContentDocumentId = cvWithDocId.ContentDocumentId,
            LinkedEntityId    = con.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        Test.startTest();
        List<FileService.FileWrapper> files = FileService.getRelatedFiles(acc.Id);
        Test.stopTest();

        // Count how many entries have the shared file's contentDocumentId
        Integer sharedFileCount = 0;
        for (FileService.FileWrapper fw : files) {
            if (fw.title == 'Shared File') {
                sharedFileCount++;
            }
        }
        System.assertEquals(1, sharedFileCount, 'Shared file should appear exactly once (deduplicated)');
    }

    @isTest
    static void getRelatedFiles_fileSizeFormattedIsReadable() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'File Viewer Test Account' LIMIT 1];

        Test.startTest();
        List<FileService.FileWrapper> files = FileService.getRelatedFiles(acc.Id);
        Test.stopTest();

        // fileSizeFormatted should end with ' KB' or ' MB'
        Boolean readable = files[0].fileSizeFormatted.endsWith('KB')
                        || files[0].fileSizeFormatted.endsWith('MB');
        System.assert(readable, 'fileSizeFormatted should be a KB or MB string, got: ' + files[0].fileSizeFormatted);
    }

    // -----------------------------------------------------------------------
    // getObjectApiName tests
    // -----------------------------------------------------------------------

    @isTest
    static void getObjectApiName_returnsAccountForAccountId() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'File Viewer Test Account' LIMIT 1];

        Test.startTest();
        String objectName = FileService.getObjectApiName(acc.Id);
        Test.stopTest();

        System.assertEquals('Account', objectName, 'Object API name should be Account');
    }

    @isTest
    static void getObjectApiName_blankRecordIdThrowsException() {
        Test.startTest();
        try {
            FileService.getObjectApiName('');
            System.assert(false, 'Expected AuraHandledException for blank record ID');
        } catch (AuraHandledException ex) {
            System.assert(true, 'AuraHandledException correctly thrown for blank record ID');
        }
        Test.stopTest();
    }

    @isTest
    static void getObjectApiName_returnsContactForContactId() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'File Viewer Test Account' LIMIT 1];
        Contact con = new Contact(LastName = 'ObjectName Test', AccountId = acc.Id);
        insert con;

        Test.startTest();
        String objectName = FileService.getObjectApiName(con.Id);
        Test.stopTest();

        System.assertEquals('Contact', objectName, 'Object API name should be Contact');
    }

    @isTest
    static void getRelatedFiles_includesFilesFromChildOpportunity() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'File Viewer Test Account' LIMIT 1];

        // Child Opportunity under the Account
        Opportunity opp = new Opportunity(
            Name        = 'File Viewer Test Opportunity',
            AccountId   = acc.Id,
            StageName   = 'Prospecting',
            CloseDate   = Date.today().addDays(30)
        );
        insert opp;

        // File attached to the Opportunity
        ContentVersion cv = new ContentVersion(
            Title          = 'Opportunity Related File',
            PathOnClient   = 'opp_file.pdf',
            VersionData    = Blob.valueOf('Opportunity file content'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion cvWithDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cvWithDocId.ContentDocumentId,
            LinkedEntityId    = opp.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        List<FileService.FileWrapper> files = FileService.getRelatedFiles(acc.Id);
        Test.stopTest();

        // Must include both the Account file from @TestSetup and the Opportunity file
        System.assert(files.size() >= 2, 'Expected parent Account file plus child Opportunity file; found: ' + files.size());

        Boolean oppFileFound = false;
        for (FileService.FileWrapper fw : files) {
            if (fw.title == 'Opportunity Related File') {
                oppFileFound = true;
            }
        }
        System.assert(oppFileFound, 'Opportunity child file should be included in getRelatedFiles result');
    }
}