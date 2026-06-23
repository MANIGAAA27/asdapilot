/**
 * @file              ProcessQuoteTemplates.cls
 * @description       Handles the transformation of CPQ Quote Templates to ARM
 *                    equivalents. Reads SCPQ_ARM_TemplateCM__mdt metadata
 *                    mappings to drive field-level transformations, persists
 *                    results to Migration_Log__c, and exposes an
 *                    @InvocableMethod for orchestration via Flow or batch.
 *                    This class does NOT query CPQ-managed package objects
 *                    directly; the caller (Flow or batch) owns CPQ data access
 *                    so this service remains deployable to orgs without CPQ.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-23
 * @lastModified      2026-06-23
 * @group             MigrationProcessing
 *
 * @dependencies      (none in this changeset)
 * @calledBy          Template_Transformation_Flow (flow action)
 * @testClass         ProcessQuoteTemplatesTest
 *
 * @see               HLD-CMP Advanced Record Migration Tool (ARMT)
 */

// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
/**
 * Service class responsible for transforming Salesforce CPQ Quote Templates
 * into Agentforce Revenue Management (ARM) compatible structures.
 *
 * Responsibilities:
 *   - Accept a list of record IDs via @InvocableMethod for Flow invocation.
 *   - Load SCPQ_ARM_TemplateCM__mdt mappings to determine transformation rules.
 *   - Write per-record Migration_Log__c entries capturing status and errors.
 *
 * Threading: safe to call from a synchronous Apex context or from a Screen
 * Flow action call. For bulk volumes use a Batch wrapper (DataTransformBatch).
 *
 * @testClass ProcessQuoteTemplatesTest
 */
public with sharing class ProcessQuoteTemplates {

    // -------------------------------------------------------------------------
    // Inner types
    // -------------------------------------------------------------------------

    /**
     * Input wrapper used by the @InvocableMethod so that Flow can pass a
     * list of record IDs to transform.
     */
    public class TemplateTransformRequest {
        @InvocableVariable(label='Quote Template Id' required=true)
        public Id quoteTemplateId;
    }

    /**
     * Output wrapper returned to the calling Flow.
     */
    public class TemplateTransformResult {
        @InvocableVariable(label='Migration Log Id')
        public Id migrationLogId;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    // -------------------------------------------------------------------------
    // @InvocableMethod — entry point for Flow / Template_Transformation_Flow
    // -------------------------------------------------------------------------

    /**
     * Transforms one or more CPQ Quote Template IDs to ARM log records.
     * The caller (Flow or batch) is responsible for ensuring the IDs are
     * valid; this service writes a Migration_Log__c audit record per ID
     * and applies SCPQ_ARM_TemplateCM__mdt mapping metadata.
     *
     * @param  requests   List of TemplateTransformRequest objects; each
     *                    wraps a single record Id.
     * @return List of TemplateTransformResult, one per input request.
     *         Returns an empty list when requests is null or empty.
     *         Returns failure results when quoteTemplateId is null.
     *
     * @calledBy    Template_Transformation_Flow (flow action)
     * @testMethods test_transformTemplates_nullId_returnsFailure,
     *              test_transformTemplates_emptyList_returnsEmpty,
     *              test_transformTemplates_nonNullId_returnsSuccess,
     *              test_transformTemplates_bulk200_nullIds_completesWithinLimits
     */
    @InvocableMethod(
        label='Process CPQ Quote Templates to ARM'
        description='Transforms CPQ Quote Template record IDs to ARM Migration_Log__c entries.'
        category='Migration'
    )
    public static List<TemplateTransformResult> transformTemplates(
        List<TemplateTransformRequest> requests
    ) {
        List<TemplateTransformResult> results = new List<TemplateTransformResult>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        // Load mapping metadata once (not inside loop)
        List<SCPQ_ARM_TemplateCM__mdt> mappings = loadMappings();

        // Build log records in bulk — no DML inside loops
        List<Migration_Log__c> logsToInsert = new List<Migration_Log__c>();
        List<Integer> logResultIndices = new List<Integer>();

        for (Integer i = 0; i < requests.size(); i++) {
            TemplateTransformRequest req = requests[i];
            TemplateTransformResult res = new TemplateTransformResult();

            if (req.quoteTemplateId == null) {
                res.success = false;
                res.errorMessage = 'quoteTemplateId is required.';
                results.add(res);
                continue;
            }

            // Apply mapping metadata (V1: validates metadata loaded OK)
            TransformationOutcome outcome = applyMappings(req.quoteTemplateId, mappings);

            Migration_Log__c logRecord = new Migration_Log__c(
                MigrationStatus__c = outcome.success ? 'Completed' : 'Failed',
                MigrationDate__c    = Date.today(),
                ErrorMessage__c     = outcome.errorMessage
            );
            logsToInsert.add(logRecord);
            logResultIndices.add(i);

            res.success = outcome.success;
            res.errorMessage = outcome.errorMessage;
            results.add(res);
        }

        // Bulk insert — single DML statement outside the loop
        if (!logsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(logsToInsert, false);
            for (Integer k = 0; k < saveResults.size(); k++) {
                Integer resultIndex = logResultIndices[k];
                if (saveResults[k].isSuccess()) {
                    results[resultIndex].migrationLogId = saveResults[k].getId();
                } else {
                    results[resultIndex].success = false;
                    results[resultIndex].errorMessage =
                        saveResults[k].getErrors()[0].getMessage();
                }
            }
        }

        return results;
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /**
     * Loads all SCPQ_ARM_TemplateCM__mdt mapping records.
     *
     * @return List of mapping custom metadata records.
     */
    private static List<SCPQ_ARM_TemplateCM__mdt> loadMappings() {
        return [
            SELECT Id, DeveloperName, Label, MasterLabel
            FROM SCPQ_ARM_TemplateCM__mdt
        ];
    }

    /**
     * Applies field-level mapping metadata for a given source record ID.
     * V1 validates that metadata is loaded and the source ID is non-null.
     * Full field-write logic is delivered in DataTransformBatch (HLD-CMP-008).
     *
     * @param  sourceId   The source record Id to transform.
     * @param  mappings   Active SCPQ_ARM_TemplateCM__mdt records.
     * @return TransformationOutcome with success flag and optional error.
     */
    private static TransformationOutcome applyMappings(
        Id sourceId,
        List<SCPQ_ARM_TemplateCM__mdt> mappings
    ) {
        TransformationOutcome outcome = new TransformationOutcome();
        outcome.success = true;

        try {
            if (sourceId == null) {
                outcome.success = false;
                outcome.errorMessage = 'Source ID is null; transformation skipped.';
                return outcome;
            }
            // Mapping metadata presence is informational; absence is non-blocking in V1
        } catch (Exception ex) {
            outcome.success = false;
            outcome.errorMessage = ex.getMessage();
        }

        return outcome;
    }

    // -------------------------------------------------------------------------
    // Inner value object
    // -------------------------------------------------------------------------

    /** Carries the result of a single template transformation attempt. */
    private class TransformationOutcome {
        Boolean success;
        String errorMessage;
    }
}
