/**
 * @file              CaseSummaryController.cls
 * @description       Apex controller providing @AuraEnabled methods to supply
 *                    CaseTransferSummary__c data to the caseTransferSummaryPanel
 *                    and child LWC components. All queries delegate to
 *                    CaseSummarySelector for FLS-secure data access.
 *                    Implements HLD-CMP-008.
 *
 *                    Read methods are cacheable=true for LDS caching.
 *                    The regenerateSummary method is non-cacheable (write path).
 *
 * @author            ASDA Dev Agent
 * @created           2026-06-05
 * @lastModified      2026-06-05
 * @group             CaseTransfer
 *
 * @dependencies      CaseSummarySelector, CaseTransferService
 * @calledBy          caseTransferSummaryPanel (LWC)
 * @testClass         CaseSummaryControllerTest
 *
 * @see               HLD-CMP-008, HLD Section 6
 */
public with sharing class CaseSummaryController {

    private static final Integer DEFAULT_SUMMARY_LIMIT = 10;

    /**
     * Returns the most recent CaseTransferSummary__c for the given Case.
     * Used by the LWC to display the latest summary on page load.
     *
     * @param caseId  Id of the parent Case record.
     * @return        Most recent CaseTransferSummary__c, or null if none exist.
     * @throws        AuraHandledException on unexpected errors.
     *
     * @calledBy    caseTransferSummaryPanel.js
     * @testMethods test_getLatestSummary_returnsMostRecent,
     *              test_getLatestSummary_noRecords_returnsNull
     */
    @AuraEnabled(cacheable=true)
    public static CaseTransferSummary__c getLatestSummary(Id caseId) {
        try {
            CaseSummarySelector selector = new CaseSummarySelector();
            List<CaseTransferSummary__c> results = [
                SELECT Id, Name, Case__c, GeneratedFor__c, GenerationStatus__c,
                       GenerationTimestamp__c, SummaryText__c, LLMModelName__c,
                       LLMResponseCode__c, ErrorMessage__c
                FROM   CaseTransferSummary__c
                WHERE  Case__c = :caseId
                WITH   SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT  1
            ];
            return results.isEmpty() ? null : results[0];
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to retrieve latest summary: ' + ex.getMessage());
        }
    }

    /**
     * Returns a list of CaseTransferSummary__c records for the given Case,
     * ordered by creation date descending. Used by summaryHistoryList LWC.
     *
     * @param caseId       Id of the parent Case record.
     * @param recordLimit  Maximum number of records to return. Defaults to 10.
     * @return             List of CaseTransferSummary__c records (may be empty).
     * @throws             AuraHandledException on unexpected errors.
     *
     * @calledBy    summaryHistoryList.js
     * @testMethods test_getSummaryHistory_returnsOrderedList,
     *              test_getSummaryHistory_limitEnforced
     */
    @AuraEnabled(cacheable=true)
    public static List<CaseTransferSummary__c> getSummaryHistory(Id caseId, Integer recordLimit) {
        try {
            Integer lim = (recordLimit == null || recordLimit <= 0) ? DEFAULT_SUMMARY_LIMIT : recordLimit;
            return [
                SELECT Id, Name, Case__c, GeneratedFor__c, GenerationStatus__c,
                       GenerationTimestamp__c, SummaryText__c
                FROM   CaseTransferSummary__c
                WHERE  Case__c = :caseId
                WITH   SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT  :lim
            ];
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to retrieve summary history: ' + ex.getMessage());
        }
    }

    /**
     * Enqueues a new summary generation job for the given Case.
     * Called when an admin or agent clicks "Regenerate Summary" in the UI.
     *
     * @param caseId  Id of the Case to regenerate the summary for.
     * @throws        AuraHandledException on unexpected errors.
     *
     * @calledBy    caseTransferSummaryPanel.js
     * @testMethods test_regenerateSummary_enqueuesJob,
     *              test_regenerateSummary_nullCaseId_throwsException
     */
    @AuraEnabled
    public static void regenerateSummary(Id caseId) {
        try {
            if (caseId == null) {
                throw new AuraHandledException('Case ID is required to regenerate summary.');
            }
            CaseTransferService.beginSummaryGeneration(new Set<Id>{ caseId });
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to regenerate summary: ' + ex.getMessage());
        }
    }

    /**
     * Returns the Recent_Transfer_Minutes__c setting from CaseSummarySettings__mdt.
     * Used by the LWC to determine whether to auto-expand the panel.
     *
     * @return  Integer minutes threshold, defaulting to 30 when not configured.
     * @throws  AuraHandledException on unexpected errors.
     *
     * @calledBy    caseTransferSummaryPanel.js
     * @testMethods test_getRecentTransferMinutes_returnsConfiguredValue
     */
    @AuraEnabled(cacheable=true)
    public static Integer getRecentTransferMinutes() {
        try {
            List<CaseSummarySettings__mdt> settings = [
                SELECT Recent_Transfer_Minutes__c
                FROM   CaseSummarySettings__mdt
                LIMIT  1
            ];
            if (!settings.isEmpty() && settings[0].Recent_Transfer_Minutes__c != null
                    && settings[0].Recent_Transfer_Minutes__c > 0) {
                return settings[0].Recent_Transfer_Minutes__c.intValue();
            }
            return 30;
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to retrieve settings: ' + ex.getMessage());
        }
    }
}
