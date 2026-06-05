/**
 * @file        CaseTransferService.cls
 * @project     Case Transfer
 * @lld         LLD-CaseTransfer-2 (BR3-BR4)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-05
 */
/**
 * @file              CaseTransferService.cls
 * @description       Orchestrates case transfer summary generation. Creates
 *                    CaseTransferSummary__c records and enqueues queueable
 *                    jobs for async LLM processing.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-23
 * @lastModified      2026-05-23
 * @group             CaseManagement
 *
 * @dependencies      CaseSummaryGeneratorQueueable, CaseTransferSummary__c
 * @calledBy          CaseTriggerHandler
 * @testClass         CaseTransferServiceTest
 *
 * @see               LLD Case Transfer Summary Generation
 */

/**
 * Service layer for case transfer processing.
 *
 * Responsibilities:
 *   - Create CaseTransferSummary__c stub records with 'Pending' status.
 *   - Resolve old/new owner details (User vs Queue).
 *   - Enqueue CaseSummaryGeneratorQueueable for async LLM generation.
 *
 * Threading: called from synchronous trigger context. Delegates heavy lifting
 * to queueable Apex to avoid governor limits.
 *
 * @testClass CaseTransferServiceTest
 */
public with sharing class CaseTransferService {
    
    /**
     * Creates transfer summary records and enqueues async generation for each
     * transferred case.
     *
     * @param caseIds Set of Case Ids that experienced ownership change.
     */
    public static void handleTransfers(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }
        
        List<Case> cases = [
            SELECT Id, OwnerId, CaseNumber, Subject, Description, Status, Priority,
                   ContactId, Contact.Name, Contact.Email,
                   AccountId, Account.Name,
                   (SELECT Id, CommentBody, CreatedDate, CreatedBy.Name 
                    FROM CaseComments 
                    ORDER BY CreatedDate DESC LIMIT 50),
                   (SELECT Id, Subject, Description, CreatedDate, CreatedBy.Name
                    FROM Tasks
                    WHERE IsClosed = false
                    ORDER BY CreatedDate DESC LIMIT 20),
                   (SELECT Id, Subject, TextBody, HtmlBody, CreatedDate, FromAddress
                    FROM EmailMessages
                    ORDER BY CreatedDate DESC LIMIT 20)
            FROM Case
            WHERE Id IN :caseIds
        ];
        
        if (cases.isEmpty()) {
            return;
        }
        
        Map<Id, Id> oldOwnerMap = getPreviousOwners(caseIds);
        Map<Id, String> userNameMap = getUserNames(cases, oldOwnerMap);
        Map<Id, String> queueNameMap = getQueueNames(cases, oldOwnerMap);
        
        List<CaseTransferSummary__c> summaries = new List<CaseTransferSummary__c>();
        
        for (Case c : cases) {
            Id oldOwnerId = oldOwnerMap.get(c.Id);
            
            CaseTransferSummary__c summary = new CaseTransferSummary__c(
                Case__c = c.Id,
                GenerationStatus__c = 'Pending',
                TransferDate__c = System.now()
            );
            
            // Determine old owner type
            if (oldOwnerId != null) {
                String oldOwnerIdPrefix = String.valueOf(oldOwnerId).substring(0, 3);
                if (oldOwnerIdPrefix == '005') {
                    summary.TransferredFrom__c = oldOwnerId;
                } else if (oldOwnerIdPrefix == '00G') {
                    summary.TransferredFromQueue__c = queueNameMap.get(oldOwnerId);
                }
            }
            
            // Determine new owner type
            String newOwnerIdPrefix = String.valueOf(c.OwnerId).substring(0, 3);
            if (newOwnerIdPrefix == '005') {
                summary.TransferredTo__c = c.OwnerId;
            } else if (newOwnerIdPrefix == '00G') {
                summary.TransferredToQueue__c = queueNameMap.get(c.OwnerId);
            }
            
            summaries.add(summary);
        }
        
        if (!summaries.isEmpty()) {
            insert summaries;
            
            // Enqueue async generation
            if (!System.isBatch() && !System.isFuture() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(new CaseSummaryGeneratorQueueable(summaries[0].Id, cases[0]));
            }
        }
    }
    
    /**
     * Retrieves previous owner IDs from Case history tracking.
     *
     * @param caseIds Set of Case IDs to query.
     * @return Map of Case Id → previous OwnerId. Empty map if no history found.
     */
    private static Map<Id, Id> getPreviousOwners(Set<Id> caseIds) {
        Map<Id, Id> result = new Map<Id, Id>();
        
        List<CaseHistory> histories = [
            SELECT CaseId, OldValue
            FROM CaseHistory
            WHERE CaseId IN :caseIds
              AND Field = 'Owner'
            ORDER BY CreatedDate DESC
        ];
        
        for (CaseHistory h : histories) {
            if (!result.containsKey(h.CaseId) && h.OldValue != null) {
                result.put(h.CaseId, (Id)h.OldValue);
            }
        }
        
        return result;
    }
    
    /**
     * Retrieves user names for all owner IDs (old and new).
     *
     * @param cases List of Case records.
     * @param oldOwnerMap Map of Case Id → old OwnerId.
     * @return Map of User Id → User Name.
     */
    private static Map<Id, String> getUserNames(List<Case> cases, Map<Id, Id> oldOwnerMap) {
        Set<Id> userIds = new Set<Id>();
        
        for (Case c : cases) {
            String prefix = String.valueOf(c.OwnerId).substring(0, 3);
            if (prefix == '005') {
                userIds.add(c.OwnerId);
            }
        }
        
        for (Id oldId : oldOwnerMap.values()) {
            if (oldId != null) {
                String prefix = String.valueOf(oldId).substring(0, 3);
                if (prefix == '005') {
                    userIds.add(oldId);
                }
            }
        }
        
        Map<Id, String> result = new Map<Id, String>();
        for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds]) {
            result.put(u.Id, u.Name);
        }
        
        return result;
    }
    
    /**
     * Retrieves queue names for all queue IDs (old and new).
     *
     * @param cases List of Case records.
     * @param oldOwnerMap Map of Case Id → old OwnerId.
     * @return Map of Queue Id → Queue Name.
     */
    private static Map<Id, String> getQueueNames(List<Case> cases, Map<Id, Id> oldOwnerMap) {
        Set<Id> queueIds = new Set<Id>();
        
        for (Case c : cases) {
            String prefix = String.valueOf(c.OwnerId).substring(0, 3);
            if (prefix == '00G') {
                queueIds.add(c.OwnerId);
            }
        }
        
        for (Id oldId : oldOwnerMap.values()) {
            if (oldId != null) {
                String prefix = String.valueOf(oldId).substring(0, 3);
                if (prefix == '00G') {
                    queueIds.add(oldId);
                }
            }
        }
        
        Map<Id, String> result = new Map<Id, String>();
        for (Group q : [SELECT Id, Name FROM Group WHERE Id IN :queueIds AND Type = 'Queue']) {
            result.put(q.Id, q.Name);
        }
        
        return result;
    }
}
