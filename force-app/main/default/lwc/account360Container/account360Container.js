/**
 * account360Container
 *
 * Parent container LWC for the Account 360 page. Owns all page state, calls
 * Account360_Service via @wire, and passes data down to child components.
 * Children emit events upward; this component decides whether to re-query.
 *
 * Pattern: single data provider (Account360_Service.getAccountData), one-way
 * data flow to children, event-up communication for refresh requests.
 *
 * @see HLD-CMP-010
 */
// MODIFIED 2026-06-23 — Project: Account 360 | CodeImplementation-Account360 | ASDA
import { LightningElement, api, wire, track } from 'lwc';
import getAccountData from '@salesforce/apex/Account360_Service.getAccountData';

export default class Account360Container extends LightningElement {
    /** Record Id injected by the Lightning record page. */
    @api recordId;

    @track isLoading = true;
    @track hasData = false;
    @track hasError = false;
    @track errorMessage = '';
    @track accountData;

    // ─────────────────────────────────────────────────────────────────
    // Column definitions (static — Phase 1 hard-coded per HLD tech debt note)
    // ─────────────────────────────────────────────────────────────────

    opportunityColumns = [
        { label: 'Name',        fieldName: 'Name',        type: 'text' },
        { label: 'Stage',       fieldName: 'StageName',   type: 'text' },
        { label: 'Amount',      fieldName: 'Amount',      type: 'currency' },
        { label: 'Close Date',  fieldName: 'CloseDate',   type: 'date' },
        { label: 'Probability', fieldName: 'Probability', type: 'percent' }
    ];

    caseColumns = [
        { label: 'Case #',  fieldName: 'CaseNumber',        type: 'text' },
        { label: 'Subject', fieldName: 'Subject',           type: 'text' },
        { label: 'Status',  fieldName: 'Status',            type: 'text' },
        { label: 'Priority',fieldName: 'Priority',          type: 'text' }
    ];

    contractColumns = [
        { label: 'Contract #', fieldName: 'ContractNumber', type: 'text' },
        { label: 'Start Date', fieldName: 'StartDate',      type: 'date' },
        { label: 'End Date',   fieldName: 'EndDate',        type: 'date' },
        { label: 'Status',     fieldName: 'Status',         type: 'text' }
    ];

    invoiceColumns = [
        { label: 'Invoice ID',    fieldName: 'ERP_Invoice_ID__c', type: 'text' },
        { label: 'Invoice Date',  fieldName: 'Invoice_Date__c',   type: 'date' },
        { label: 'Due Date',      fieldName: 'Due_Date__c',       type: 'date' },
        { label: 'Status',        fieldName: 'Status__c',         type: 'text' },
        { label: 'Total Amount',  fieldName: 'Total_Amount__c',   type: 'currency' }
    ];

    // ─────────────────────────────────────────────────────────────────
    // Wire
    // ─────────────────────────────────────────────────────────────────

    @wire(getAccountData, { accountId: '$recordId' })
    wiredAccountData({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.accountData = data;
            this.hasData = true;
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
            this.hasData = false;
            this.errorMessage = error.body
                ? (error.body.message || 'An unexpected error occurred loading Account 360 data.')
                : 'An unexpected error occurred loading Account 360 data.';
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // Derived getters
    // ─────────────────────────────────────────────────────────────────

    get accountName() {
        return this.accountData && this.accountData.accountRecord
            ? this.accountData.accountRecord.Name
            : '';
    }

    get healthScore() {
        return this.accountData && this.accountData.accountRecord
            ? this.accountData.accountRecord.Health_Score__c
            : 100;
    }

    get opportunities() {
        return this.accountData ? this.accountData.opportunities : [];
    }

    get cases() {
        return this.accountData ? this.accountData.cases : [];
    }

    get contracts() {
        return this.accountData ? this.accountData.contracts : [];
    }

    get invoices() {
        return this.accountData ? this.accountData.invoices : [];
    }

    get erpOrders() {
        return this.accountData ? this.accountData.erpOrders : [];
    }

    // ─────────────────────────────────────────────────────────────────
    // Event handlers
    // ─────────────────────────────────────────────────────────────────

    /** Handles refresh request events bubbled up from child components. */
    handleRefresh() {
        this.isLoading = true;
        this.hasData = false;
        this.hasError = false;
        // Wire re-evaluates when reactive property changes; toggle to force refresh
        const currentRecordId = this.recordId;
        this.recordId = null;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        Promise.resolve().then(() => {
            this.recordId = currentRecordId;
        });
    }
}