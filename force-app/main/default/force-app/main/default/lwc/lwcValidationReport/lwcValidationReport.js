/**
 * @file        lwcValidationReport.js
 * @description Parent/dashboard Lightning Web Component for the validation report
 *              component tree. Orchestrates data loading and passes report data
 *              to the child armtValidationReport component.
 * @author      ASDA Dev Agent
 * @created     2026-06-06
 */
import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

export default class LwcValidationReport extends LightningElement {

    /** The record ID of the parent migration job or context record. */
    @api recordId;

    /** Tracks whether data is currently loading. */
    @track isLoading = false;

    /** Tracks any error message to surface to the user. */
    @track errorMessage = '';

    /** The report data array passed to the child component. */
    @track reportData = [];

    /** The computed overall validation status. */
    @track overallStatus = '';

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle hooks
    // ─────────────────────────────────────────────────────────────────────────

    connectedCallback() {
        this._loadReportData();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Getters
    // ─────────────────────────────────────────────────────────────────────────

    /** Returns true when an overall status is available to display. */
    get hasOverallStatus() {
        return this.overallStatus && this.overallStatus.length > 0;
    }

    /** Returns the CSS class for the overall status banner. */
    get overallStatusClass() {
        const base = 'slds-notify slds-notify_alert slds-m-bottom_medium ';
        if (this.overallStatus === 'BLOCKER') {
            return base + 'slds-theme_error';
        }
        if (this.overallStatus === 'WARNING') {
            return base + 'slds-theme_warning';
        }
        return base + 'slds-theme_success';
    }

    /** Returns the icon name for the overall status banner. */
    get overallStatusIcon() {
        if (this.overallStatus === 'BLOCKER') {
            return 'utility:error';
        }
        if (this.overallStatus === 'WARNING') {
            return 'utility:warning';
        }
        return 'utility:success';
    }

    /** Returns the label text for the overall status banner. */
    get overallStatusLabel() {
        if (this.overallStatus === 'BLOCKER') {
            return 'Migration Blocked';
        }
        if (this.overallStatus === 'WARNING') {
            return 'Warnings Present';
        }
        return 'Validation Passed';
    }

    /** Returns the descriptive message for the overall status banner. */
    get overallStatusMessage() {
        if (this.overallStatus === 'BLOCKER') {
            return 'One or more BLOCKER issues must be resolved before migration can proceed.';
        }
        if (this.overallStatus === 'WARNING') {
            return 'Review warnings before proceeding. Migration can continue but risks exist.';
        }
        return 'All validation checks passed. Migration is ready to execute.';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Event handlers
    // ─────────────────────────────────────────────────────────────────────────

    /** Handles the refresh button click — reloads report data. */
    handleRefresh() {
        this._loadReportData();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Loads validation report data. In a full implementation this would call
     * an @AuraEnabled Apex method. For V1, initialises with empty state.
     */
    _loadReportData() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            // In a full implementation: call Apex controller to fetch reports
            // For now, initialise with empty array — data will be passed via @api
            this.reportData = [];
            this._computeOverallStatus();
        } catch (err) {
            this.errorMessage = err && err.message
                ? err.message
                : 'An unexpected error occurred while loading validation data.';
        } finally {
            this.isLoading = false;
        }
    }

    /** Computes the overall status from the current report data. */
    _computeOverallStatus() {
        if (!this.reportData || this.reportData.length === 0) {
            this.overallStatus = '';
            return;
        }

        const hasBlocker = this.reportData.some(r => r.validationStatus === 'BLOCKER');
        const hasWarning = this.reportData.some(r => r.validationStatus === 'WARNING');

        if (hasBlocker) {
            this.overallStatus = 'BLOCKER';
        } else if (hasWarning) {
            this.overallStatus = 'WARNING';
        } else {
            this.overallStatus = 'INFO';
        }
    }
}
