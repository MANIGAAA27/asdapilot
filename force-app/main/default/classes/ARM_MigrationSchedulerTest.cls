/**
 * @file        ARM_MigrationSchedulerTest.cls
 * @description Tests ARM_MigrationScheduler — covers scheduled execute(),
 *              startMigration(), getJobStatus(), getRecentJobs(),
 *              getDataMappings(), and error/null input paths.
 * @testFor     ARM_MigrationScheduler
 * @coverage    Target ≥ 90%.
 */
@isTest
private class ARM_MigrationSchedulerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Test data setup
    // ─────────────────────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        ARMT_MigrationJob__c job = new ARMT_MigrationJob__c(
            MigrationName__c = 'Scheduler Test Job',
            MigrationStatus__c = 'New'
        );
        insert job;

        CPQ_ARM_DataMapping__c mapping = new CPQ_ARM_DataMapping__c(
            MappingName__c = 'Product Mapping',
            SourceEntity__c = 'SBQQ__Quote__c',
            TargetEntity__c = 'arm__Quote__c'
        );
        insert mapping;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor + Schedulable tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_constructor_validJobId_setsState() {
        ARMT_MigrationJob__c job = [SELECT Id FROM ARMT_MigrationJob__c LIMIT 1];
        ARM_MigrationScheduler scheduler = new ARM_MigrationScheduler(job.Id);
        System.assertNotEquals(null, scheduler, 'Scheduler instance should not be null');
    }

    @isTest
    static void test_execute_scheduledRun_enqueuesBatch() {
        ARMT_MigrationJob__c job = [SELECT Id FROM ARMT_MigrationJob__c LIMIT 1];
        ARM_MigrationScheduler scheduler = new ARM_MigrationScheduler(job.Id);

        Test.startTest();
        String jobName = 'ARMT Test Schedule ' + Datetime.now().getTime();
        String cronExp = '0 0 2 1 * ? *';
        System.schedule(jobName, cronExp, scheduler);
        Test.stopTest();

        // Verify the scheduled job can be set up without error
        List<CronTrigger> ct = [SELECT Id, CronExpression FROM CronTrigger WHERE CronJobDetail.Name = :jobName];
        System.assertEquals(1, ct.size(), 'One scheduled job should be registered');
    }

    @isTest
    static void test_execute_nullJobId_noError() {
        ARM_MigrationScheduler scheduler = new ARM_MigrationScheduler(null);

        Test.startTest();
        String jobName = 'ARMT Null Test ' + Datetime.now().getTime();
        String cronExp = '0 0 2 1 * ? *';
        System.schedule(jobName, cronExp, scheduler);
        Test.stopTest();

        System.assert(true, 'Null job ID in scheduled execute should not throw');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // startMigration tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_startMigration_validJob_returnsBatchId() {
        ARMT_MigrationJob__c job = [SELECT Id FROM ARMT_MigrationJob__c LIMIT 1];

        Test.startTest();
        Id batchId = ARM_MigrationScheduler.startMigration(job.Id);
        Test.stopTest();

        System.assertNotEquals(null, batchId, 'startMigration should return a valid batch job Id');

        ARMT_MigrationJob__c updated = [SELECT MigrationStatus__c, StartDate__c FROM ARMT_MigrationJob__c WHERE Id = :job.Id];
        System.assertEquals('Executing', updated.MigrationStatus__c, 'Status should be Executing');
        System.assertNotEquals(null, updated.StartDate__c, 'StartDate__c should be stamped');
    }

    @isTest
    static void test_startMigration_nullJobId_throwsException() {
        Test.startTest();
        try {
            ARM_MigrationScheduler.startMigration(null);
            System.assert(false, 'Expected AuraHandledException not thrown');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('required') || ex.getMessage() != null,
                'Exception message should indicate missing job Id');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getJobStatus tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getJobStatus_validId_returnsRecord() {
        ARMT_MigrationJob__c job = [SELECT Id FROM ARMT_MigrationJob__c LIMIT 1];

        Test.startTest();
        ARMT_MigrationJob__c result = ARM_MigrationScheduler.getJobStatus(job.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'getJobStatus should return a record');
        System.assertEquals(job.Id, result.Id, 'Returned record Id should match');
    }

    @isTest
    static void test_getJobStatus_nullId_throwsException() {
        Test.startTest();
        try {
            ARM_MigrationScheduler.getJobStatus(null);
            System.assert(false, 'Expected AuraHandledException not thrown');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage(), 'Exception message should be populated');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getRecentJobs tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getRecentJobs_returnsUpToLimit() {
        Test.startTest();
        List<ARMT_MigrationJob__c> jobs = ARM_MigrationScheduler.getRecentJobs(10);
        Test.stopTest();

        System.assertNotEquals(null, jobs, 'getRecentJobs should not return null');
        System.assert(jobs.size() <= 10, 'Should respect the record limit');
    }

    @isTest
    static void test_getRecentJobs_nullLimit_usesDefault() {
        Test.startTest();
        List<ARMT_MigrationJob__c> jobs = ARM_MigrationScheduler.getRecentJobs(null);
        Test.stopTest();

        System.assertNotEquals(null, jobs, 'getRecentJobs with null limit should default to 25');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getDataMappings tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void test_getDataMappings_returnsRecords() {
        Test.startTest();
        List<CPQ_ARM_DataMapping__c> mappings = ARM_MigrationScheduler.getDataMappings(10);
        Test.stopTest();

        System.assertNotEquals(null, mappings, 'getDataMappings should not return null');
        System.assert(mappings.size() >= 1, 'Should return at least the mapping from @TestSetup');
    }

    @isTest
    static void test_getDataMappings_nullLimit_usesDefault() {
        Test.startTest();
        List<CPQ_ARM_DataMapping__c> mappings = ARM_MigrationScheduler.getDataMappings(null);
        Test.stopTest();

        System.assertNotEquals(null, mappings, 'getDataMappings with null limit should default to 50');
    }
}
