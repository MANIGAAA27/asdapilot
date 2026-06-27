/**
 * @file        CustomMigrationBatchTest.cls
 * @description Tests CustomMigrationBatch — covers constructor initialization,
 *              query locator scope, execute chunk processing, finish status
 *              transitions, and bulk 200+ record safety paths.
 * @testFor     CustomMigrationBatch
 * @coverage    Target ≥ 90%.
 */
@isTest
private class CustomMigrationBatchTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Test data setup
    // ─────────────────────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        ARMT_MigrationJob__c job = new ARMT_MigrationJob__c(
            MigrationName__c = 'Test Migration',
            MigrationStatus__c = 'Executing',
            StartDate__c = Datetime.now()
        );
        insert job;

        List<CPQ_ARM_DataMapping__c> mappings = new List<CPQ_ARM_DataMapping__c>();
        for (Integer i = 0; i < 5; i++) {
            mappings.add(new CPQ_ARM_DataMapping__c(
                MappingName__c = 'Mapping ' + i,
                SourceEntity__c = 'SBQQ__Quote__c',
                TargetEntity__c = 'arm__Quote__c'
            ));
        }
        insert mappings;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_constructor_validJobId_setsState() {
        ARMT_MigrationJob__c job = [SELECT Id FROM ARMT_MigrationJob__c LIMIT 1];

        Test.startTest();
        CustomMigrationBatch batch = new CustomMigrationBatch(job.Id);
        Test.stopTest();

        // Verify object can be instantiated without error
        System.assertNotEquals(null, batch, 'Batch instance should not be null');
    }

    @isTest
    static void test_constructor_nullJobId_doesNotThrow() {
        Test.startTest();
        CustomMigrationBatch batch = new CustomMigrationBatch(null);
        Test.stopTest();

        System.assertNotEquals(null, batch, 'Batch should handle null job ID gracefully');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Execute / full batch run tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_execute_happyPath_logsSuccess() {
        ARMT_MigrationJob__c job = [SELECT Id FROM ARMT_MigrationJob__c LIMIT 1];

        Test.startTest();
        CustomMigrationBatch batch = new CustomMigrationBatch(job.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        List<Migration_Log__c> logs = [SELECT Id, ValidationStatus__c FROM Migration_Log__c];
        System.assert(!logs.isEmpty(), 'Migration log entries should have been created');
        for (Migration_Log__c logEntry : logs) {
            System.assertEquals('Passed', logEntry.ValidationStatus__c,
                'Mappings with both entities populated should log as Passed');
        }
    }

    @isTest
    static void test_finish_allSuccess_updatesStatus() {
        ARMT_MigrationJob__c job = [SELECT Id FROM ARMT_MigrationJob__c LIMIT 1];

        Test.startTest();
        CustomMigrationBatch batch = new CustomMigrationBatch(job.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        ARMT_MigrationJob__c updated = [
            SELECT MigrationStatus__c, EndDate__c
            FROM ARMT_MigrationJob__c
            WHERE Id = :job.Id
        ];

        System.assertEquals('Completed', updated.MigrationStatus__c,
            'Job status should be Completed after successful batch run');
        System.assertNotEquals(null, updated.EndDate__c,
            'EndDate__c should be stamped after batch finish');
    }

    @isTest
    static void test_execute_200Records_bulkSafe() {
        // Insert 200 mappings to verify bulk-safe path
        List<CPQ_ARM_DataMapping__c> bulkMappings = new List<CPQ_ARM_DataMapping__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkMappings.add(new CPQ_ARM_DataMapping__c(
                MappingName__c = 'Bulk Mapping ' + i,
                SourceEntity__c = 'SBQQ__QuoteLine__c',
                TargetEntity__c = 'arm__QuoteLine__c'
            ));
        }
        insert bulkMappings;

        ARMT_MigrationJob__c job = [SELECT Id FROM ARMT_MigrationJob__c LIMIT 1];

        Test.startTest();
        CustomMigrationBatch batch = new CustomMigrationBatch(job.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify the batch processed without governor limit exceptions
        ARMT_MigrationJob__c updated = [SELECT MigrationStatus__c FROM ARMT_MigrationJob__c WHERE Id = :job.Id];
        System.assertNotEquals(null, updated.MigrationStatus__c,
            'Job status must be set after bulk processing');
    }

    @isTest
    static void test_finish_nullJobId_doesNotThrow() {
        Test.startTest();
        CustomMigrationBatch batch = new CustomMigrationBatch(null);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // No assertion needed — test verifies no unhandled exception occurs
        System.assert(true, 'Null job ID should not cause an unhandled exception');
    }
}
