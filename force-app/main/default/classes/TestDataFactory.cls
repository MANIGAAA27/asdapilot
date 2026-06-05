/**
 * @file        TestDataFactory.cls
 * @project     Account Deactivation
 * @lld         LLD - Intelligent Suppression Engine for Inactive Records in Lookups, Reports, Flows, Lightning, and API Contexts (draft)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-05
 */
/**
 * @file              TestDataFactory.cls
 * @description       Centralized test data creation utility for all test classes.
 *                    Provides reusable methods for creating Account, Contact, and
 *                    other SObject records with consistent defaults.
 * @author            ASDA Dev Agent
 * @created           2025-01-23
 * @lastModified      2025-01-23
 * @group             TestUtilities
 *
 * @dependencies      None
 * @calledBy          All test classes in platform
 * @testClass         TestDataFactoryTest
 *
 * @see               LLD Account Deactivation Platform
 */

/**
 * Factory class for creating test data across all test classes.
 * Eliminates duplicate data setup code and ensures consistent test data patterns.
 *
 * @testClass TestDataFactoryTest
 */
@isTest
public class TestDataFactory {
    
    /**
     * Creates a list of Account records with standard defaults.
     *
     * @param  count      Number of accounts to create
     * @param  doInsert   If true, inserts records; if false, returns unsaved records
     * @return List of Account records
     */
    public static List<Account> createAccounts(Integer count, Boolean doInsert) {
        List<Account> accounts = new List<Account>();
        
        for (Integer i = 0; i < count; i++) {
            Account acc = new Account(
                Name = 'Test Account ' + i,
                Industry = 'Technology',
                Type = 'Customer',
                Inactive__c = false,
                Last_Activity_Date__c = Date.today()
            );
            accounts.add(acc);
        }
        
        if (doInsert) {
            insert accounts;
        }
        
        return accounts;
    }
    
    /**
     * Creates a list of Contact records with standard defaults.
     *
     * @param  accountId  ID of the Account to associate contacts with
     * @param  count      Number of contacts to create
     * @param  doInsert   If true, inserts records; if false, returns unsaved records
     * @return List of Contact records
     */
    public static List<Contact> createContacts(Id accountId, Integer count, Boolean doInsert) {
        List<Contact> contacts = new List<Contact>();
        
        for (Integer i = 0; i < count; i++) {
            Contact con = new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'test.contact' + i + '@example.com',
                AccountId = accountId,
                Inactive__c = false
            );
            contacts.add(con);
        }
        
        if (doInsert) {
            insert contacts;
        }
        
        return contacts;
    }
    
    /**
     * Creates a single Governance_Log__c record for testing logging behavior.
     *
     * @param  logType    Type of log ('Error', 'Info', 'Warning')
     * @param  className  Name of the class being logged
     * @param  doInsert   If true, inserts record; if false, returns unsaved record
     * @return Governance_Log__c record
     */
    public static Governance_Log__c createGovernanceLog(String logType, String className, Boolean doInsert) {
        Governance_Log__c log = new Governance_Log__c(
            Log_Type__c = logType,
            Class_Name__c = className,
            Method_Name__c = 'testMethod',
            Error_Message__c = 'Test log message',
            Timestamp__c = System.now()
        );
        
        if (doInsert) {
            insert log;
        }
        
        return log;
    }
}
