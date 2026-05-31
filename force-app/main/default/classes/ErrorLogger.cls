/**
 * @file              ErrorLogger.cls
 * @description       Utility class providing methods to log exceptions, create Error_Log__c
 *                    records with full stack trace and user context, and notify administrators
 *                    of critical errors via email. Uses without sharing to ensure logs are
 *                    always persisted regardless of user record access.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             CaseTransfer
 *
 * @dependencies      Error_Log__c (custom object)
 * @calledBy          CaseTransferService, CaseTransferController, CaseTransferAPI,
 *                    CaseTriggerHandler
 * @testClass         ErrorLoggerTest
 *
 * @see               LLD Case Transfer Flow — Error Handling Design §8
 */

/**
 * Centralised error logging utility for the Case Transfer feature.
 *
 * Responsibilities:
 *   - Capture full stack traces and user context for all handled exceptions.
 *   - Persist Error_Log__c records for auditing and operations monitoring.
 *   - Send email alerts to org administrators for critical failures.
 *
 * Threading: without sharing to guarantee log writes regardless of the
 * running user's record access. Never expose this class to untrusted input.
 *
 * @testClass ErrorLoggerTest
 */
public without sharing class ErrorLogger {

    private static final String SEVERITY_ERROR = 'Error';
    private static final String SEVERITY_WARNING = 'Warning';
    private static final String SEVERITY_INFO = 'Info';

    /**
     * Logs a caught exception to Error_Log__c with full stack trace and class context.
     * Safe to call from catch blocks — never re-throws.
     *
     * @param  ex         The exception to log. Stack trace is extracted automatically.
     * @param  className  Name of the Apex class where the exception was caught.
     *
     * @calledBy   CaseTransferService, CaseTransferController, CaseTriggerHandler
     * @testMethods test_logException_validException_createsLog,
     *              test_logException_nullException_handlesGracefully
     */
    public static void logException(Exception ex, String className) {
        try {
            String stackTrace = ex.getStackTraceString();
            String message = ex.getMessage();
            createErrorLog(message, className, stackTrace, SEVERITY_ERROR, null);
        } catch (Exception logEx) {
            // Swallow to prevent infinite error loops — log to debug only
            System.debug(LoggingLevel.ERROR, 'ErrorLogger.logException failed: ' + logEx.getMessage());
        }
    }

    /**
     * Logs an exception with an associated Salesforce record ID for traceability.
     *
     * @param  ex              The exception to log.
     * @param  className       Apex class name where the exception was caught.
     * @param  relatedRecordId The SObject Id associated with this error (e.g., Case Id).
     *
     * @calledBy   CaseTransferService, CaseTransferAPI
     * @testMethods test_logException_withRecordId_setsRelatedId
     */
    public static void logException(Exception ex, String className, Id relatedRecordId) {
        try {
            String stackTrace = ex.getStackTraceString();
            String message = ex.getMessage();
            createErrorLog(message, className, stackTrace, SEVERITY_ERROR, relatedRecordId);
        } catch (Exception logEx) {
            System.debug(LoggingLevel.ERROR, 'ErrorLogger.logException (with recordId) failed: ' + logEx.getMessage());
        }
    }

    /**
     * Creates and inserts an Error_Log__c record directly from raw string data.
     * Used when no exception object is available (e.g., Flow fault paths).
     *
     * @param  message          Human-readable error description.
     * @param  className        Apex class or component name where the error originated.
     * @param  stackTrace       Stack trace string or description of call path.
     * @param  severity         Severity level: 'Error', 'Warning', or 'Info'.
     * @param  relatedRecordId  Optional related SObject Id; null if not applicable.
     *
     * @calledBy   logException, CaseTransferAPI
     * @testMethods test_createErrorLog_validData_insertsRecord
     */
    public static void createErrorLog(
        String message,
        String className,
        String stackTrace,
        String severity,
        Id relatedRecordId
    ) {
        Error_Log__c logRecord = new Error_Log__c(
            Error_Message__c   = message != null ? message.left(32768) : 'No message provided',
            Stack_Trace__c     = stackTrace != null ? stackTrace.left(32768) : '',
            Class_Name__c      = className != null ? className.left(255) : '',
            User_Context__c    = UserInfo.getName() + ' (' + UserInfo.getUserId() + ')',
            Severity__c        = severity != null ? severity : SEVERITY_ERROR,
            Related_Record_Id__c = relatedRecordId != null ? String.valueOf(relatedRecordId) : null
        );
        insert logRecord;
    }

    /**
     * Sends a critical error alert email to all active Salesforce administrators.
     * Uses OrgWideEmailAddress where available; falls back to current user.
     *
     * @param  subject  Email subject line summarising the error.
     * @param  body     Full email body with error details.
     *
     * @calledBy   CaseTransferService (on critical failure)
     * @testMethods test_notifyAdministrator_validMessage_queuesEmail
     */
    public static void notifyAdministrator(String subject, String body) {
        try {
            List<User> admins = [
                SELECT Email
                FROM   User
                WHERE  Profile.Name = 'System Administrator'
                AND    IsActive = true
                WITH   SECURITY_ENFORCED
                LIMIT  10
            ];
            if (admins.isEmpty()) {
                return;
            }
            List<String> adminEmails = new List<String>();
            for (User admin : admins) {
                adminEmails.add(admin.Email);
            }
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(adminEmails);
            email.setSubject('[Case Transfer Flow] ' + subject);
            email.setPlainTextBody(body + '\n\nTimestamp: ' + Datetime.now().format());
            email.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'ErrorLogger.notifyAdministrator failed: ' + ex.getMessage());
        }
    }
}
