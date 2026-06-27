/**
 * @file              ARM_MigrationScheduler.cls
 * @description       Handles scheduling of ARMT migration jobs. Implements the
 *                    Schedulable interface to allow recurring or one-time execution
 *                    of the CustomMigrationBatch. Provides @AuraEnabled methods so
 *                    the LWC layer (JobTrackerComponent, DataMappingWizard) can
 *                    trigger on-demand batch execution and retrieve job status.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-27
 * @lastModified      2026-06-27
 * @group             ARMTOrchestration
 *
 * @dependencies      CustomMigrationBatch
 * @calledBy          JobTrackerComponent (LWC via @AuraEnabled), system scheduler
 * @testClass         ARM_MigrationSchedulerTest
 *
 * @see               HLD-CMP-001 ARMT_JobManagerService (Feature: Advanced Record Migration Tool)
 */

/**
 * Schedulable orchestrator for ARMT migration batch jobs.
 *
 * Responsibilities:
 *   - Schedule CustomMigrationBatch via Salesforce cron expressions.
 *   - Provide @AuraEnabled entry points for LWC-initiated batch execution.
 *   - Update ARMT_MigrationJob__c StartDate__c and MigrationStatus__c on kick-off.
 *   - Return job status summaries to the UI layer.
 *
 * Threading: Schedulable execute() is always async; @AuraEnabled methods are
 * synchronous and enqueue batch jobs — do not call heavy DML directly.
 *
 * @testClass ARM_MigrationSchedulerTest
 */
public with sharing class ARM_MigrationScheduler implements Schedulable {

    /** The Id of the ARMT_MigrationJob__c to execute when the scheduled run fires. */
    private Id migrationJobId;

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Constructs the scheduler bound to a specific migration job.
     *
     * @param migrationJobId  The ARMT_MigrationJob__c Id to execute. Must not be null.
     *
     * @calledBy    ARM_MigrationSchedulerTest, System.schedule()
     * @testMethods test_constructor_validJobId_setsState
     */
    public ARM_MigrationScheduler(Id migrationJobId) {
        this.migrationJobId = migrationJobId;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Schedulable interface
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Invoked by the Salesforce scheduler at the configured cron interval.
     * Kicks off the CustomMigrationBatch for the bound migration job.
     *
     * @param  sc  SchedulableContext provided by the platform.
     *
     * @calledBy  Salesforce platform (scheduler)
     * @testMethods test_execute_scheduledRun_enqueuesBatch
     */
    public void execute(SchedulableContext sc) {
        if (migrationJobId != null) {
            executeMigrationBatch(migrationJobId);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // @AuraEnabled controller methods (called from LWC)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Starts a migration batch run for the given ARMT_MigrationJob__c record.
     * Updates the job's status to 'Executing' and stamps StartDate__c before
     * enqueuing the batch.
     *
     * @param  jobId  The Id of the ARMT_MigrationJob__c to execute.
     * @return        The AsyncApexJob Id for the enqueued batch, for UI polling.
     * @throws        AuraHandledException if jobId is blank or job is not found.
     *
     * @calledBy    JobTrackerComponent.startMigration()
     * @testMethods test_startMigration_validJob_returnsBatchId,
     *              test_startMigration_nullJobId_throwsException
     */
    @AuraEnabled
    public static Id startMigration(Id jobId) {
        if (jobId == null) {
            throw new AuraHandledException('Migration Job Id is required.');
        }

        List<ARMT_MigrationJob__c> jobs = [
            SELECT Id, MigrationStatus__c
            FROM ARMT_MigrationJob__c
            WHERE Id = :jobId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (jobs.isEmpty()) {
            throw new AuraHandledException('Migration Job not found: ' + jobId);
        }

        ARMT_MigrationJob__c job = jobs[0];
        job.MigrationStatus__c = 'Executing';
        job.StartDate__c = Datetime.now();

        try {
            update job;
        } catch (DmlException ex) {
            throw new AuraHandledException('Failed to update job status: ' + ex.getMessage());
        }

        return executeMigrationBatch(jobId);
    }

    /**
     * Retrieves the current status of an ARMT_MigrationJob__c for the UI.
     *
     * @param  jobId  The Id of the ARMT_MigrationJob__c to query.
     * @return        The ARMT_MigrationJob__c record with status fields populated.
     * @throws        AuraHandledException if jobId is null.
     *
     * @calledBy    JobTrackerComponent.pollJobStatus()
     * @testMethods test_getJobStatus_validId_returnsRecord,
     *              test_getJobStatus_nullId_throwsException
     */
    @AuraEnabled(cacheable=true)
    public static ARMT_MigrationJob__c getJobStatus(Id jobId) {
        if (jobId == null) {
            throw new AuraHandledException('Job Id is required.');
        }

        List<ARMT_MigrationJob__c> jobs = [
            SELECT Id, Name, MigrationName__c, MigrationStatus__c, StartDate__c, EndDate__c
            FROM ARMT_MigrationJob__c
            WHERE Id = :jobId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (jobs.isEmpty()) {
            throw new AuraHandledException('Migration Job not found: ' + jobId);
        }

        return jobs[0];
    }

    /**
     * Returns all ARMT_MigrationJob__c records ordered by creation date, for the
     * job list view in the JobTrackerComponent.
     *
     * @param  recordLimit  Maximum number of records to return. Defaults to 25 if null or ≤ 0.
     * @return              List of ARMT_MigrationJob__c records.
     *
     * @calledBy    JobTrackerComponent.loadJobs()
     * @testMethods test_getRecentJobs_returnsUpToLimit
     */
    @AuraEnabled(cacheable=true)
    public static List<ARMT_MigrationJob__c> getRecentJobs(Integer recordLimit) {
        if (recordLimit == null || recordLimit <= 0) {
            recordLimit = 25;
        }
        return [
            SELECT Id, Name, MigrationName__c, MigrationStatus__c, StartDate__c, EndDate__c
            FROM ARMT_MigrationJob__c
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT :recordLimit
        ];
    }

    /**
     * Returns all CPQ_ARM_DataMapping__c records for the DataMappingWizard LWC.
     *
     * @param  recordLimit  Maximum number of records to return. Defaults to 50 if null or ≤ 0.
     * @return              List of CPQ_ARM_DataMapping__c records.
     *
     * @calledBy    DataMappingWizard.loadMappings()
     * @testMethods test_getDataMappings_returnsRecords
     */
    @AuraEnabled(cacheable=true)
    public static List<CPQ_ARM_DataMapping__c> getDataMappings(Integer recordLimit) {
        if (recordLimit == null || recordLimit <= 0) {
            recordLimit = 50;
        }
        return [
            SELECT Id, Name, MappingName__c, SourceEntity__c, TargetEntity__c
            FROM CPQ_ARM_DataMapping__c
            WITH SECURITY_ENFORCED
            ORDER BY MappingName__c ASC
            LIMIT :recordLimit
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Enqueues a CustomMigrationBatch instance for the given job Id and returns the batch job Id. */
    private static Id executeMigrationBatch(Id jobId) {
        CustomMigrationBatch batchJob = new CustomMigrationBatch(jobId);
        return Database.executeBatch(batchJob, 100);
    }
}
