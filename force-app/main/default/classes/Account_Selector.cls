/**
 * @file              Account_Selector.cls
 * @description       FFLib-style selector layer for all SOQL queries related to
 *                    the Account 360 experience. Centralises query logic, enforces
 *                    field-level security via WITH SECURITY_ENFORCED, and applies
 *                    consistent LIMIT clauses to protect governor limits.
 *                    All callers must supply a queryLimit or accept the default.
 * @author            ASDA Dev Agent
 * @created           2026-06-23
 * @lastModified      2026-06-23
 * @group             Account360
 *
 * @dependencies      (none — selector is the lowest layer)
 * @calledBy          Account360_Service
 * @testClass         Account_SelectorTest
 *
 * @see               HLD-CMP-002: Account_Selector
 */

// MODIFIED 2026-06-23 — Project: Account 360 | CodeImplementation-Account360 | ASDA
/**
 * Centralises all SOQL for Account and its key child objects.
 *
 * Responsibilities:
 *   - Expose typed query methods for Account, Opportunity, Case,
 *     Contract, ERP_Order__c, and Invoice__c.
 *   - Apply WITH SECURITY_ENFORCED on every user-visible query.
 *   - Accept a nullable queryLimit; fall back to DEFAULT_QUERY_LIMIT.
 *   - Never perform SOQL inside a loop.
 *
 * Threading: static methods, no instance state.
 *
 * @testClass Account_SelectorTest
 */
