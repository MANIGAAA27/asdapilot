/**
 * @file        caseSummaryPanel.js
 * @description LWC controller for the Case Transfer Summary side-panel component.
 *              Wires to CaseSummaryController.getLatestSummary to retrieve the
 *              most recent successful summary for the current Case record.
 *              The card is rendered only when a summary exists (FR17/FR19);
 *              when getLatestSummary returns null the template is entirely hidden.
 *
 * @imports     CaseSummaryController.getLatestSummary (requires CaseSummaryController.cls)
 */
import { LightningElement, api, wire } from 'lwc';
import getLatestSummary from '@salesforce/apex/CaseSummaryController.getLatestSummary';

export default class CaseSummaryPanel extends LightningElement {
    /** Injected by the Lightning record page — the current Case Id. */
    @api recordId;

    summary      = null;
    isLoading    = true;
    errorMessage = null;

    @wire(getLatestSummary, { caseId: '$recordId' })
    wiredSummary({ error, data }) {
        this.isLoading = false;
        if (data !== undefined) {
            this.summary = data;
        } else if (error) {
            this.errorMessage =
                (error.body && error.body.message)
                    ? error.body.message
                    : 'An error occurred while loading the case transfer summary.';
        }
    }

    /** True only when a successful summary record was returned. */
    get hasSummary() {
        return this.summary !== null && this.summary !== undefined;
    }

    /** True when the wire adapter returned an error. */
    get hasError() {
        return this.errorMessage !== null && this.errorMessage !== undefined;
    }

    /** Formats the transfer timestamp for display. */
    get formattedTimestamp() {
        if (!this.summary || !this.summary.Transfer_Timestamp__c) {
            return '';
        }
        return new Date(this.summary.Transfer_Timestamp__c).toLocaleString();
    }
}