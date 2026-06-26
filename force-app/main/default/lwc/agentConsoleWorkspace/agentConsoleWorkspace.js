/**
 * @file              agentConsoleWorkspace.js
 * @description       Controller for the Agent Console Workspace LWC. Orchestrates
 *                    imperative Apex calls to AgentConsoleWorkspaceService to load
 *                    Case data, interactions, AI recommendations, and knowledge
 *                    articles. Manages an SLA countdown timer that refreshes every
 *                    60 seconds against CaseMilestone.TargetDate. Calls
 *                    markWorkspaceOpened imperatively on connectedCallback to stamp
 *                    Case.Workspace_Used__c and Case.Workspace_Opened_At__c.
 *
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-26
 * @lastModified      2026-06-26
 * @see               LLD-AgentConsoleWorkspace
 */

// MODIFIED 2026-06-26 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
import { LightningElement, api, track } from 'lwc';
import getCaseData from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseData';
import getInteractions from '@salesforce/apex/AgentConsoleWorkspaceService.getInteractions';
import getRecommendations from '@salesforce/apex/AgentConsoleWorkspaceService.getRecommendations';
import searchKnowledge from '@salesforce/apex/AgentConsoleWorkspaceService.searchKnowledge';
import markWorkspaceOpened from '@salesforce/apex/AgentConsoleWorkspaceService.markWorkspaceOpened';

const SLA_REFRESH_INTERVAL_MS = 60000; // Refresh SLA countdown every 60 seconds
const SLA_WARN_HOURS = 2;              // Threshold (hours) for warning colour
const SLA_CRITICAL_HOURS = 1;         // Threshold (hours) for critical colour
const KNOWLEDGE_SEARCH_DELAY_MS = 500; // Debounce delay for knowledge search

export default class AgentConsoleWorkspace extends LightningElement {

    /** Case record Id from the Lightning Record Page. */
    @api recordId;

    // ── State flags ──────────────────────────────────────────────────────────
    @track isLoading = true;
    @track interactionsLoading = false;
    @track recommendationsLoading = false;
    @track knowledgeLoading = false;

    // ── Data payloads ─────────────────────────────────────────────────────────
    @track caseData;
    @track interactionData;
    @track recommendations = [];
    @track knowledgeArticles = [];

    // ── UI state ──────────────────────────────────────────────────────────────
    @track errorMessage;
    @track slaCountdown = '';
    @track slaClass = 'slds-text-color_success';
    @track knowledgeSearchTerm = '';

    // ── Internal handles ──────────────────────────────────────────────────────
    _slaTimerHandle;
    _knowledgeSearchTimeout;

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    connectedCallback() {
        this._loadInitialData();
    }

