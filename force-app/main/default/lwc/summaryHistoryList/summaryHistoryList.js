/**
 * @file        summaryHistoryList.js
 * @description Child LWC that displays a collapsible list of historical
 *              CaseTransferSummary__c records for a Case. Receives caseId
 *              as a public property and queries via CaseSummaryController.
 *              Implements HLD-CMP-011.
 * @author      ASDA Dev Agent
 * @created     2026-06-05
 * @see         HLD-CMP-011, HLD Section 6
 */
import { LightningElement, api, wire } from 'lwc';
import getSummaryHistory from '@salesforce/apex/CaseSummaryController.getSummaryHistory';

export default class SummaryHistoryList extends LightningElement {
    @api caseId;

    summaryHistory = [];
    isLoading      = true;
    hasError       = false;

    @wire(getSummaryHistory, { caseId: '$caseId', recordLimit: 50 })
    wiredHistory({ data, error }) {
        this.isLoading = false;
        if (data) {
            // Skip index 0 — that is the latest summary shown by the parent
            this.summaryHistory = data.length > 1 ? data.slice(1) : [];
            this.hasError       = false;
        } else if (error) {
            this.hasError       = true;
            this.summaryHistory = [];
        }
    }

    get hasHistory() {
        return this.summaryHistory && this.summaryHistory.length > 0;
    }
}
