/**
  @file              CaseSummarySelector.cls
  @description       Data access layer providing reusable, FLS-secure SOQL queries
                     for CaseTransferSummary__c records. Encapsulates all summary
                     retrieval logic used by CaseSummaryController and any future
                     callers. All queries use WITH SECURITY_ENFORCED to respect
                     field-level security (SEC-06).
  @author            ASDA Dev Agent
  @created           2026-06-05
  @lastModified      2026-06-05
  @group             CaseTransfer
 
  @dependencies      (none)
  @calledBy          CaseSummaryController
  @testClass         CaseSummarySelectorTest
 
  @see               HLD-CMP-007, HLD Section 5 LDV Strategy
 */
// MODIFIED 2026-06-05 — Project: Case Transfer | LLD-CaseTransfer-1 (BR1-BR2) | ASDA
public with sharing class CaseSummarySelector {

    private static final Integer DEFAULT_SUMMARY_LIMIT = 10;

    public SObject getLatestSummaryForCase(Id caseId) {
        List<SObject> results = [
            SELECT Id, Name
            FROM   CaseTransferSummary__c
            WHERE  Case__c = :caseId
            WITH   SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT  1
        ];
        return results.isEmpty() ? null : results[0];
    }

    public List<SObject> getSummariesForCase(Id caseId, Integer recordLimit) {
        Integer lim = (recordLimit == null || recordLimit <= 0) ? DEFAULT_SUMMARY_LIMIT : recordLimit;
        return [
            SELECT Id, Name, Case__c
            FROM   CaseTransferSummary__c
            WHERE  Case__c = :caseId
            WITH   SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT  :lim
        ];
    }

    public List<SObject> getSummariesForCases(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return new List<SObject>();
        }
        return [
            SELECT Id, Name, Case__c
            FROM   CaseTransferSummary__c
            WHERE  Case__c IN :caseIds
            WITH   SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];
    }
}
