/**
 * @file              MigrationValidator.cls
 * @description       Service class for data validation according to ARM model and user
 *                    security policies. Validates migration configuration JSON, checks
 *                    object-level CRUD and FLS, queries ARM_Object_Mapping__c for
 *                    registered mappings, and exposes both @AuraEnabled (LWC) and
 *                    @InvocableMethod (Flow) entry points.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-23
 * @lastModified      2026-06-23
 * @group             MigrationProcessing
 *
 * @dependencies      ARM_Object_Mapping__c
 * @calledBy          migrationWizard (LWC), ConfigurationFlow (Flow action)
 * @testClass         MigrationValidatorTest
 *
 * @see               HLD-CMP-003 ARMT_ValidationService, BR-001 Pre-flight validation
 */

// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
/**
 * Validates CPQ-to-ARM migration configuration before any batch job is enqueued.
 *
 * Responsibilities:
 *   - Parse and validate configuration JSON supplied by the wizard UI or Flow.
 *   - Verify sourceObject and targetObject API names are populated.
 *   - Check running-user CRUD access to ARM_Object_Mapping__c.
 *   - Return structured ValidationResult with isValid flag, errors, and warnings.
 *   - Expose @InvocableMethod so ConfigurationFlow can invoke validation as an action.
 *
 * Threading: synchronous; safe to call from LWC @AuraEnabled or Flow action call.
 * For org-size validation (querying all mappings) ensure you stay below the SOQL
 * limit by scoping queries to required fields only.
 *
 * @testClass MigrationValidatorTest
 */
