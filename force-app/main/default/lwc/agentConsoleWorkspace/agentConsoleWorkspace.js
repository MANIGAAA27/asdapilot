/**
 * @file        agentConsoleWorkspace.js
 * @description Controller for the Agent Console Workspace LWC. Aggregates case details,
 *              customer profile, previous interactions, AI recommendations, and SLA
 *              milestone data into a unified operational view for service managers and
 *              support agents. Calls AgentConsoleWorkspaceService Apex methods.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-25
 * @project     Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
 * @lld         LLD-AgentConsoleWorkspace
 */

// MODIFIED 2026-06-25 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
import { LightningElement, api, wire, track } from 'lwc';
import getCaseDetails          from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseDetails';
import getPreviousInteractions from '@salesforce/apex/AgentConsoleWorkspaceService.getPreviousInteractions';
import getAiRecommendations    from '@salesforce/apex/AgentConsoleWorkspaceService.getAiRecommendations';
import getCaseMilestones       from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseMilestones';
import trackWorkspaceOpen      from '@salesforce/apex/AgentConsoleWorkspaceService.trackWorkspaceOpen';

// SLA visual threshold constants (minutes remaining).
const SLA_WARNING_THRESHOLD_MINS  = 120;   // 2 hours  → yellow
const SLA_CRITICAL_THRESHOLD_MINS = 30;    // 30 mins  → red
const SLA_REFRESH_INTERVAL_MS     = 60000; // 1 minute → refresh cadence

export default class AgentConsoleWorkspace extends LightningElement {

    /** Populated by the Lightning record page via recordId API. */
    @api recordId;

    // ── Wire adapter results ──────────────────────────────────────────────────
    @track _caseDetails     = null;
    @track _recommendations = [];
    @track _milestones      = [];

    // ── Imperative call state ─────────────────────────────────────────────────
    @track interactions          = [];
    @track isInteractionsLoading = false;

    // ── UI state ──────────────────────────────────────────────────────────────
    @track isLoading    = true;
    @track hasError     = false;
    @track errorMessage = '';

    // ── SLA countdown ─────────────────────────────────────────────────────────
    _slaTimerIntervalId      = null;
    @track slaCountdownDisplay = '';
    @track slaCountdownClass   = 'slds-text-heading_small';

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    connectedCallback() {
        this._trackOpen();
        this._startSlaTimer();
    }

    disconnectedCallback() {
        this._stopSlaTimer();
    }

    // ── Wire adapters ─────────────────────────────────────────────────────────

    @wire(getCaseDetails, { caseId: '$recordId' })
    wiredCaseDetails({ error, data }) {
        if (data) {
            this._caseDetails = data;
            this.isLoading    = false;
            this._loadInteractions();
        } else if (error) {
            this._handleError('Failed to load case details', error);
        }
    }

    @wire(getAiRecommendations, { caseId: '$recordId' })
    wiredRecommendations({ error, data }) {
        if (data) {
            this._recommendations = data;
        } else if (error) {
            // Non-fatal: recommendations panel degrades gracefully.
            console.error('[agentConsoleWorkspace] AI recommendations error:', error);
        }
    }

