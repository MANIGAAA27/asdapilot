/**
 * @file              CaseSummaryController.cls
 * @description       Lightning controller for the caseSummaryPanel LWC.
 *                    Provides a single @AuraEnabled(cacheable=true) method that
 *                    returns the most recent successful Case_Transfer_Summary__c
 *                    record for the given Case, or null if none exists.
 *                    The LWC uses the null check to conditionally render the
 *                    summary component (FR17 / FR19).
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-25
 * @lastModified      2026-05-25
 * @group             CaseSummaryTransfer
 *
 * @dependencies      (none in this changeset)
 * @calledBy          caseSummaryPanel LWC
 * @testClass         CaseSummaryControllerTest
 *
 * @see               LLD-Case Summary Transfer 1.0 §2.6 UI Layer
 */
public with sharing class CaseSummaryController {

    /**
     * Returns the most recent successful Case_Transfer_Summary__c for the
     * given Case Id, ordered by Transfer_Timestamp__c descending.
     *
     * Cacheable so repeated LWC wire calls do not issue redundant SOQL.
     *
     * @param  caseId  Id of the Case record displayed on the current record page.
     * @return The most recent successful Case_Transfer_Summary__c, or null if
     *         no successful summary exists for this Case. Null is the signal
     *         the LWC uses to hide the component (FR19).
     *
     * @calledBy    caseSummaryPanel LWC (via @wire)
     * @testMethods test_getLatestSummary_existingSummary_returnsSummary,
     *              test_getLatestSummary_noSummaryExists_returnsNull
     */
    @AuraEnabled(cacheable=true)
    public static Case_Transfer_Summary__c getLatestSummary(Id caseId) {
        List<Case_Transfer_Summary__c> summaries = [
            SELECT Id,
                   Summary_Text__c,
                   Transfer_Timestamp__c,
                   Model_Name__c,
                   Model_Version__c,
                   Generation_Status__c
            FROM   Case_Transfer_Summary__c
            WHERE  Case__c = :caseId
            AND    Generation_Status__c = 'Success'
            WITH SECURITY_ENFORCED
            ORDER BY Transfer_Timestamp__c DESC
            LIMIT  1
        ];
        return summaries.isEmpty() ? null : summaries[0];
    }
}