public with sharing class Account_Selector {

    @TestVisible
    private static final Integer DEFAULT_QUERY_LIMIT = 100;

    // ─────────────────────────────────────────────────────────────────
    // Account
    // ─────────────────────────────────────────────────────────────────

    /**
     * Retrieves a single Account by Id, including fields required for the
     * Account 360 header and health score display.
     *
     * @param  accountId  Id of the Account to retrieve.
     * @return            Account record or null if not found / not accessible.
     * @calledBy          Account360_Service.getAccountData
     * @testMethods       test_getAccountById_validId_returnsAccount,
     *                    test_getAccountById_nullId_returnsNull
     */
    public static Account getAccountById(Id accountId) {
        if (accountId == null) {
            return null;
        }
        List<Account> results = [
            SELECT Id, Name, Industry, BillingCity, BillingCountry,
                   Phone, Website, Health_Score__c,
                   OwnerId, Owner.Name
            FROM Account
            WHERE Id = :accountId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0];
    }

    // ─────────────────────────────────────────────────────────────────
    // Opportunity
    // ─────────────────────────────────────────────────────────────────

    /**
     * Retrieves Opportunities for an Account, ordered by CloseDate ascending
     * so the most imminent opportunities appear first.
     *
     * @param  accountId   Id of the parent Account.
     * @param  queryLimit  Max records to return. Null uses DEFAULT_QUERY_LIMIT.
     * @return             List of Opportunity records, never null.
     * @calledBy           Account360_Service.getAccountData
     * @testMethods        test_getOpportunitiesForAccount_withData_returnsList,
     *                     test_getOpportunitiesForAccount_noData_returnsEmpty
     */
    public static List<Opportunity> getOpportunitiesForAccount(Id accountId, Integer queryLimit) {
        if (accountId == null) {
            return new List<Opportunity>();
        }
        Integer resolvedLimit = resolveLimit(queryLimit);
        return [
            SELECT Id, Name, StageName, Amount, CloseDate, Probability,
                   OwnerId, Owner.Name, IsClosed
            FROM Opportunity
            WHERE AccountId = :accountId
            WITH SECURITY_ENFORCED
            ORDER BY CloseDate ASC
            LIMIT :resolvedLimit
        ];
    }

    // ─────────────────────────────────────────────────────────────────
    // Case
    // ─────────────────────────────────────────────────────────────────

    /**
     * Retrieves Cases for an Account, ordered by Priority and LastModifiedDate
     * so high-priority recent cases appear first.
     *
     * @param  accountId   Id of the parent Account.
     * @param  queryLimit  Max records to return. Null uses DEFAULT_QUERY_LIMIT.
     * @return             List of Case records, never null.
     * @calledBy           Account360_Service.getAccountData
     * @testMethods        test_getCasesForAccount_withData_returnsList
     */
    public static List<Case> getCasesForAccount(Id accountId, Integer queryLimit) {
        if (accountId == null) {
            return new List<Case>();
        }
        Integer resolvedLimit = resolveLimit(queryLimit);
        return [
            SELECT Id, CaseNumber, Subject, Status, Priority,
                   OwnerId, Owner.Name, LastModifiedDate, IsClosed
            FROM Case
            WHERE AccountId = :accountId
            WITH SECURITY_ENFORCED
            ORDER BY LastModifiedDate DESC
            LIMIT :resolvedLimit
        ];
    }

    // ─────────────────────────────────────────────────────────────────
    // Contract
    // ─────────────────────────────────────────────────────────────────

    /**
     * Retrieves Contracts for an Account, ordered by EndDate ascending
     * to surface contracts nearest expiry.
     *
     * @param  accountId   Id of the parent Account.
     * @param  queryLimit  Max records to return. Null uses DEFAULT_QUERY_LIMIT.
     * @return             List of Contract records, never null.
     * @calledBy           Account360_Service.getAccountData
     * @testMethods        test_getContractsForAccount_withData_returnsList
     */
    public static List<Contract> getContractsForAccount(Id accountId, Integer queryLimit) {
        if (accountId == null) {
            return new List<Contract>();
        }
        Integer resolvedLimit = resolveLimit(queryLimit);
        return [
            SELECT Id, ContractNumber, StartDate, EndDate, Status,
                   ContractTerm, OwnerId
            FROM Contract
            WHERE AccountId = :accountId
            WITH SECURITY_ENFORCED
            ORDER BY EndDate ASC
            LIMIT :resolvedLimit
        ];
    }

    // ─────────────────────────────────────────────────────────────────
    // ERP_Order__c
    // ─────────────────────────────────────────────────────────────────

    /**
     * Retrieves ERP Orders for an Account, ordered by Order_Date__c descending
     * to show the most recent orders first.
     *
     * @param  accountId   Id of the parent Account.
     * @param  queryLimit  Max records to return. Null uses DEFAULT_QUERY_LIMIT.
     * @return             List of ERP_Order__c records, never null.
     * @calledBy           Account360_Service.getAccountData, Account360_Service.getERPOrders
     * @testMethods        test_getERPOrdersForAccount_withData_returnsList
     */
    public static List<ERP_Order__c> getERPOrdersForAccount(Id accountId, Integer queryLimit) {
        if (accountId == null) {
            return new List<ERP_Order__c>();
        }
        Integer resolvedLimit = resolveLimit(queryLimit);
        return [
            SELECT Id, Name, ERP_Order_ID__c, Order_Date__c,
                   Status__c, Total_Amount__c, Account__c
            FROM ERP_Order__c
            WHERE Account__c = :accountId
            WITH SECURITY_ENFORCED
            ORDER BY Order_Date__c DESC
            LIMIT :resolvedLimit
        ];
    }

    // ─────────────────────────────────────────────────────────────────
    // Invoice__c
    // ─────────────────────────────────────────────────────────────────

    /**
     * Retrieves Invoices for an Account, ordered by Due_Date__c ascending
     * to surface overdue and upcoming invoices first.
     *
     * @param  accountId   Id of the parent Account.
     * @param  queryLimit  Max records to return. Null uses DEFAULT_QUERY_LIMIT.
     * @return             List of Invoice__c records, never null.
     * @calledBy           Account360_Service.getAccountData
     * @testMethods        test_getInvoicesForAccount_withData_returnsList
     */
    public static List<Invoice__c> getInvoicesForAccount(Id accountId, Integer queryLimit) {
        if (accountId == null) {
            return new List<Invoice__c>();
        }
        Integer resolvedLimit = resolveLimit(queryLimit);
        return [
            SELECT Id, Name, ERP_Invoice_ID__c, Invoice_Date__c,
                   Due_Date__c, Status__c, Total_Amount__c, Account__c
            FROM Invoice__c
            WHERE Account__c = :accountId
            WITH SECURITY_ENFORCED
            ORDER BY Due_Date__c ASC
            LIMIT :resolvedLimit
        ];
    }

    // ─────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────

    /** Returns queryLimit if positive, otherwise DEFAULT_QUERY_LIMIT. */
    private static Integer resolveLimit(Integer queryLimit) {
        return (queryLimit != null && queryLimit > 0) ? queryLimit : DEFAULT_QUERY_LIMIT;
    }
}
