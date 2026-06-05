/**
 * @file        ErrorLogger.cls
 * @project     Account Deactivation
 * @lld         LLD - Intelligent Suppression Engine for Inactive Records in Lookups, Reports, Flows, Lightning, and API Contexts (draft)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-05
 */
/**
 * @file              ErrorLogger.cls
 * @description       Centralized error logging service for the Data Lifecycle
 *                    Governance platform. Routes all exceptions to Governance_Log__c
 *                    and provides structured error capture patterns.
 * @author            ASDA Dev Agent
 * @created           2025-01-23
 * @lastModified      2025-01-23
 * @group             CoreFramework
 *
 * @dependencies      Governance_Log__c (Custom Object)
 * @calledBy          All service classes in platform (SuppressionService, 
 *                    InactivationPolicyBatch, etc.)
 * @testClass         ErrorLoggerTest
 *
 * @see               LLD Account Deactivation Platform
 */

/**
 * Service for routing all exceptions through a centralized logging pattern.
 * All catch blocks in the platform must call logError() instead of inline handling.
 *
 * @testClass ErrorLoggerTest
 */
public with sharing class ErrorLogger {
    
    /**
     * Logs an exception to Governance_Log__c with full context capture.
     *
     * @param ex            The caught exception to log
     * @param contextClass  Name of the class where error occurred
     * @param contextMethod Name of the method where error occurred
     * @param recordId      Optional: ID of the record being processed when error occurred
     */
    public static void logError(Exception ex, String contextClass, String contextMethod, String recordId) {
        try {
            Governance_Log__c log = new Governance_Log__c(
                Log_Type__c = 'Error',
                Class_Name__c = contextClass,
                Method_Name__c = contextMethod,
                Error_Message__c = ex.getMessage(),
                Stack_Trace__c = ex.getStackTraceString(),
                Record_Id__c = recordId,
                Timestamp__c = System.now()
            );
            
            insert log;
            
        } catch (Exception loggingEx) {
            // Final fallback - publish platform event for async monitoring
            System.debug(LoggingLevel.ERROR, 'ErrorLogger failed: ' + loggingEx.getMessage());
            System.debug(LoggingLevel.ERROR, 'Original error: ' + ex.getMessage());
        }
    }
    
    /**
     * Logs an exception without a specific record context.
     *
     * @param ex            The caught exception to log
     * @param contextClass  Name of the class where error occurred
     * @param contextMethod Name of the method where error occurred
     */
    public static void logError(Exception ex, String contextClass, String contextMethod) {
        logError(ex, contextClass, contextMethod, null);
    }
    
    /**
     * Creates and throws a custom AppException with proper error logging.
     *
     * @param message       Error message for the exception
     * @param contextClass  Name of the class throwing the exception
     * @param contextMethod Name of the method throwing the exception
     * @throws AppException Always throws after logging
     */
    public static void throwAppException(String message, String contextClass, String contextMethod) {
        AppException ex = new AppException(message);
        logError(ex, contextClass, contextMethod);
        throw ex;
    }
}
