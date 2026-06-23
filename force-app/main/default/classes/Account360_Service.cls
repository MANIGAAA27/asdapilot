/**
 * @file              Account360_Service.cls
 * @description       Central @AuraEnabled service class providing aggregated
 *                    Account 360 data to the account360Container LWC. Delegates
 *                    all SOQL to Account_Selector to enforce FLS and query limits.
 *                    Returns a typed AccountDataWrapper DTO for efficient wire
 *                    service consumption.
 * @author            ASDA Dev Agent
 * @created           2026-06-23
 * @lastModified      2026-06-23
 * @group             Account360
 *
 * @dependencies      Account_Selector
 * @calledBy          (none in this changeset — LWC wire adapter calls @AuraEnabled methods)
 * @testClass         Account360_ServiceTest
 *
 * @see               HLD-CMP-001: Account360_Service
 */

// MODIFIED 2026-06-23 — Project: Account 360 | CodeImplementation-Account360 | ASDA
/**
 * Service layer for the Account 360 LWC.
 *
 * Responsibilities:
 *   - Aggregate Account, Opportunity, Case, Contract, ERP_Order__c, and
 *     Invoice__c data into a single AccountDataWrapper response.
 *   - Provide a focused ERP orders query for the account360ErpData child.
 *   - Delegate all SOQL to Account_Selector.
 *   - Surface AuraHandledExceptions for clean LWC error handling.
 *
 * Threading: static methods, no instance state.
 *
 * @testClass Account360_ServiceTest
 */
public with sharing class Account360_Service {

    @TestVisible
    private static final Integer DEFAULT_RECORD_LIMIT = 10;

    // ─────────────────────────────────────────────────────────────────
    // Inner DTO
    // ─────────────────────────────────────────────────────────────────

    /**
     * Data transfer object returned to the account360Container LWC.
     * All properties are @AuraEnabled for wire adapter consumption.
     */
    public class AccountDataWrapper {
        @AuraEnabled public Account accountRecord { get; set; }
        @AuraEnabled public List<Opportunity> opportunities { get; set; }
        @AuraEnabled public List<Case> cases { get; set; }
        @AuraEnabled public List<Contract> contracts { get; set; }
        @AuraEnabled public List<ERP_Order__c> erpOrders { get; set; }
        @AuraEnabled public List<Invoice__c> invoices { get; set; }

        /** Initialises all list properties to empty to prevent null-checks in JS. */
        public AccountDataWrapper() {
            this.opportunities = new List<Opportunity>();
            this.cases = new List<Case>();
            this.contracts = new List<Contract>();
            this.erpOrders = new List<ERP_Order__c>();
            this.invoices = new List<Invoice__c>();
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // @AuraEnabled methods
    // ─────────────────────────────────────────────────────────────────

    /**
     * Returns a fully aggregated AccountDataWrapper for the given Account Id.
     * Called by the account360Container LWC via @wire.
     *
     * @param  accountId  Salesforce Record Id of the Account (String to accept
     *                    both 15- and 18-char Ids from the LWC recordId property).
     * @return            Populated AccountDataWrapper. Never null.
     * @throws AuraHandledException on invalid/null accountId or query failure.
     *
     * @calledBy    (LWC: account360Container via @wire)
     * @testMethods test_getAccountData_validId_returnsWrapper,
     *              test_getAccountData_nullId_throwsException,
     *              test_getAccountData_blankId_throwsException
     */
    @AuraEnabled(cacheable=true)
    public static AccountDataWrapper getAccountData(String accountId) {
        if (String.isBlank(accountId)) {
            throw new AuraHandledException('Account ID is required.');
        }
        try {
            Id acctId = (Id) accountId;
            AccountDataWrapper wrapper = new AccountDataWrapper();
            wrapper.accountRecord = Account_Selector.getAccountById(acctId);
            wrapper.opportunities  = Account_Selector.getOpportunitiesForAccount(acctId, DEFAULT_RECORD_LIMIT);
            wrapper.cases          = Account_Selector.getCasesForAccount(acctId, DEFAULT_RECORD_LIMIT);
            wrapper.contracts      = Account_Selector.getContractsForAccount(acctId, DEFAULT_RECORD_LIMIT);
            wrapper.erpOrders      = Account_Selector.getERPOrdersForAccount(acctId, DEFAULT_RECORD_LIMIT);
            wrapper.invoices       = Account_Selector.getInvoicesForAccount(acctId, DEFAULT_RECORD_LIMIT);
            return wrapper;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to load Account 360 data: ' + ex.getMessage());
        }
    }

    /**
     * Returns ERP Orders for the given Account, with an optional record limit.
     * Called by the account360ErpData child LWC for targeted refresh.
     *
     * @param  accountId   Salesforce Record Id of the Account.
     * @param  queryLimit  Maximum number of records to return. Null uses DEFAULT_RECORD_LIMIT.
     * @return             List of ERP_Order__c records. Never null.
     * @throws AuraHandledException on invalid accountId or query failure.
     *
     * @calledBy    (LWC: account360ErpData via imperative call)
     * @testMethods test_getERPOrders_validId_returnsList,
     *              test_getERPOrders_nullId_throwsException
     */
    @AuraEnabled(cacheable=true)
    public static List<ERP_Order__c> getERPOrders(String accountId, Integer queryLimit) {
        if (String.isBlank(accountId)) {
            throw new AuraHandledException('Account ID is required.');
        }
        try {
            Id acctId = (Id) accountId;
            Integer resolvedLimit = (queryLimit != null && queryLimit > 0) ? queryLimit : DEFAULT_RECORD_LIMIT;
            return Account_Selector.getERPOrdersForAccount(acctId, resolvedLimit);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to load ERP Orders: ' + ex.getMessage());
        }
    }
}
