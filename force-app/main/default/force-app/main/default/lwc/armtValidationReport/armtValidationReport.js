/**
 * @file        armtValidationReport.js
 * @description Standalone Lightning Web Component for displaying and filtering
 *              validation report details from ARMT_ValidationReport__c records.
 *              Dispatches a custom 'reportfiltered' event when filters change.
 * @author      ASDA Dev Agent
 * @created     2026-06-06
 */
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getValidationReports from '@salesforce/apex/ARMT_ValidationReportController.getValidationReports';

/** Column definitions for the data table. */
const COLUMNS = [
    {
        label: 'Report ID',
        fieldName: 'reportId',
        type: 'text',
        sortable: true,
        cellAttributes: { alignment: 'left' }
    },
    {
        label: 'Status',
        fieldName: 'validationStatus',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'statusClass' }
        }
    },
    {
        label: 'Summary',
        fieldName: 'summary',
        type: 'text',
        wrapText: true,
        cellAttributes: { alignment: 'left' }
    },
    {
        label: 'Created Date',
        fieldName: 'createdDate',
        type: 'date',
        sortable: true,
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    }
];

/** Available status filter options. */
const STATUS_OPTIONS = [
    { label: 'All Statuses', value: '' },
    { label: 'BLOCKER', value: 'BLOCKER' },
    { label: 'WARNING', value: 'WARNING' },
    { label: 'INFO', value: 'INFO' }
];

export default class ArmtValidationReport extends LightningElement {

    // ─── Public Properties ────────────────────────────────────────────────────

    /** Optional report ID to pre-filter the displayed reports. */
    @api reportId;

    // ─── Tracked State ────────────────────────────────────────────────────────

    @track searchTerm = '';
    @track selectedStatus = '';
    @track sortedBy = 'createdDate';
    @track sortedDirection = 'desc';
    @track isLoading = false;
    @track errorMessage = '';
    @track allReports = [];

    // ─── Wired Data ───────────────────────────────────────────────────────────

    /** Wire adapter to load validation reports from Apex. */
    @wire(getValidationReports, { reportId: '$reportId' })
    wiredReports({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.allReports = data.map(record => ({
                id: record.Id,
                reportId: record.Report_Id__c,
                validationStatus: record.Validation_Status__c,
                summary: record.Summary__c,
                createdDate: record.CreatedDate,
                statusClass: this._getStatusClass(record.Validation_Status__c)
            }));
            this.errorMessage = '';
        } else if (error) {
            this.errorMessage = this._extractErrorMessage(error);
            this.allReports = [];
            this._showToast('Error', this.errorMessage, 'error');
        }
    }

    // ─── Computed Properties ──────────────────────────────────────────────────

    /** Returns the column definitions for the data table. */
    get columns() {
        return COLUMNS;
    }

    /** Returns the status filter options for the combobox. */
    get statusOptions() {
        return STATUS_OPTIONS;
    }

    /** Returns true when the component is in a loading state. */
    get isLoadingState() {
        return this.isLoading;
    }

    /** Returns true when there is an error to display. */
    get hasError() {
        return !!this.errorMessage;
    }

    /** Returns true when there are records to display after filtering. */
    get hasRecords() {
        return !this.isLoading && !this.hasError && this.filteredReports.length > 0;
    }

    /** Returns true when there are no records after filtering. */
    get isEmpty() {
        return !this.isLoading && !this.hasError && this.filteredReports.length === 0;
    }

    /** Returns true when summary badge data is available. */
    get hasSummaryData() {
        return this.allReports.length > 0;
    }

    /** Returns the count of BLOCKER reports in the full (unfiltered) dataset. */
    get blockerCount() {
        return this.allReports.filter(r => r.validationStatus === 'BLOCKER').length;
    }

    /** Returns the count of WARNING reports in the full (unfiltered) dataset. */
    get warningCount() {
        return this.allReports.filter(r => r.validationStatus === 'WARNING').length;
    }

    /** Returns the count of INFO reports in the full (unfiltered) dataset. */
    get infoCount() {
        return this.allReports.filter(r => r.validationStatus === 'INFO').length;
    }

    /**
     * Returns the filtered and sorted list of reports based on current
     * search term and status filter selections.
     */
    get filteredReports() {
        let result = [...this.allReports];

        // Apply status filter
        if (this.selectedStatus) {
            result = result.filter(r => r.validationStatus === this.selectedStatus);
        }

        // Apply search filter (case-insensitive match on summary or reportId)
        if (this.searchTerm) {
            const lowerSearch = this.searchTerm.toLowerCase();
            result = result.filter(r =>
                (r.summary && r.summary.toLowerCase().includes(lowerSearch)) ||
                (r.reportId && r.reportId.toLowerCase().includes(lowerSearch))
            );
        }

        // Apply sort
        result = this._sortData(result, this.sortedBy, this.sortedDirection);

        return result;
    }

    // ─── Event Handlers ───────────────────────────────────────────────────────

    /** Handles changes to the search input field. */
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this._dispatchFilteredEvent();
    }

    /** Handles changes to the status filter combobox. */
    handleStatusFilterChange(event) {
        this.selectedStatus = event.detail.value;
        this._dispatchFilteredEvent();
    }

    /** Handles the clear filters button click. */
    handleClearFilters() {
        this.searchTerm = '';
        this.selectedStatus = '';
        this._dispatchFilteredEvent();
    }

    /** Handles column sort events from the data table. */
    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    /**
     * Dispatches the custom 'reportfiltered' event with current filter state.
     * Parent components can listen to this event to react to filter changes.
     */
    _dispatchFilteredEvent() {
        const filterEvent = new CustomEvent('reportfiltered', {
            detail: {
                searchTerm: this.searchTerm,
                selectedStatus: this.selectedStatus,
                filteredCount: this.filteredReports.length
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(filterEvent);
    }

    /**
     * Returns a CSS class string based on the validation status value.
     *
     * @param {string} status - The validation status string.
     * @returns {string} CSS class string.
     */
    _getStatusClass(status) {
        switch (status) {
            case 'BLOCKER': return 'slds-text-color_error slds-font-weight_bold';
            case 'WARNING': return 'slds-text-color_warning';
            case 'INFO':    return 'slds-text-color_success';
            default:        return '';
        }
    }

    /**
     * Sorts an array of report objects by the given field and direction.
     *
     * @param {Array}  data       - Array of report objects to sort.
     * @param {string} field      - Field name to sort by.
     * @param {string} direction  - 'asc' or 'desc'.
     * @returns {Array} Sorted array.
     */
    _sortData(data, field, direction) {
        const multiplier = direction === 'asc' ? 1 : -1;
        return [...data].sort((a, b) => {
            const valA = a[field] || '';
            const valB = b[field] || '';
            if (valA < valB) return -1 * multiplier;
            if (valA > valB) return 1 * multiplier;
            return 0;
        });
    }

    /**
     * Extracts a human-readable error message from an Apex wire error.
     *
     * @param {Object} error - The error object from the wire adapter.
     * @returns {string} Human-readable error message.
     */
    _extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'An unexpected error occurred while loading validation reports.';
    }

    /**
     * Displays a toast notification to the user.
     *
     * @param {string} title   - Toast title.
     * @param {string} message - Toast message body.
     * @param {string} variant - Toast variant: success, error, warning, info.
     */
    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