    disconnectedCallback() {
        this._clearSlaTimer();
        if (this._knowledgeSearchTimeout) {
            clearTimeout(this._knowledgeSearchTimeout);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Data loading
    // ─────────────────────────────────────────────────────────────────────────

    async _loadInitialData() {
        this.isLoading = true;
        this.errorMessage = undefined;

        try {
            // Mark workspace as opened (write — not cacheable)
            await markWorkspaceOpened({ caseId: this.recordId });
        } catch (err) {
            // Non-fatal: log but continue workspace load
            console.warn('AgentConsoleWorkspace: markWorkspaceOpened failed', err);
        }

        try {
            // Load primary Case data
            this.caseData = await getCaseData({ caseId: this.recordId });

            // Kick off SLA countdown if milestones are present
            if (this.hasMilestones) {
                this._startSlaTimer();
            }

            // Lazy-load secondary panels in parallel
            this._loadInteractions();
            this._loadRecommendations();

            // Seed knowledge search from Case subject
            if (this.caseData && this.caseData.caseRecord && this.caseData.caseRecord.Subject) {
                const subjectWords = this.caseData.caseRecord.Subject.split(' ').slice(0, 3).join(' ');
                this.knowledgeSearchTerm = subjectWords;
                this._runKnowledgeSearch(subjectWords);
            }
        } catch (err) {
            this.errorMessage = this._extractMessage(err);
        } finally {
            this.isLoading = false;
        }
    }

    async _loadInteractions() {
        this.interactionsLoading = true;
        try {
            const contactId = (this.caseData && this.caseData.caseRecord)
                ? this.caseData.caseRecord.ContactId
                : null;
            this.interactionData = await getInteractions({
                caseId: this.recordId,
                contactId: contactId
            });
        } catch (err) {
            console.error('AgentConsoleWorkspace: getInteractions failed', err);
        } finally {
            this.interactionsLoading = false;
        }
    }

    async _loadRecommendations() {
        this.recommendationsLoading = true;
        try {
            this.recommendations = await getRecommendations({ caseId: this.recordId });
        } catch (err) {
            console.error('AgentConsoleWorkspace: getRecommendations failed', err);
            this.recommendations = [];
        } finally {
            this.recommendationsLoading = false;
        }
    }

    async _runKnowledgeSearch(term) {
        if (!term || term.trim().length < 2) {
            this.knowledgeArticles = [];
            return;
        }
        this.knowledgeLoading = true;
        try {
            this.knowledgeArticles = await searchKnowledge({ searchTerm: term.trim() });
        } catch (err) {
            console.error('AgentConsoleWorkspace: searchKnowledge failed', err);
            this.knowledgeArticles = [];
        } finally {
            this.knowledgeLoading = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SLA countdown timer
    // ─────────────────────────────────────────────────────────────────────────

    _startSlaTimer() {
        this._refreshSlaCountdown();
        this._slaTimerHandle = setInterval(() => {
            this._refreshSlaCountdown();
        }, SLA_REFRESH_INTERVAL_MS);
    }

    _clearSlaTimer() {
        if (this._slaTimerHandle) {
            clearInterval(this._slaTimerHandle);
            this._slaTimerHandle = null;
        }
    }

    _refreshSlaCountdown() {
        if (!this.caseData || !this.caseData.milestones || this.caseData.milestones.length === 0) {
            this.slaCountdown = 'No active milestones';
            return;
        }
        // Use the first (earliest) milestone target date
        const firstMilestone = this.caseData.milestones[0];
        if (!firstMilestone.TargetDate) {
            this.slaCountdown = 'No target date set';
            return;
        }
        const targetMs = new Date(firstMilestone.TargetDate).getTime();
        const nowMs = Date.now();
        const diffMs = targetMs - nowMs;

        if (diffMs <= 0) {
            this.slaCountdown = 'SLA Expired';
            this.slaClass = 'slds-text-color_error';
            return;
        }

        const totalMinutes = Math.floor(diffMs / 60000);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        this.slaCountdown = hours + 'h ' + minutes + 'm remaining';

        if (hours < SLA_CRITICAL_HOURS) {
            this.slaClass = 'slds-text-color_error';
        } else if (hours < SLA_WARN_HOURS) {
            this.slaClass = 'slds-text-color_warning';
        } else {
            this.slaClass = 'slds-text-color_success';
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Event handlers
    // ─────────────────────────────────────────────────────────────────────────

    handleKnowledgeSearch(event) {
        const searchTerm = event.target.value;
        this.knowledgeSearchTerm = searchTerm;

        if (this._knowledgeSearchTimeout) {
            clearTimeout(this._knowledgeSearchTimeout);
        }
        // Debounce — wait for user to stop typing before firing the SOSL
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._knowledgeSearchTimeout = setTimeout(() => {
            this._runKnowledgeSearch(searchTerm);
        }, KNOWLEDGE_SEARCH_DELAY_MS);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Computed getters — drive lwc:if and class bindings in template
    // ─────────────────────────────────────────────────────────────────────────

    get workspaceReady() {
        return !this.isLoading && !this.errorMessage && this.caseData != null;
    }

    get hasMilestones() {
        return this.caseData &&
               this.caseData.milestones &&
               this.caseData.milestones.length > 0;
    }

    get interactionsReady() {
        return !this.interactionsLoading && this.interactionData != null;
    }

    get hasEmails() {
        return this.interactionData &&
               this.interactionData.emails &&
               this.interactionData.emails.length > 0;
    }

    get hasTasks() {
        return this.interactionData &&
               this.interactionData.tasks &&
               this.interactionData.tasks.length > 0;
    }

    get hasPriorCases() {
        return this.interactionData &&
               this.interactionData.priorCases &&
               this.interactionData.priorCases.length > 0;
    }

    get noInteractions() {
        return this.interactionsReady &&
               !this.hasEmails &&
               !this.hasTasks &&
               !this.hasPriorCases;
    }

    get hasRecommendations() {
        return !this.recommendationsLoading &&
               this.recommendations &&
               this.recommendations.length > 0;
    }

    get noRecommendations() {
        return !this.recommendationsLoading &&
               (!this.recommendations || this.recommendations.length === 0);
    }

    get hasKnowledgeResults() {
        return !this.knowledgeLoading &&
               this.knowledgeArticles &&
               this.knowledgeArticles.length > 0;
    }

    get noKnowledgeResults() {
        return !this.knowledgeLoading &&
               this.knowledgeSearchTerm &&
               this.knowledgeSearchTerm.trim().length > 1 &&
               (!this.knowledgeArticles || this.knowledgeArticles.length === 0);
    }

    get getSlaClass() {
        return 'sla-countdown ' + this.slaClass;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

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