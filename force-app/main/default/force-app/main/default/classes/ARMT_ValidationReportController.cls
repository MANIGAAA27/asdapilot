/**
 * @file              ARMT_ValidationReportController.cls
 * @description       AuraEnabled Apex controller for the ARMT_ValidationReport LWC.
 *                    Provides methods to retrieve ARMT_ValidationReport__c records for display
 *                    and filtering in the validation report Lightning Web Component.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ARMT_Controllers
 *
 * @dependencies      DataAccessException, ValidationException
 * @calledBy          armtValidationReport (LWC)
 * @testClass         ARMT_ValidationReportTest
 *
 * @see               HLD-ARMT-V1.0 Section 3.4, HLD-CMP-023
 */

/**
 * Apex controller for the ARMT Validation Report LWC.
 *
 * Responsibilities:
 *   - Retrieve ARMT_ValidationReport__c records with optional status filter.
 *   - Return structured data for LWC display.
 *   - Enforce FLS via WITH SECURITY_ENFORCED.
 *
 * Threading: Synchronous, called from LWC @wire or imperative Apex.
 *
 * @testClass ARMT_ValidationReportTest
 */
public with sharing class ARMT_ValidationReportController {

    /**
     * Retrieves all ARMT_ValidationReport__c records, optionally filtered by status.
     *
     * @param  statusFilter  Optional Validation_Status__c value to filter by (BLOCKER, WARNING, INFO).
     *                       Pass null or empty string to retrieve all records.
     * @return List of ARMT_ValidationReport__c records matching the filter.
     * @throws ValidationException when the query fails due to access violations.
     *
     * @calledBy armtValidationReport (LWC)
     * @testMethods test_getValidationReports_noFilter_returnsAll, test_getValidationReports_blockerFilter_returnsBlockers, test_getValidationReports_emptyOrg_returnsEmpty
     */
    @AuraEnabled(cacheable=true)
    public static List<ARMT_ValidationReport__c> getValidationReports(String statusFilter) {
        try {
            if (String.isBlank(statusFilter)) {
                return [
                    SELECT Id, Name, Report_Id__c, Validation_Status__c, Summary__c
                    FROM ARMT_ValidationReport__c
                    WITH SECURITY_ENFORCED
                    ORDER BY Validation_Status__c ASC, Name ASC
                    LIMIT 1000
                ];
            } else {
                return [
                    SELECT Id, Name, Report_Id__c, Validation_Status__c, Summary__c
                    FROM ARMT_ValidationReport__c
                    WHERE Validation_Status__c = :statusFilter
                    WITH SECURITY_ENFORCED
                    ORDER BY Name ASC
                    LIMIT 1000
                ];
            }
        } catch (System.QueryException qe) {
            throw new ValidationException('Failed to retrieve validation reports: ' + qe.getMessage());
        }
    }

    /**
     * Retrieves a single ARMT_ValidationReport__c record by its Report_Id__c.
     *
     * @param  reportId  The unique Report_Id__c value to look up.
     * @return The matching ARMT_ValidationReport__c record, or null if not found.
     * @throws ValidationException when the query fails.
     *
     * @calledBy armtValidationReport (LWC)
     * @testMethods test_getReportById_validId_returnsRecord, test_getReportById_invalidId_returnsNull
     */
    @AuraEnabled(cacheable=true)
    public static ARMT_ValidationReport__c getReportById(String reportId) {
        if (String.isBlank(reportId)) {
            return null;
        }
        try {
            List<ARMT_ValidationReport__c> results = [
                SELECT Id, Name, Report_Id__c, Validation_Status__c, Summary__c
                FROM ARMT_ValidationReport__c
                WHERE Report_Id__c = :reportId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return results.isEmpty() ? null : results[0];
        } catch (System.QueryException qe) {
            throw new ValidationException('Failed to retrieve validation report by ID: ' + qe.getMessage());
        }
    }
}
