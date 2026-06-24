/**
 * @file              agentConsoleWorkspace.js
 * @description       Controller for the Agent Console Workspace LWC.
 *                    Loads Case, Account, Contact, previous interactions,
 *                    CaseMilestones, and AI recommendations via imperative
 *                    Apex calls on component load. Provides a client-side
 *                    SLA countdown timer refreshed every 60 seconds.
 *                    On connectedCallback, stamps Case.Workspace_Used__c
 *                    and Case.Workspace_Opened_At__c via trackWorkspaceOpen.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-24
 * @lastModified      2026-06-24
 * @project           Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
 */

// MODIFIED 2026-06-24 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
import { LightningElement, api, track } from 'lwc';
import getCaseDetails from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseDetails';
import getPreviousInteractions from '@salesforce/apex/AgentConsoleWorkspaceService.getPreviousInteractions';
import getKnowledgeArticles from '@salesforce/apex/AgentConsoleWorkspaceService.getKnowledgeArticles';
import getCaseMilestones from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseMilestones';
import getAIRecommendations from '@salesforce/apex/AgentConsoleWorkspaceService.getAIRecommendations';
import trackWorkspaceOpen from '@salesforce/apex/AgentConsoleWorkspaceService.trackWorkspaceOpen';

/** Interval in milliseconds between SLA timer refreshes. */
const SLA_REFRESH_INTERVAL_MS = 60000;

/** SLA warning threshold: minutes remaining below which to show warning colour. */
const SLA_WARNING_MINUTES = 120;

/** SLA critical threshold: minutes remaining below which to show critical colour. */
const SLA_CRITICAL_MINUTES = 30;

export default class AgentConsoleWorkspace extends LightningElement {
    /** Case record Id injected by the Lightning record page. */
    @api recordId;

    // ── Tracked state ────────────────────────────────────────────────────────

    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';

    @track caseData = null;
    @track interactions = null;
    @track interactionsLoading = false;
    @track knowledgeArticles = [];
    @track knowledgeSearchTerm = '';
    @track knowledgeLoading = false;
    @track milestones = [];
    @track aiRecommendations = [];

    // SLA timer state
    @track slaCountdownLabel = '';
    @track slaTimerClass = 'slds-p-around_small';

    /** Internal timer reference for cleanup. */
    _slaTimerHandle = null;

    // ── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this._loadWorkspace();
    }

    disconnectedCallback() {
        this._clearSlaTimer();
    }

    // ── Private data-loading methods ─────────────────────────────────────────

    /**
     * Orchestrates all initial data loads. Loads case details first, then
     * interactions, milestones and AI recommendations in parallel.
     */
    async _loadWorkspace() {
        this.isLoading = true;
        this.hasError = false;

        try {
            // Load case + account + contact header data
            this.caseData = await getCaseDetails({ caseId: this.recordId });

            // Stamp workspace usage asynchronously (fire and forget)
            trackWorkspaceOpen({ caseId: this.recordId }).catch(() => {
                // Non-critical — workspace tracking failure must not block the UI
            });

            // Load remaining panels in parallel
            await Promise.all([
                this._loadInteractions(),
                this._loadMilestones(),
                this._loadAIRecommendations()
            ]);

            // Pre-load knowledge articles using the case subject as the seed term
            if (this.caseData && this.caseData.caseRecord && this.caseData.caseRecord.Subject) {
                this.knowledgeSearchTerm = this.caseData.caseRecord.Subject;
                await this._fetchKnowledgeArticles(this.knowledgeSearchTerm);
            }

        } catch (err) {
            this.hasError = true;
            this.errorMessage = this._extractMessage(err);
        } finally {
            this.isLoading = false;
        }
    }

    async _loadInteractions() {
        this.interactionsLoading = true;
        try {
            this.interactions = await getPreviousInteractions({ caseId: this.recordId });
        } catch (err) {
            // Non-critical — log and continue
            console.error('AgentConsoleWorkspace: interactions load failed', err);
        } finally {
            this.interactionsLoading = false;
        }
    }

    async _loadMilestones() {
        try {
            this.milestones = await getCaseMilestones({ caseId: this.recordId }) || [];
            this._startSlaTimer();
        } catch (err) {
            this.milestones = [];
            console.error('AgentConsoleWorkspace: milestones load failed', err);
        }
    }

    async _loadAIRecommendations() {
        try {
            this.aiRecommendations = await getAIRecommendations({ caseId: this.recordId }) || [];
        } catch (err) {
            this.aiRecommendations = [];
            console.error('AgentConsoleWorkspace: AI recommendations load failed', err);
        }
    }

    async _fetchKnowledgeArticles(term) {
        if (!term || !term.trim()) {
            this.knowledgeArticles = [];
            return;
        }
        this.knowledgeLoading = true;
        try {
            this.knowledgeArticles = await getKnowledgeArticles({ searchTerm: term }) || [];
        } catch (err) {
            this.knowledgeArticles = [];
            console.error('AgentConsoleWorkspace: knowledge search failed', err);
        } finally {
            this.knowledgeLoading = false;
        }
    }

    // ── SLA timer ────────────────────────────────────────────────────────────

    _startSlaTimer() {
        this._tickSlaTimer();
        this._clearSlaTimer();
        this._slaTimerHandle = setInterval(() => this._tickSlaTimer(), SLA_REFRESH_INTERVAL_MS);
    }

    _clearSlaTimer() {
        if (this._slaTimerHandle) {
            clearInterval(this._slaTimerHandle);
            this._slaTimerHandle = null;
        }
    }

    _tickSlaTimer() {
        const milestone = this.activeMilestone;
        if (!milestone || !milestone.TargetDate) {
            this.slaCountdownLabel = 'No active milestone';
            this.slaTimerClass = 'slds-p-around_small';
            return;
        }

        const targetMs = new Date(milestone.TargetDate).getTime();
        const nowMs = Date.now();
        const remainingMs = targetMs - nowMs;
        const remainingMinutes = Math.floor(remainingMs / 60000);

        if (remainingMs <= 0) {
            this.slaCountdownLabel = 'SLA BREACHED';
            this.slaTimerClass = 'slds-p-around_small slds-theme_error slds-text-color_inverse';
        } else if (remainingMinutes <= SLA_CRITICAL_MINUTES) {
            this.slaCountdownLabel = this._formatCountdown(remainingMs) + ' remaining (CRITICAL)';
            this.slaTimerClass = 'slds-p-around_small slds-theme_error slds-text-color_inverse';
        } else if (remainingMinutes <= SLA_WARNING_MINUTES) {
            this.slaCountdownLabel = this._formatCountdown(remainingMs) + ' remaining (WARNING)';
            this.slaTimerClass = 'slds-p-around_small slds-theme_warning';
        } else {
            this.slaCountdownLabel = this._formatCountdown(remainingMs) + ' remaining';
            this.slaTimerClass = 'slds-p-around_small slds-theme_success slds-text-color_inverse';
        }
    }

    _formatCountdown(ms) {
        const totalSeconds = Math.floor(ms / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        return `${hours}h ${minutes}m`;
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    handleKnowledgeSearch(evt) {
        const term = evt.detail.value;
        this.knowledgeSearchTerm = term;
        if (term && term.length >= 3) {
            this._fetchKnowledgeArticles(term);
        } else if (!term) {
            this.knowledgeArticles = [];
        }
    }

    // ── Computed getters ─────────────────────────────────────────────────────

    get hasTasks() {
        return this.interactions && this.interactions.tasks && this.interactions.tasks.length > 0;
    }

    get hasEmails() {
        return this.interactions && this.interactions.emails && this.interactions.emails.length > 0;
    }

    get hasComments() {
        return this.interactions && this.interactions.comments && this.interactions.comments.length > 0;
    }

    get hasPriorCases() {
        return this.interactions && this.interactions.priorCases && this.interactions.priorCases.length > 0;
    }

    get hasInteractions() {
        return this.hasTasks || this.hasEmails || this.hasComments || this.hasPriorCases;
    }

    /** The first non-completed, non-violated milestone (most urgent). */
    get activeMilestone() {
        if (!this.milestones || this.milestones.length === 0) {
            return null;
        }
        const active = this.milestones.find(m => !m.IsCompleted);
        return active || this.milestones[0];
    }

    get accountLocation() {
        if (!this.caseData || !this.caseData.accountRecord) {
            return '';
        }
        const acc = this.caseData.accountRecord;
        const parts = [acc.BillingCity, acc.BillingState, acc.BillingCountry]
            .filter(v => v);
        return parts.join(', ');
    }

    // ── Utility ──────────────────────────────────────────────────────────────

    _extractMessage(err) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        if (err && err.message) {
            return err.message;
        }
        return 'An unexpected error occurred loading the workspace.';
    }
}