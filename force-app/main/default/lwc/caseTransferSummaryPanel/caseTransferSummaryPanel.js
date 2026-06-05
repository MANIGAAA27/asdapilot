/**
 * @file        caseTransferSummaryPanel.js
 * @description Main parent LWC for the Case Transfer Summary feature.
 *              Placed on the Case Lightning Record Page. Displays the latest
 *              CaseTransferSummary__c record, subscribes to CaseSummaryGenerated__e
 *              Platform Events for near-real-time refresh, and manages
 *              collapsed/expanded state for the history list.
 *              Implements HLD-CMP-009.
 * @author      ASDA Dev Agent
 * @created     2026-06-05
 * @see         HLD-CMP-009, HLD Section 6
 */
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { refreshApex } from '@salesforce/apex';

import getLatestSummary       from '@salesforce/apex/CaseSummaryController.getLatestSummary';
import getSummaryHistory      from '@salesforce/apex/CaseSummaryController.getSummaryHistory';
import regenerateSummary      from '@salesforce/apex/CaseSummaryController.regenerateSummary';
import getRecentTransferMinutes from '@salesforce/apex/CaseSummaryController.getRecentTransferMinutes';

const CHANNEL_NAME = '/event/CaseSummaryGenerated__e';

export default class CaseTransferSummaryPanel extends LightningElement {
    @api recordId;

    @track latestSummary      = null;
    @track isLoading          = true;
    @track hasError           = false;
    @track errorMessage       = '';
    @track isHistoryExpanded  = false;
    @track historyCount       = 0;

    _subscription             = null;
    _wiredLatestResult        = null;
    _wiredHistoryResult       = null;
    _recentMinutes            = 30;

    // ── Wire adapters ────────────────────────────────────────────────────────

    @wire(getLatestSummary, { caseId: '$recordId' })
    wiredLatestSummary(result) {
        this._wiredLatestResult = result;
        this.isLoading = false;
        if (result.data !== undefined) {
            this.latestSummary = result.data;
            this.hasError      = false;
            this.checkAutoExpand();
        } else if (result.error) {
            this.hasError     = true;
            this.errorMessage = 'Unable to load summary. Please refresh the page.';
        }
    }

    @wire(getSummaryHistory, { caseId: '$recordId', recordLimit: 50 })
    wiredHistory(result) {
        this._wiredHistoryResult = result;
        if (result.data) {
            this.historyCount = result.data.length > 1 ? result.data.length - 1 : 0;
        }
    }

    @wire(getRecentTransferMinutes)
    wiredSettings({ data }) {
        if (data) {
            this._recentMinutes = data;
        }
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this.subscribeToEvents();
    }

    disconnectedCallback() {
        this.unsubscribeFromEvents();
    }

    // ── Platform Event subscription ──────────────────────────────────────────

    subscribeToEvents() {
        const messageCallback = (response) => {
            const payload = response.data.payload;
            if (payload.CaseId__c === this.recordId) {
                this.handleRefresh();
            }
        };

        subscribe(CHANNEL_NAME, -1, messageCallback)
            .then((subscription) => {
                this._subscription = subscription;
            });

        onError((error) => {
            console.error('EMP API error:', JSON.stringify(error));
        });
    }

    unsubscribeFromEvents() {
        if (this._subscription) {
            unsubscribe(this._subscription, () => {
                this._subscription = null;
            });
        }
    }

    // ── Event handlers ───────────────────────────────────────────────────────

    handleRegenerate() {
        this.isLoading = true;
        regenerateSummary({ caseId: this.recordId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Summary Requested',
                    message: 'A new summary is being generated.',
                    variant: 'info'
                }));
                this.isLoading = false;
            })
            .catch((error) => {
                this.isLoading    = false;
                this.hasError     = true;
                this.errorMessage = error.body ? error.body.message : 'Regeneration failed.';
            });
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredLatestResult)
            .then(() => {
                refreshApex(this._wiredHistoryResult);
                this.isLoading = false;
            })
            .catch(() => {
                this.isLoading = false;
            });
    }

    toggleHistory() {
        this.isHistoryExpanded = !this.isHistoryExpanded;
    }

    // ── Auto-expand logic ────────────────────────────────────────────────────

    checkAutoExpand() {
        if (this.latestSummary && this.latestSummary.GenerationTimestamp__c) {
            const ts      = new Date(this.latestSummary.GenerationTimestamp__c);
            const now     = new Date();
            const diffMs  = now - ts;
            const diffMin = diffMs / 60000;
            if (diffMin <= this._recentMinutes) {
                this.isHistoryExpanded = false;
            }
        }
    }

    // ── Computed properties ──────────────────────────────────────────────────

    get hasSummaries() {
        return this.latestSummary !== null && this.latestSummary !== undefined;
    }

    get isInProgress() {
        return this.hasSummaries && this.latestSummary.GenerationStatus__c === 'In Progress';
    }

    get isFailed() {
        return this.hasSummaries && this.latestSummary.GenerationStatus__c === 'Failed';
    }

    get isSuccess() {
        return this.hasSummaries && this.latestSummary.GenerationStatus__c === 'Success';
    }

    get showHistory() {
        return this.historyCount > 0;
    }

    get historyToggleIcon() {
        return this.isHistoryExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get formattedTimestamp() {
        if (this.latestSummary && this.latestSummary.GenerationTimestamp__c) {
            return new Date(this.latestSummary.GenerationTimestamp__c).toLocaleString();
        }
        return '';
    }
}
