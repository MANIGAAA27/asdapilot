/**
 * @file         agentConsoleWorkspace.js
 * @description  Controller for the Agent Console Workspace LWC. Aggregates
 *               case details, customer profile, interaction history, knowledge
 *               articles, AI recommendations, and SLA milestone countdown into
 *               a single operational view for service managers and agents.
 * @author       ASDA Dev Agent (Claude Code)
 * @created      2026-06-26
 * @see          LLD-AgentConsoleWorkspace (Feature: Agent Console Workspace)
 * @project      Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
 */
// MODIFIED 2026-06-26 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
import { LightningElement, api, track } from 'lwc';
import getCaseDetails from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseDetails';
import getInteractionHistory from '@salesforce/apex/AgentConsoleWorkspaceService.getInteractionHistory';
import getKnowledgeArticles from '@salesforce/apex/AgentConsoleWorkspaceService.getKnowledgeArticles';
import getRecommendations from '@salesforce/apex/AgentConsoleWorkspaceService.getRecommendations';
import markWorkspaceOpened from '@salesforce/apex/AgentConsoleWorkspaceService.markWorkspaceOpened';

/** Milliseconds between SLA timer refresh cycles. */
const SLA_REFRESH_INTERVAL_MS = 60000;

/** Warning threshold in hours — SLA tiles turn amber below this value. */
const SLA_WARNING_HOURS = 4;

/** Critical threshold in hours — SLA tiles turn red below this value. */
const SLA_CRITICAL_HOURS = 2;

export default class AgentConsoleWorkspace extends LightningElement {
    /** Case record Id passed from the Lightning record page context. */
    @api recordId;

    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';

    // Data properties
    @track caseRecord = null;
    @track accountRecord = null;
    @track contactRecord = null;
    @track milestones = [];
    @track interactionHistory = null;
    @track knowledgeArticles = [];
    @track recommendations = [];

    /** Interval handle for the SLA countdown refresh. */
    _slaTimerInterval = null;

    /** Reactive copy of milestones with computed timer display values. */
    @track milestonesWithTimer = [];

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle hooks
    // ─────────────────────────────────────────────────────────────────────────

    connectedCallback() {
        this._loadWorkspace();
    }

    disconnectedCallback() {
        this._clearSlaTimer();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public data load orchestration
    // ─────────────────────────────────────────────────────────────────────────

    async _loadWorkspace() {
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }
        this.isLoading = true;
        this.hasError = false;

        try {
            // Load core case details first (case + account + contact + milestones)
            const wrapper = await getCaseDetails({ caseId: this.recordId });
            this.caseRecord = wrapper.caseRecord;
            this.accountRecord = wrapper.accountRecord;
            this.contactRecord = wrapper.contactRecord;
            this.milestones = wrapper.milestones || [];
            this._refreshMilestoneTimers();

            // Mark workspace opened (fire-and-forget; errors are non-blocking)
            markWorkspaceOpened({ caseId: this.recordId }).catch(() => {
                // Workspace stamp failure is non-fatal
            });

            // Load secondary panels after primary data is rendered
            await Promise.all([
                this._loadInteractionHistory(),
                this._loadKnowledgeArticles(),
                this._loadRecommendations()
            ]);

            // Start SLA timer refresh
            this._startSlaTimer();
        } catch (err) {
            this.hasError = true;
            this.errorMessage = this._extractErrorMessage(err);
        } finally {
            this.isLoading = false;
        }
    }

    async _loadInteractionHistory() {
        try {
            const contactId = this.contactRecord ? this.contactRecord.Id : null;
            const accountId = this.accountRecord ? this.accountRecord.Id : null;
            this.interactionHistory = await getInteractionHistory({
                caseId: this.recordId,
                contactId: contactId,
                accountId: accountId
            });
        } catch (err) {
            // Non-fatal — panel shows empty state
            this.interactionHistory = null;
        }
    }

    async _loadKnowledgeArticles() {
        if (!this.caseRecord || !this.caseRecord.Subject) {
            this.knowledgeArticles = [];
            return;
        }
        try {
            this.knowledgeArticles = await getKnowledgeArticles({
                searchTerm: this.caseRecord.Subject
            });
        } catch (err) {
            this.knowledgeArticles = [];
        }
    }

