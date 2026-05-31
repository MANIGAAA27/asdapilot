/**
 * @file              CaseTestDataFactory.cls
 * @description       Centralised test data factory for Case Transfer feature tests.
 *                    Provides builder methods for Case, Account, Contact, and Error_Log__c
 *                    records. All methods insert and return SObjects so callers can chain.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             CaseTransfer
 *
 * @dependencies      Error_Log__c (custom object)
 * @calledBy          CaseTransferServiceTest, CaseTransferControllerTest,
 *                    CaseTransferAPITest, CaseTriggerHandlerTest,
 *                    CaseTransferDomainTest, ErrorLoggerTest
 * @testClass         (this IS the test data factory — tested indirectly via consumers)
 *
 * @see               LLD Case Transfer Flow — Test Strategy §10
 */

/**
 * Factory for generating test SObject records across the Case Transfer feature.
 *
 * Responsibilities:
 *   - Single source of truth for test data setup.
 *   - Expose bulk createCases(n) for 200-record governor-limit tests.
 *   - Never hard-code record Ids.
 *
 * @testClass (see consumer test classes)
 */
@isTest
public class CaseTestDataFactory {

    /**
     * Creates and inserts a single Case with the given subject and default required fields.
     *
     * @param  subject  Subject line for the test Case.
     * @return          Inserted Case record.
     */
    public static Case createCase(String subject) {
        Case c = new Case(
            Subject = subject,
            Status  = 'New',
            Origin  = 'Web',
            Priority = 'Medium',
            Transferred_to_Engineering__c = false
        );
        insert c;
        return c;
    }

    /**
     * Creates and inserts N Cases with auto-generated subjects.
     *
     * @param  count  Number of Case records to create.
     * @return        List of inserted Case records.
     */
    public static List<Case> createCases(Integer count) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(new Case(
                Subject  = 'Test Case ' + i,
                Status   = 'New',
                Origin   = 'Web',
                Priority = 'Medium',
                Transferred_to_Engineering__c = false
            ));
        }
        insert cases;
        return cases;
    }

    /**
     * Creates and inserts a Case with all transfer-required fields populated.
     *
     * @param  subject  Subject line for the test Case.
     * @return          Inserted Case with transfer fields filled.
     */
    public static Case createTransferReadyCase(String subject) {
        Case c = new Case(
            Subject                        = subject,
            Status                         = 'New',
            Origin                         = 'Web',
            Priority                       = 'Medium',
            Reproduction_Steps__c          = 'Reproducible_on_Demand',
            Troubleshooting_Steps_Taken__c = 'Verified error in logs. Replicated in sandbox. Checked configuration.',
            Transferred_to_Engineering__c  = false
        );
        insert c;
        return c;
    }

    /**
     * Creates and inserts an Error_Log__c record for ErrorLogger tests.
     *
     * @param  message  Error message text to store.
     * @return          Inserted Error_Log__c record.
     */
    public static Error_Log__c createErrorLog(String message) {
        Error_Log__c log = new Error_Log__c(
            Error_Message__c = message,
            Class_Name__c    = 'TestFactory',
            Severity__c      = 'Error',
            User_Context__c  = 'Test User'
        );
        insert log;
        return log;
    }

    /**
     * Creates and inserts an Account for use as a Case parent.
     *
     * @param  name  Account name.
     * @return       Inserted Account record.
     */
    public static Account createAccount(String name) {
        Account a = new Account(Name = name, Industry = 'Technology');
        insert a;
        return a;
    }
}
