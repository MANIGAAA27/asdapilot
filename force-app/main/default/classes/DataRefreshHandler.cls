/**
 * @file              DataRefreshHandler.cls
 * @description       Orchestrates metadata sync and refresh operations for the Flow Dependency
 *                    Visualizer. Implements Schedulable for cron-based scheduling and Queueable
 *                    with AllowsCallouts for asynchronous Tooling API extraction. On each
 *                    execution, clears stale Flow_Dependency__c records, fetches active Flow
 *                    metadata from the Tooling API, parses dependencies, and persists them.
 *                    Transitive dependencies up to depth 3 are expanded after direct deps are stored.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-20
 * @lastModified      2026-06-20
 * @group             FlowDependencyVisualizer
 *
 * @dependencies      MetadataExtractionService, DependencyCalculationService
 * @calledBy          System.schedule (via scheduleRefresh), triggerManualRefresh (AuraEnabled)
 * @testClass         DataRefreshHandlerTest
 *
 * @see               LLD-FlowDependencyVisualizer (Project: Flow Dependency Visualizer)
 */
// MODIFIED 2026-06-20 — Project: Flow Dependency Visualizer | LLD-FlowDependencyVisualizer | ASDA
public with sharing class DataRefreshHandler implements Schedulable, Queueable, Database.AllowsCallouts {

    private static final Integer TRANSITIVE_DEPTH = 3;
    private static final String DEFAULT_CRON     = '0 0 2 * * ?';

    // ─── Schedulable ──────────────────────────────────────────────────────────

    /**
     * Schedulable entry point. Enqueues this handler as a Queueable to perform
     * the actual callout-based extraction in an async context.
     *
     * @param  sc  SchedulableContext provided by the platform scheduler.
     *
     * @calledBy    Platform scheduler (cron job registered via scheduleRefresh)
     * @testMethods execute_schedulable_enqueuesQueueable
     */
    public void execute(SchedulableContext sc) {
        System.enqueueJob(new DataRefreshHandler());
    }

    // ─── Queueable ────────────────────────────────────────────────────────────

    /**
     * Queueable entry point. Performs the full sync cycle:
     *   1. Creates an InProgress Metadata_Sync_Log__c record.
     *   2. Clears all existing Flow_Dependency__c records.
     *   3. Fetches the list of active Flows from the Tooling API.
     *   4. For each Flow, fetches and parses its metadata to extract dependencies.
     *   5. Stores all direct dependency edges.
     *   6. Expands transitive dependencies up to TRANSITIVE_DEPTH.
     *   7. Marks the sync log as Completed (or Failed on exception).
     *
     * Respects the 100-callout-per-transaction limit by processing only the first
     * 98 flows per execution (1 callout for list + up to 98 individual metadata fetches).
     *
     * @param  qc  QueueableContext provided by the async execution framework.
     *
     * @calledBy    execute(SchedulableContext), triggerManualRefresh
     * @testMethods execute_queueable_storesDependencies, execute_queueable_apiErrorLogsFailure
     */
    public void execute(QueueableContext qc) {
        Metadata_Sync_Log__c syncLog = new Metadata_Sync_Log__c(
            Sync_Status__c   = 'InProgress',
            Last_Sync_Time__c = System.now(),
            Records_Processed__c = 0
        );
        insert syncLog;

        try {
            MetadataExtractionService extSvc = new MetadataExtractionService();

            // Step 1: Fetch list of active flows
            List<MetadataExtractionService.FlowSummary> flows = extSvc.fetchActiveFlows();

            // Step 2: Clear stale data
            DependencyCalculationService.clearExistingDependencies();

            // Step 3: Process each flow (cap at 98 to stay within callout limit)
            List<MetadataExtractionService.FlowDependency> allDeps =
                new List<MetadataExtractionService.FlowDependency>();

            Integer maxFlows = Math.min(flows.size(), 98);
            for (Integer i = 0; i < maxFlows; i++) {
                MetadataExtractionService.FlowSummary summary = flows[i];
                try {
                    Map<String, Object> flowData = extSvc.fetchFlowMetadata(summary.flowId);
                    List<MetadataExtractionService.FlowDependency> deps =
                        extSvc.parseFlowDependencies(summary, flowData);
                    allDeps.addAll(deps);
                } catch (MetadataExtractionService.MetadataExtractionServiceException innerEx) {
                    // Log the failure for this individual flow but continue processing others
                    System.debug(LoggingLevel.WARN,
                        'Failed to process flow ' + summary.apiName + ': ' + innerEx.getMessage());
                }
            }

            // Step 4: Persist direct dependencies
            DependencyCalculationService.storeDependencies(allDeps);

            // Step 5: Expand transitive dependencies
            DependencyCalculationService.computeTransitiveDependencies(TRANSITIVE_DEPTH);

            // Step 6: Mark sync as Completed
            syncLog.Sync_Status__c        = 'Completed';
            syncLog.Records_Processed__c  = allDeps.size();
            update syncLog;

        } catch (Exception ex) {
            syncLog.Sync_Status__c  = 'Failed';
            syncLog.Error_Message__c = ex.getMessage() + '\n' + ex.getStackTraceString();
            update syncLog;
        }
    }

    // ─── AuraEnabled Trigger Method ───────────────────────────────────────────

    /**
     * Enqueues an immediate refresh job, reachable from LWC via an imperative call.
     * Guards against enqueuing a second job when a sync is already InProgress.
     *
     * @return  String 'queued' when the job was successfully enqueued,
     *          or 'in_progress' when a sync is already running.
     *
     * @calledBy    visualizationComponent.js (manual refresh button)
     * @testMethods triggerManualRefresh_enqueuesJob, triggerManualRefresh_inProgressReturnsStatus
     */
    @AuraEnabled
    public static String triggerManualRefresh() {
        // Prevent double-enqueue if a sync is already running
        List<Metadata_Sync_Log__c> inProgress = [
            SELECT Id
            FROM Metadata_Sync_Log__c
            WHERE Sync_Status__c = 'InProgress'
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (!inProgress.isEmpty()) {
            return 'in_progress';
        }
        System.enqueueJob(new DataRefreshHandler());
        return 'queued';
    }

    // ─── Static Scheduling Helper ─────────────────────────────────────────────

    /**
     * Registers a scheduled job using the provided cron expression, or the default
     * nightly 2 AM schedule when cronExpression is blank.
     *
     * @param  jobName         Unique name for the scheduled job. Required.
     * @param  cronExpression  Optional CRON expression (seconds minutes hours day month weekday).
     *                         Defaults to '0 0 2 * * ?' (nightly 2 AM) when blank.
     * @return The ID of the created CronTrigger record.
     *
     * @calledBy    Admin/Setup Apex scripts or DataRefreshHandlerTest
     * @testMethods scheduleRefresh_registersJob
     */
    public static Id scheduleRefresh(String jobName, String cronExpression) {
        if (String.isBlank(jobName)) {
            throw new DataRefreshHandlerException('jobName must not be blank.');
        }
        String cron = String.isBlank(cronExpression) ? DEFAULT_CRON : cronExpression;
        return System.schedule(jobName, cron, new DataRefreshHandler());
    }

    /** Custom exception for this handler. */
    public class DataRefreshHandlerException extends Exception {}
}