    async _loadRecommendations() {
        try {
            const rawRecs = await getRecommendations({ caseId: this.recordId });
            this.recommendations = (rawRecs || []).map(rec => ({
                ...rec,
                confidencePercent: rec.Confidence_Score__c
                    ? Math.round(rec.Confidence_Score__c * 100)
                    : null
            }));
        } catch (err) {
            this.recommendations = [];
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SLA countdown timer helpers
    // ─────────────────────────────────────────────────────────────────────────

    _startSlaTimer() {
        this._clearSlaTimer();
        this._slaTimerInterval = setInterval(() => {
            this._refreshMilestoneTimers();
        }, SLA_REFRESH_INTERVAL_MS);
    }

    _clearSlaTimer() {
        if (this._slaTimerInterval) {
            clearInterval(this._slaTimerInterval);
            this._slaTimerInterval = null;
        }
    }

    _refreshMilestoneTimers() {
        const now = new Date();
        this.milestonesWithTimer = (this.milestones || []).map(m => {
            const target = m.TargetDate ? new Date(m.TargetDate) : null;
            let timeRemaining = 'N/A';
            let timerClass = 'slds-text-color_default';

            if (target) {
                const diffMs = target - now;
                const diffHours = diffMs / (1000 * 60 * 60);

                if (diffMs < 0) {
                    timeRemaining = 'SLA Breached';
                    timerClass = 'slds-text-color_error';
                } else if (diffHours <= SLA_CRITICAL_HOURS) {
                    timeRemaining = this._formatDuration(diffMs);
                    timerClass = 'slds-text-color_error';
                } else if (diffHours <= SLA_WARNING_HOURS) {
                    timeRemaining = this._formatDuration(diffMs);
                    timerClass = 'slds-badge slds-theme_warning';
                } else {
                    timeRemaining = this._formatDuration(diffMs);
                    timerClass = 'slds-text-color_success';
                }
            }

            return {
                ...m,
                timeRemaining,
                timerClass
            };
        });
    }

    /** Formats milliseconds duration into a human-readable string. */
    _formatDuration(ms) {
        if (ms <= 0) {
            return '0m';
        }
        const totalMinutes = Math.floor(ms / 60000);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        if (hours > 0) {
            return `${hours}h ${minutes}m`;
        }
        return `${minutes}m`;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Event handlers
    // ─────────────────────────────────────────────────────────────────────────

    handleRefreshInteractions() {
        this._loadInteractionHistory();
    }

    handleSearchKnowledge() {
        this._loadKnowledgeArticles();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Computed getters (template conditions)
    // ─────────────────────────────────────────────────────────────────────────

    get hasMilestones() {
        return this.milestonesWithTimer && this.milestonesWithTimer.length > 0;
    }

    get hasCustomerProfile() {
        return this.contactRecord != null || this.accountRecord != null;
    }

    get hasInteractions() {
        if (!this.interactionHistory) return false;
        return (
            (this.interactionHistory.emailMessages && this.interactionHistory.emailMessages.length > 0) ||
            (this.interactionHistory.relatedCases && this.interactionHistory.relatedCases.length > 0) ||
            (this.interactionHistory.tasks && this.interactionHistory.tasks.length > 0) ||
            (this.interactionHistory.caseComments && this.interactionHistory.caseComments.length > 0)
        );
    }

    get hasEmails() {
        return this.interactionHistory &&
               this.interactionHistory.emailMessages &&
               this.interactionHistory.emailMessages.length > 0;
    }

    get hasRelatedCases() {
        return this.interactionHistory &&
               this.interactionHistory.relatedCases &&
               this.interactionHistory.relatedCases.length > 0;
    }

    get hasTasks() {
        return this.interactionHistory &&
               this.interactionHistory.tasks &&
               this.interactionHistory.tasks.length > 0;
    }

    get hasKnowledgeArticles() {
        return this.knowledgeArticles && this.knowledgeArticles.length > 0;
    }

    get hasRecommendations() {
        return this.recommendations && this.recommendations.length > 0;
    }

    /** CSS class for the SLA timer container — changes colour near breach. */
    get slaTimerClass() {
        const hasBreached = this.milestonesWithTimer.some(
            m => m.timeRemaining === 'SLA Breached'
        );
        const hasCritical = this.milestonesWithTimer.some(
            m => m.timerClass === 'slds-text-color_error' && m.timeRemaining !== 'SLA Breached'
        );
        if (hasBreached) {
            return 'slds-box slds-theme_error slds-p-around_x-small slds-m-bottom_small';
        }
        if (hasCritical) {
            return 'slds-box slds-theme_warning slds-p-around_x-small slds-m-bottom_small';
        }
        return 'slds-box slds-theme_shade slds-p-around_x-small slds-m-bottom_small';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Utilities
    // ─────────────────────────────────────────────────────────────────────────

    /** Extracts a human-readable error message from an Apex AuraHandledException. */
    _extractErrorMessage(err) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        if (err && err.message) {
            return err.message;
        }
        return 'An unexpected error occurred loading the workspace.';
    }
}