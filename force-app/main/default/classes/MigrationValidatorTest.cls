/**
 * @file        MigrationValidatorTest.cls
 * @description Tests MigrationValidator — covers blank JSON guard, missing source/target
 *              keys, valid configuration path, getObjectMappings, and the
 *              @InvocableMethod validateConfigInvocable path.
 * @testFor     MigrationValidator
 * @coverage    Target >= 90%.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-23
 */
// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
@isTest
private class MigrationValidatorTest {

    // -------------------------------------------------------------------------
    // Test setup
    // -------------------------------------------------------------------------

    @TestSetup
    static void setupData() {
        ARM_Object_Mapping__c mapping = new ARM_Object_Mapping__c(
            Name = 'Quote Mapping',
            Source_Object__c = 'SBQQ__Quote__c',
            Target_Object__c = 'arm__Quote__c',
            Mapping_Logic__c = '[]'
        );
        insert mapping;
    }

    // -------------------------------------------------------------------------
    // validateConfiguration — blank JSON
    // -------------------------------------------------------------------------

    @isTest
    static void test_validateConfiguration_blankJson_returnsInvalid() {
        Test.startTest();
        MigrationValidator.ValidationResult result =
            MigrationValidator.validateConfiguration('');
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Blank JSON must return isValid = false');
        System.assert(!result.errors.isEmpty(), 'Errors list must be non-empty for blank JSON');
    }

    // -------------------------------------------------------------------------
    // validateConfiguration — missing sourceObject key
    // -------------------------------------------------------------------------

    @isTest
    static void test_validateConfiguration_missingSource_returnsError() {
        String config = JSON.serialize(new Map<String, Object>{
            'targetObject' => 'arm__Quote__c'
        });

        Test.startTest();
        MigrationValidator.ValidationResult result =
            MigrationValidator.validateConfiguration(config);
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Missing sourceObject must make config invalid');
        Boolean hasSourceError = false;
        for (String err : result.errors) {
            if (err.containsIgnoreCase('sourceObject')) {
                hasSourceError = true;
            }
        }
        System.assert(hasSourceError, 'Error message must mention sourceObject');
    }

    // -------------------------------------------------------------------------
    // validateConfiguration — missing targetObject key
    // -------------------------------------------------------------------------

    @isTest
    static void test_validateConfiguration_missingTarget_returnsError() {
        String config = JSON.serialize(new Map<String, Object>{
            'sourceObject' => 'SBQQ__Quote__c'
        });

        Test.startTest();
        MigrationValidator.ValidationResult result =
            MigrationValidator.validateConfiguration(config);
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Missing targetObject must make config invalid');
    }

    // -------------------------------------------------------------------------
    // validateConfiguration — valid JSON with both keys
    // -------------------------------------------------------------------------

    @isTest
    static void test_validateConfiguration_validJson_returnsValid() {
        String config = JSON.serialize(new Map<String, Object>{
            'sourceObject'  => 'SBQQ__Quote__c',
            'targetObject'  => 'arm__Quote__c',
            'fieldMappings' => new List<Object>()
        });

        Test.startTest();
        MigrationValidator.ValidationResult result =
            MigrationValidator.validateConfiguration(config);
        Test.stopTest();

        System.assertEquals(0, result.errors.size(), 'Valid config must produce no errors');
        System.assertEquals(true, result.isValid, 'Valid config must return isValid = true');
    }

    // -------------------------------------------------------------------------
    // validateConfiguration — malformed JSON
    // -------------------------------------------------------------------------

    @isTest
    static void test_validateConfiguration_malformedJson_returnsInvalid() {
        Test.startTest();
        MigrationValidator.ValidationResult result =
            MigrationValidator.validateConfiguration('{ not valid json }');
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Malformed JSON must return isValid = false');
        System.assert(!result.errors.isEmpty(), 'Errors must be present for malformed JSON');
    }

    // -------------------------------------------------------------------------
    // getObjectMappings — returns seeded record
    // -------------------------------------------------------------------------

    @isTest
    static void test_getObjectMappings_returnsRecords() {
        Test.startTest();
        List<ARM_Object_Mapping__c> mappings = MigrationValidator.getObjectMappings();
        Test.stopTest();

        System.assertNotEquals(null, mappings, 'Mappings list must not be null');
        System.assertEquals(1, mappings.size(), 'Expected the seeded mapping record');
        System.assertEquals('SBQQ__Quote__c', mappings[0].Source_Object__c, 'Source object must match seeded value');
    }

    // -------------------------------------------------------------------------
    // validateConfigInvocable — valid request
    // -------------------------------------------------------------------------

    @isTest
    static void test_validateConfigInvocable_validRequest_returnsValid() {
        MigrationValidator.ValidateConfigRequest req = new MigrationValidator.ValidateConfigRequest();
        req.sourceObjectName = 'SBQQ__Quote__c';
        req.targetObjectName = 'arm__Quote__c';

        Test.startTest();
        List<MigrationValidator.ValidateConfigResponse> responses =
            MigrationValidator.validateConfigInvocable(
                new List<MigrationValidator.ValidateConfigRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Expected one response');
        System.assertEquals(true, responses[0].isValid, 'Valid request must return isValid = true');
        System.assertEquals(null, responses[0].errorSummary, 'No errors expected for valid request');
    }

    // -------------------------------------------------------------------------
    // validateConfigInvocable — missing source returns error
    // -------------------------------------------------------------------------

    @isTest
    static void test_validateConfigInvocable_missingSource_returnsInvalid() {
        MigrationValidator.ValidateConfigRequest req = new MigrationValidator.ValidateConfigRequest();
        req.sourceObjectName = '';
        req.targetObjectName = 'arm__Quote__c';

        Test.startTest();
        List<MigrationValidator.ValidateConfigResponse> responses =
            MigrationValidator.validateConfigInvocable(
                new List<MigrationValidator.ValidateConfigRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(false, responses[0].isValid, 'Blank source must make response invalid');
        System.assertNotEquals(null, responses[0].errorSummary, 'Error summary must be populated');
    }
}