    @wire(getCaseMilestones, { caseId: '$recordId' })
    wiredMilestones({ error, data }) {
        if (data) {
            this._milestones = data;
            this._updateSlaCountdown();
        } else if (error) {
            // Non-fatal: milestones may not be configured in all orgs.
            console.error('[agentConsoleWorkspace] Milestones error:', error);
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /** Imperatively loads previous interactions after the case details wire resolves. */
    _loadInteractions() {
        if (!this.recordId) { return; }
        this.isInteractionsLoading = true;
        getPreviousInteractions({ caseId: this.recordId })
            .then(result => {
                this.interactions = (result || []).map((item, index) => ({
                    ...item,
                    uniqueKey: item.recordType + '_' + index
                }));
                this.isInteractionsLoading = false;
            })
            .catch(err => {
                console.error('[agentConsoleWorkspace] Interactions error:', err);
                this.isInteractionsLoading = false;
            });
    }

    /** Fires workspace-open tracking (DML — imperative, not cacheable). */
    _trackOpen() {
        if (!this.recordId) { return; }
        trackWorkspaceOpen({ caseId: this.recordId })
            .catch(err => {
                // Non-fatal — tracking failure must not surface to the agent.
                console.warn('[agentConsoleWorkspace] trackWorkspaceOpen failed:', err);
            });
    }

    _startSlaTimer() {
        this._updateSlaCountdown();
        this._slaTimerIntervalId = setInterval(() => {
            this._updateSlaCountdown();
        }, SLA_REFRESH_INTERVAL_MS);
    }

    _stopSlaTimer() {
        if (this._slaTimerIntervalId) {
            clearInterval(this._slaTimerIntervalId);
            this._slaTimerIntervalId = null;
        }
    }

    /** Recomputes countdown display string and CSS class from the nearest milestone. */
    _updateSlaCountdown() {
        if (!this._milestones || this._milestones.length === 0) {
            this.slaCountdownDisplay = '';
            return;
        }
        const soonest = this._milestones[0];
        if (!soonest.TargetDate) {
            this.slaCountdownDisplay = 'No target date';
            return;
        }
        const remainingMs   = new Date(soonest.TargetDate).getTime() - Date.now();
        const remainingMins = Math.floor(remainingMs / 60000);

        if (remainingMins < 0) {
            this.slaCountdownDisplay = 'OVERDUE by ' + Math.abs(remainingMins) + ' min';
            this.slaCountdownClass   = 'slds-text-color_error slds-text-heading_small';
        } else if (remainingMins <= SLA_CRITICAL_THRESHOLD_MINS) {
            this.slaCountdownDisplay = remainingMins + ' min remaining';
            this.slaCountdownClass   = 'slds-text-color_error slds-text-heading_small';
        } else if (remainingMins <= SLA_WARNING_THRESHOLD_MINS) {
            const hrs  = Math.floor(remainingMins / 60);
            const mins = remainingMins % 60;
            this.slaCountdownDisplay = hrs + 'h ' + mins + 'm remaining';
            this.slaCountdownClass   = 'slds-text-color_warning slds-text-heading_small';
        } else {
            const hrs  = Math.floor(remainingMins / 60);
            const mins = remainingMins % 60;
            this.slaCountdownDisplay = hrs + 'h ' + mins + 'm remaining';
            this.slaCountdownClass   = 'slds-text-color_success slds-text-heading_small';
        }
    }

    _handleError(context, error) {
        this.isLoading    = false;
        this.hasError     = true;
        const msg = error && error.body ? error.body.message : JSON.stringify(error);
        this.errorMessage = context + ': ' + msg;
        console.error('[agentConsoleWorkspace]', context, error);
    }

    // ── Computed getters — Case Details ───────────────────────────────────────

    get caseDetails()      { return this._caseDetails; }
    get caseNumber()       { return this._caseDetails && this._caseDetails.caseRecord ? this._caseDetails.caseRecord.CaseNumber  : ''; }
    get caseStatus()       { return this._caseDetails && this._caseDetails.caseRecord ? this._caseDetails.caseRecord.Status      : ''; }
    get casePriority()     { return this._caseDetails && this._caseDetails.caseRecord ? this._caseDetails.caseRecord.Priority    : ''; }
    get caseOrigin()       { return this._caseDetails && this._caseDetails.caseRecord ? this._caseDetails.caseRecord.Origin      : ''; }
    get caseSubject()      { return this._caseDetails && this._caseDetails.caseRecord ? this._caseDetails.caseRecord.Subject     : ''; }
    get caseDescription()  { return this._caseDetails && this._caseDetails.caseRecord ? this._caseDetails.caseRecord.Description : ''; }
    get caseCreatedDate()  { return this._caseDetails && this._caseDetails.caseRecord ? this._caseDetails.caseRecord.CreatedDate : null; }
    get isEscalatedDisplay() {
        if (!this._caseDetails || !this._caseDetails.caseRecord) { return 'No'; }
        return this._caseDetails.caseRecord.IsEscalated ? 'Yes' : 'No';
    }

    // ── Computed getters — Customer Profile ───────────────────────────────────

    get accountName()  { return this._caseDetails ? this._caseDetails.accountName  : ''; }
    get contactName()  { return this._caseDetails ? this._caseDetails.contactName  : ''; }
    get contactEmail() { return this._caseDetails ? this._caseDetails.contactEmail : ''; }
    get contactPhone() { return this._caseDetails ? this._caseDetails.contactPhone : ''; }

    // ── Computed getters — Interactions ───────────────────────────────────────

    get hasInteractions() { return this.interactions && this.interactions.length > 0; }

    // ── Computed getters — AI Recommendations ─────────────────────────────────

    get recommendations()    { return this._recommendations; }
    get hasRecommendations() { return this._recommendations && this._recommendations.length > 0; }

    // ── Computed getters — SLA Milestones ─────────────────────────────────────

    get milestones()    { return this._milestones; }
    get hasMilestones() { return this._milestones && this._milestones.length > 0; }
    get nextMilestoneName() {
        return this._milestones && this._milestones.length > 0
            ? this._milestones[0].MilestoneType.Name
            : '';
    }
}