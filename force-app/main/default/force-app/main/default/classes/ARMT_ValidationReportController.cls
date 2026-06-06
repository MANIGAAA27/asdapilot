/**
 * @file              ARMT_ValidationReportController.cls
 * @description       AuraEnabled Apex controller for the armtValidationReport LWC.
 *                    Provides @AuraEnabled methods to retrieve ARMT_ValidationReport__c
 *                    records for display and filtering in the UI.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ARMT_Validation
 *
 * @dependencies      ARMT_PreMigrationValidator
 * @calledBy          armtValidationReport (LWC)
 * @testClass         ARMT_ValidationReportControllerTest
 *
 * @see               HLD-ARMT-V1.0 Section 3.4 HLD-CMP-023
 */

/**
 * Controller providing AuraEnabled data access for the armtValidationReport LWC.
 *
 * Responsibilities:
 *   - Retrieve ARMT_ValidationReport__c records with optional report ID filter.
 *   - Enforce FLS via WITH SECURITY_ENFORCED.
 *   - Return lightweight data suitable for LWC wire adapter consumption.
 *
 * @testClass ARMT_ValidationReportControllerTest
 */
public with sharing class ARMT_ValidationReportController {

    /**
     * Retrieves ARMT_ValidationReport__c records, optionally filtered by report ID.
     * Cacheable for read-only wire adapter use in the LWC.
     *
     * @param  reportId  Optional report ID to filter by. Pass null or empty to return all.
     * @return           List of ARMT_ValidationReport__c records ordered by CreatedDate DESC.
     *
     * @calledBy    armtValidationReport LWC (wire adapter)
     * @testMethods test_getValidationReports_noFilter_returnsAll,
     *              test_getValidationReports_withFilter_returnsFiltered,
     *              test_getValidationReports_unknownId_returnsEmpty
     */
    @AuraEnabled(cacheable=true)
    public static List<ARMT_ValidationReport__c> getValidationReports(String reportId) {
        if (String.isNotBlank(reportId)) {
            return [
                SELECT Id, Name, Report_Id__c, Summary__c, Validation_Status__c, CreatedDate
                FROM   ARMT_ValidationReport__c
                WHERE  Report_Id__c = :reportId
                WITH   SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT  1000
            ];
        }
        return [
            SELECT Id, Name, Report_Id__c, Summary__c, Validation_Status__c, CreatedDate
            FROM   ARMT_ValidationReport__c
            WITH   SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT  1000
        ];
    }
}
