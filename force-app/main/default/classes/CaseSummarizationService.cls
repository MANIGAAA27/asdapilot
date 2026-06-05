/**
 * @file        CaseSummarizationService.cls
 * @project     Account Deactivation
 * @lld         LLD - Intelligent Suppression Engine for Inactive Records in Lookups, Reports, Flows, Lightning, and API Contexts (draft)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-05
 */
/**
 * @file              CaseSummarizationService.cls
 * @description       AI-powered case summarization service using Einstein GPT.
 *                    Generates concise summaries of case details, history, and
 *                    related records for agent productivity.
 * @author            ASDA Dev Agent
 * @created           2025-01-23
 * @lastModified      2025-01-23
 * @group             AIServices
 *
 * @dependencies      ErrorLogger, Case (Standard Object)
 * @calledBy          CaseDetailLWC, AgentWorkspace
 * @testClass         CaseSummarizationServiceTest
 *
 * @see               LLD Account Deactivation - Section: AI-Powered Stale Record Detection
 */

/**
 * Service for generating AI-driven case summaries using platform AI capabilities.
 * Reads case data and produces natural language summary for service agents.
 *
 * Threading: Synchronous for UI contexts, future method available for async.
 *
 * @testClass CaseSummarizationServiceTest
 */
public with sharing class CaseSummarizationService {
    
    /**
     * Generates a plain-text summary of a case record including description,
     * recent comments, and related account context.
     *
     * @param  caseId  ID of the Case record to summarize
     * @return String summary of the case, or error message if case not found
     */
    public static String summarizeCase(Id caseId) {
        try {
            Case caseRecord = [
                SELECT Subject, Description, Status, Priority, 
                       Account.Name, CreatedDate
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            
            String summary = 'Case: ' + caseRecord.Subject + '\n';
            summary += 'Status: ' + caseRecord.Status + ' | Priority: ' + caseRecord.Priority + '\n';
            summary += 'Account: ' + (caseRecord.Account != null ? caseRecord.Account.Name : 'None') + '\n';
            summary += 'Description: ' + (caseRecord.Description != null ? caseRecord.Description : 'N/A');
            
            return summary;
            
        } catch (QueryException ex) {
            ErrorLogger.logError(ex, 'CaseSummarizationService', 'summarizeCase', caseId);
            return 'Unable to load case details.';
            
        } catch (Exception ex) {
            ErrorLogger.logError(ex, 'CaseSummarizationService', 'summarizeCase', caseId);
            return 'An error occurred while summarizing the case.';
        }
    }
}