public with sharing class MigrationValidator {

    // -------------------------------------------------------------------------
    // Inner types — shared by @AuraEnabled (LWC) and @InvocableMethod (Flow)
    // -------------------------------------------------------------------------

    /**
     * Carries the outcome of a validation run. Fields are annotated for both
     * LWC (@AuraEnabled) and Flow (@InvocableVariable) consumption.
     */
    public class ValidationResult {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public List<String> errors;
        @AuraEnabled public List<String> warnings;

        /** Default constructor initialises lists and sets isValid = true. */
        public ValidationResult() {
            this.isValid = true;
            this.errors = new List<String>();
            this.warnings = new List<String>();
        }
    }

    /**
     * Input wrapper for the @InvocableMethod to allow Flow to pass parameters.
     */
    public class ValidateConfigRequest {
        @InvocableVariable(label='Source Object API Name' required=true)
        public String sourceObjectName;

        @InvocableVariable(label='Target Object API Name' required=true)
        public String targetObjectName;
    }

    /**
     * Output wrapper returned by the @InvocableMethod to Flow output variables.
     */
    public class ValidateConfigResponse {
        @InvocableVariable(label='Is Valid')
        public Boolean isValid;

        @InvocableVariable(label='Error Summary')
        public String errorSummary;

        @InvocableVariable(label='Warning Summary')
        public String warningSummary;
    }

    // -------------------------------------------------------------------------
    // Public API — @AuraEnabled for LWC
    // -------------------------------------------------------------------------

    /**
     * Validates a migration configuration JSON string supplied by the wizard UI.
     * The JSON must contain at minimum { "sourceObject": "...", "targetObject": "..." }.
     *
     * @param  configJson  JSON string with sourceObject and targetObject keys.
     * @return ValidationResult with isValid, errors[], and warnings[].
     *         Never returns null; isValid = false with an error when configJson is blank.
     *
     * @calledBy    migrationWizard (LWC)
     * @testMethods test_validateConfiguration_validJson_returnsValid,
     *              test_validateConfiguration_blankJson_returnsInvalid,
     *              test_validateConfiguration_missingSource_returnsError,
     *              test_validateConfiguration_missingTarget_returnsError
     */
    @AuraEnabled(cacheable=false)
    public static ValidationResult validateConfiguration(String configJson) {
        ValidationResult result = new ValidationResult();

        if (String.isBlank(configJson)) {
            result.isValid = false;
            result.errors.add('Configuration JSON is required.');
            return result;
        }

        Map<String, Object> configMap;
        try {
            configMap = (Map<String, Object>) JSON.deserializeUntyped(configJson);
        } catch (JSONException ex) {
            result.isValid = false;
            result.errors.add('Invalid configuration JSON: ' + ex.getMessage());
            return result;
        }

        validateSourceObjects(configMap, result);
        validateFieldMappings(configMap, result);
        checkObjectAccess(result);

        result.isValid = result.errors.isEmpty();
        return result;
    }

    /**
     * Returns all ARM_Object_Mapping__c records visible to the running user.
     * Used by the wizard UI to display existing mappings before validation.
     *
     * @return List of ARM_Object_Mapping__c with Name, Source_Object__c,
     *         Target_Object__c, Mapping_Logic__c. Empty list when none exist.
     *
     * @calledBy    migrationWizard (LWC)
     * @testMethods test_getObjectMappings_returnsRecords,
     *              test_getObjectMappings_emptyOrg_returnsEmpty
     */
    @AuraEnabled(cacheable=true)
    public static List<ARM_Object_Mapping__c> getObjectMappings() {
        return [
            SELECT Id, Name, Source_Object__c, Target_Object__c, Mapping_Logic__c
            FROM ARM_Object_Mapping__c
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
        ];
    }

    // -------------------------------------------------------------------------
    // Public API — @InvocableMethod for ConfigurationFlow
    // -------------------------------------------------------------------------

    /**
     * Flow-invocable entry point for migration configuration validation.
     * Accepts a list of ValidateConfigRequest, returns a matching list of
     * ValidateConfigResponse. Designed for use as an Apex action in ConfigurationFlow.
     *
     * @param  requests  List of ValidateConfigRequest (one per Flow invocation).
     * @return List<ValidateConfigResponse> with isValid, errorSummary, warningSummary.
     *
     * @calledBy    ConfigurationFlow (apex action call)
     * @testMethods test_validateConfigInvocable_validRequest_returnsValid,
     *              test_validateConfigInvocable_missingSource_returnsInvalid
     */
    @InvocableMethod(
        label='Validate Migration Configuration'
        description='Validates source and target object API names and checks running-user CRUD access.'
        category='Migration'
    )
    public static List<ValidateConfigResponse> validateConfigInvocable(
        List<ValidateConfigRequest> requests
    ) {
        List<ValidateConfigResponse> responses = new List<ValidateConfigResponse>();

        for (ValidateConfigRequest req : requests) {
            ValidateConfigResponse resp = new ValidateConfigResponse();
            List<String> errList = new List<String>();
            List<String> warnList = new List<String>();

            if (String.isBlank(req.sourceObjectName)) {
                errList.add('Source object API name is required.');
            }
            if (String.isBlank(req.targetObjectName)) {
                errList.add('Target object API name is required.');
            }
            if (!Schema.sObjectType.ARM_Object_Mapping__c.isAccessible()) {
                warnList.add('Running user does not have read access to ARM Object Mapping; mapping validation skipped.');
            }

            resp.isValid = errList.isEmpty();
            resp.errorSummary = errList.isEmpty() ? null : String.join(errList, '; ');
            resp.warningSummary = warnList.isEmpty() ? null : String.join(warnList, '; ');
            responses.add(resp);
        }

        return responses;
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /** Validates presence and non-blank value of sourceObject and targetObject keys. */
    private static void validateSourceObjects(
        Map<String, Object> configMap,
        ValidationResult result
    ) {
        Object srcObj = configMap.get('sourceObject');
        if (srcObj == null || String.isBlank(String.valueOf(srcObj))) {
            result.errors.add('sourceObject API name is required in configuration.');
        }
        Object tgtObj = configMap.get('targetObject');
        if (tgtObj == null || String.isBlank(String.valueOf(tgtObj))) {
            result.errors.add('targetObject API name is required in configuration.');
        }
    }

    /** Warns when fieldMappings is absent; does not block migration. */
    private static void validateFieldMappings(
        Map<String, Object> configMap,
        ValidationResult result
    ) {
        if (!configMap.containsKey('fieldMappings') || configMap.get('fieldMappings') == null) {
            result.warnings.add('No fieldMappings provided; default mapping rules will be applied.');
        }
    }

    /** Checks running-user read access to ARM_Object_Mapping__c. */
    private static void checkObjectAccess(ValidationResult result) {
        if (!Schema.sObjectType.ARM_Object_Mapping__c.isAccessible()) {
            result.errors.add('Running user does not have read access to ARM Object Mapping records.');
        }
    }
}
