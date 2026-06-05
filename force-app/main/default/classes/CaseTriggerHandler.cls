/**
 * @file        CaseTriggerHandler.cls
 * @project     Case Transfer
 * @lld         LLD-CaseTransfer-2 (BR3-BR4)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-05
 */
/**
 * @file              CaseTriggerHandler.cls
 * @description       Handler for Case trigger events. Detects ownership changes
 *                    (agent-to-agent, agent-to-queue, queue-to-agent transfers)
 *                    and enqueues async summary generation via CaseTransferService.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-23
 * @lastModified      2026-05-23
 * @group             CaseManagement
 *
 * @dependencies      CaseTransferService
 * @calledBy          CaseTrigger
 * @testClass         CaseTriggerHandlerTest
 *
 * @see               LLD Case Transfer Summary Generation
 */

/**
 * Centralized handler for Case trigger logic.
 *
 * Responsibilities:
 *   - Detect Case ownership changes (OwnerId field modifications).
 *   - Identify transfer type (User→User, User→Queue, Queue→User).
 *   - Delegate to CaseTransferService for summary generation.
 *
 * Threading: executes synchronously in trigger context. CaseTransferService
 * handles async queueable chaining for LLM calls.
 *
 * @testClass CaseTriggerHandlerTest
 */
public with sharing class CaseTriggerHandler {
    
    /**
     * Handles before insert events. Currently no-op; reserved for future validation.
     *
     * @param newCases List of Case records being inserted.
     */
    public void beforeInsert(List<Case> newCases) {
        // Reserved for future validation logic
    }
    
    /**
     * Handles before update events. Currently no-op; reserved for future validation.
     *
     * @param newCases List of Case records being updated.
     * @param oldMap   Map of Case Id → old version of record.
     */
    public void beforeUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        // Reserved for future validation logic
    }
    
    /**
     * Handles after insert events. Currently no-op; transfers detected on update only.
     *
     * @param newCases List of Case records that were inserted.
     */
    public void afterInsert(List<Case> newCases) {
        // Transfers only occur on update (OwnerId change)
    }
    
    /**
     * Handles after update events. Detects OwnerId changes and enqueues
     * summary generation for transferred cases.
     *
     * @param newCases List of Case records after update.
     * @param oldMap   Map of Case Id → old version of record.
     */
    public void afterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        Set<Id> transferredCaseIds = new Set<Id>();
        
        for (Case c : newCases) {
            Case oldCase = oldMap.get(c.Id);
            
            // Detect ownership change
            if (c.OwnerId != oldCase.OwnerId) {
                transferredCaseIds.add(c.Id);
            }
        }
        
        if (!transferredCaseIds.isEmpty()) {
            CaseTransferService.handleTransfers(transferredCaseIds);
        }
    }
}
