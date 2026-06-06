/**
 * @file        armtValidationReport.js
 * @description Standalone Lightning Web Component for displaying and filtering
 *              validation report details. Supports status-based filtering,
 *              summary badge display, and tabular report rendering.
 * @author      ASDA Dev Agent
 * @created     2026-06-06
 */
import { LightningElement, api, track } from 'lwc';

/** Column definitions for the validation report datatable. */
const COLUMNS = [
    { label: 'Report ID', fieldName: 'reportId', type: 'text', sortable: true },
    { label: 'Status', fieldName: 'validationStatus', type: 'text', sortable: true },
    { label: 'Summary', fieldName: 'summary', type: 'text', wrapText: true }
];

/** Status filter options for the combobox. */
const STATUS_OPTIONS = [
    { label: 'All Statuses', value: '' },
    { label: 'BLOCKER', value: 'BLOCKER' },
    { label: 'WARNING', value: 'WARNING' },
    { label: 'INFO', value: 'INFO' }
];

export default class ArmtValidationReport extends LightningElement {

    /** Public property: array of report objects to display. */
    @api
    get reports() {
        return this._reports;
    }
    set reports(value) {
        this._reports = value ? [...value] : [];
        this._applyFilter();
    }

    /** Public property: controls loading spinner visibility. */
    @api isLoading = false;

    /** Public property: error message to display in the error banner. */
    @api errorMessage = '';

    /** Internal report store. */
    _reports = [];

    /** Currently selected status filter value. */
    @track selectedStatus = '';

    /** Filtered subset of reports based on selectedStatus. */
    @track filteredReports = [];

    // ─────────────────────────────────────────────────────────────────────────
    // Getters
    // ─────────────────────────────────────────────────────────────────────────

    /** Returns column definitions for the datatable. */
    get columns() {
        return COLUMNS;
    }

    /** Returns status filter options for the combobox. */
    get statusOptions() {
        return STATUS_OPTIONS;
    }

    /** Returns true when there are filtered reports to display. */
    get hasReports() {
        return this.filteredReports && this.filteredReports.length > 0;
    }

    /** Returns true when an error message is present. */
    get hasError() {
        return this.errorMessage && this.errorMessage.length > 0;
    }

    /** Returns true when summary data is available. */
    get hasSummary() {
        return this._reports && this._reports.length > 0;
    }

    /** Returns the blocker count badge label. */
    get blockerLabel() {
        const count = this._reports.filter(r => r.validationStatus === 'BLOCKER').length;
        return `Blockers: ${count}`;
    }

    /** Returns the warning count badge label. */
    get warningLabel() {
        const count = this._reports.filter(r => r.validationStatus === 'WARNING').length;
        return `Warnings: ${count}`;
    }

    /** Returns the info count badge label. */
    get infoLabel() {
        const count = this._reports.filter(r => r.validationStatus === 'INFO').length;
        return `Info: ${count}`;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Event handlers
    // ─────────────────────────────────────────────────────────────────────────

    /** Handles status filter combobox change events. */
    handleStatusFilterChange(event) {
        this.selectedStatus = event.detail.value;
        this._applyFilter();
    }

    /** Clears the active status filter and shows all reports. */
    handleClearFilter() {
        this.selectedStatus = '';
        this._applyFilter();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Applies the current selectedStatus filter to the internal report list. */
    _applyFilter() {
        if (!this.selectedStatus) {
            this.filteredReports = [...this._reports];
        } else {
            this.filteredReports = this._reports.filter(
                r => r.validationStatus === this.selectedStatus
            );
        }
    }
}
