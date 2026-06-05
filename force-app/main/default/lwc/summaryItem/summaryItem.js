/**
 * @file        summaryItem.js
 * @description Child LWC that renders a single CaseTransferSummary__c record.
 *              Displays summary text, generation time, new owner, and status.
 *              Implements HLD-CMP-010.
 * @author      ASDA Dev Agent
 * @created     2026-06-05
 * @see         HLD-CMP-010, HLD Section 6
 */
import { LightningElement, api } from 'lwc';

export default class SummaryItem extends LightningElement {
    @api summary;

    get isSuccess() {
        return this.summary && this.summary.GenerationStatus__c === 'Success';
    }

    get isFailed() {
        return this.summary && this.summary.GenerationStatus__c === 'Failed';
    }

    get isInProgress() {
        return this.summary && this.summary.GenerationStatus__c === 'In Progress';
    }

    get formattedTimestamp() {
        if (this.summary && this.summary.GenerationTimestamp__c) {
            return new Date(this.summary.GenerationTimestamp__c).toLocaleString();
        }
        return '';
    }

    get statusBadgeClass() {
        if (this.isSuccess)    return 'slds-theme_success';
        if (this.isFailed)     return 'slds-theme_error';
        return 'slds-theme_shade';
    }
}
