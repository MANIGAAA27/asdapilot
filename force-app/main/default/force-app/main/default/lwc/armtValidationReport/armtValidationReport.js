/**
 * @file          armtValidationReport.js
 * @description   Standalone Lightning Web Component for displaying and filtering validation
 *                report details. Retrieves ARMT_ValidationReport__c records via Apex,
 *                supports status filtering, displays severity badges, and dispatches
 *                a 'validationcomplete' event to parent components when the user marks
 *                the validation step as complete.
 * @author        ASDA Dev Agent
 * @created       2026-06-06
 * @see           HLD-ARMT-V1.0 Section 3.4, HLD-CMP-023
 */

import { LightningElement, track, wire } from 'lwc';
import getValidationReports from '@salesforce/apex/ARMT_ValidationReportController.getValidationReports';

/** Status filter options for the combobox. */
const STATUS_OPTIONS = [
    { label: 'All Statuses', value: '' },
    { label: 'BLOCKER', value: 'BLOCKER' },
    { label: 'WARNING', value: 'WARNING' },
    { label: 'INFO', value: 'INFO' }
];

export default class ArmtValidationReport extends LightningElement {

    /** Currently selected status filter value. */
    @track selectedStatus = '';

    /** All validation reports retrieved from Apex. */
    @track allReports = [];

    /** Whether the component is in a loading state. */
    @track isLoading = false;

    /** Whether an error has occurred. */
    @track hasError = false;

    /** Error message to display. */
    @track errorMessage = '';

    /** Status filter options for the combobox. */
    get statusOptions() {
        return STATUS_OPTIONS;
    }

    /** Whether a status filter is currently active. */
    get hasActiveFilter() {
        return this.selectedStatus !== '';
    }

    /** Reports filtered by the selected status. */
    get filteredReports() {
        let reports = this.allReports;
        if (this.selectedStatus) {
            reports = reports.filter(r => r.Validation_Status__c === this.selectedStatus);
        }
        return reports.map(r => ({
            ...r,
            badgeClass: this.getBadgeClass(r.Validation_Status__c),
            rowClass: this.getRowClass(r.Validation_Status__c)
        }));
    }

    /** Whether there are records to display. */
    get hasRecords() {
        return !this.isLoading && !this.hasError && this.filteredReports.length > 0;
    }

    /** Whether the empty state should be shown. */
    get isEmpty() {
        return !this.isLoading && !this.hasError && this.filteredReports.length === 0;
    }

    /** Count of BLOCKER reports. */
    get blockerCount() {
        return this.allReports.filter(r => r.Validation_Status__c === 'BLOCKER').length;
    }

    /** Count of WARNING reports. */
    get warningCount() {
        return this.allReports.filter(r => r.Validation_Status__c === 'WARNING').length;
    }

    /** Count of INFO reports. */
    get infoCount() {
        return this.allReports.filter(r => r.Validation_Status__c === 'INFO').length;
    }

    /** Whether the Mark Complete button should be disabled (blockers present). */
    get isMarkCompleteDisabled() {
        return this.blockerCount > 0;
    }

    /**
     * Lifecycle hook — loads validation reports on component initialization.
     */
    connectedCallback() {
        this.loadReports();
    }

    /**
     * Loads validation reports from Apex with the current status filter.
     */
    loadReports() {
        this.isLoading = true;
        this.hasError = false;
        this.errorMessage = '';

        getValidationReports({ statusFilter: this.selectedStatus || null })
            .then(data => {
                this.allReports = data || [];
                this.isLoading = false;
            })
            .catch(error => {
                this.hasError = true;
                this.errorMessage = error && error.body && error.body.message
                    ? error.body.message
                    : 'An unexpected error occurred while loading validation reports.';
                this.isLoading = false;
            });
    }

    /**
     * Handles status filter combobox change events.
     * @param {Event} event - The change event from lightning-combobox.
     */
    handleStatusFilterChange(event) {
        this.selectedStatus = event.detail.value;
        this.loadReports();
    }

    /**
     * Clears the active status filter and reloads all reports.
     */
    handleClearFilter() {
        this.selectedStatus = '';
        this.loadReports();
    }

    /**
     * Dispatches a 'validationcomplete' custom event to the parent component.
     * Only enabled when no BLOCKER reports are present.
     */
    handleMarkComplete() {
        if (this.blockerCount > 0) {
            return;
        }
        const completeEvent = new CustomEvent('validationcomplete', {
            detail: {
                blockerCount: this.blockerCount,
                warningCount: this.warningCount,
                infoCount: this.infoCount,
                totalCount: this.allReports.length
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(completeEvent);
    }

    /**
     * Returns the SLDS badge CSS class for a given validation status.
     * @param {string} status - The Validation_Status__c value.
     * @returns {string} The CSS class string for the badge.
     */
    getBadgeClass(status) {
        switch (status) {
            case 'BLOCKER':
                return 'slds-badge slds-badge_error';
            case 'WARNING':
                return 'slds-badge slds-badge_warning';
            case 'INFO':
            default:
                return 'slds-badge';
        }
    }

    /**
     * Returns the CSS row class for a given validation status.
     * @param {string} status - The Validation_Status__c value.
     * @returns {string} The CSS class string for the table row.
     */
    getRowClass(status) {
        switch (status) {
            case 'BLOCKER':
                return 'slds-hint-parent slds-is-selected';
            case 'WARNING':
                return 'slds-hint-parent';
            default:
                return '';
        }
    }
}
