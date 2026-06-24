/**
 * @file        agentConsoleWorkspace.js
 * @description Controller for the Agent Console Workspace LWC. Consolidates
 *              Case details, Customer Profile, Previous Interactions,
 *              Knowledge Articles, AI Recommendations, and SLA Countdown Timer.
 * @project     Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
 */

// MODIFIED 2026-06-24 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
import { LightningElement, api, track } from 'lwc';
import getCaseData from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseData';
import getPreviousInteractions from '@salesforce/apex/AgentConsoleWorkspaceService.getPreviousInteractions';
import searchKnowledge from '@salesforce/apex/AgentConsoleWorkspaceService.searchKnowledge';
import markWorkspaceOpened from '@salesforce/apex/AgentConsoleWorkspaceService.markWorkspaceOpened';

const SLA_WARNING_THRESHOLD_MS = 2 * 60 * 60 * 1000; // 2 hours
const TIMER_INTERVAL_MS = 60000; // 60 seconds

export default class AgentConsoleWorkspace extends LightningElement {

    @api recordId;

    @track caseData = null;
    @track interactions = null;
    @track knowledgeArticles = [];
    @track knowledgeSearchTerm = '';
    @track knowledgeError = null;

    isLoading = true;
    isLoadingInteractions = false;
    isLoadingKnowledge = false;
    errorMessage = null;
    _slaTimerInterval = null;
    _slaCountdowns = [];
    _knowledgeSearched = false;

    connectedCallback() {
        this._loadWorkspace();
    }

    disconnectedCallback() {
        this._clearSlaTimer();
    }

    async _loadWorkspace() {
        this.isLoading = true;
        this.errorMessage = null;
        try {
            markWorkspaceOpened({ caseId: this.recordId }).catch(() => {});
            this.caseData = await getCaseData({ caseId: this.recordId });
            this._initSlaCountdowns();
            this._startSlaTimer();
            this._loadInteractions();
            if (this.caseData && this.caseData.caseRecord && this.caseData.caseRecord.Subject) {
                this.knowledgeSearchTerm = this.caseData.caseRecord.Subject;
                this._runKnowledgeSearch();
            }
        } catch (err) {
            this.errorMessage = this._extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    async _loadInteractions() {
        this.isLoadingInteractions = true;
        try {
            const contactId = this.caseData && this.caseData.caseRecord
                ? this.caseData.caseRecord.ContactId : null;
            this.interactions = await getPreviousInteractions({
                caseId: this.recordId,
                contactId: contactId
            });
        } catch (err) {
            this.interactions = { emails: [], tasks: [], priorCases: [] };
        } finally {
            this.isLoadingInteractions = false;
        }
    }

    async _runKnowledgeSearch() {
        if (!this.knowledgeSearchTerm || this.knowledgeSearchTerm.trim().length < 2) {
            return;
        }
        this.isLoadingKnowledge = true;
        this.knowledgeError = null;
        this.knowledgeArticles = [];
        this._knowledgeSearched = true;
        try {
            const result = await searchKnowledge({ searchTerm: this.knowledgeSearchTerm });
            this.knowledgeArticles = result && result.articles ? result.articles : [];
            this.knowledgeError = result && result.errorMessage ? result.errorMessage : null;
        } catch (err) {
            this.knowledgeError = this._extractError(err);
        } finally {
            this.isLoadingKnowledge = false;
        }
    }

    _initSlaCountdowns() {
        if (!this.caseData || !this.caseData.milestones) { return; }
        this._slaCountdowns = this.caseData.milestones.map(m => this._buildMilestoneDisplay(m));
    }

    _buildMilestoneDisplay(milestone) {
        const now = Date.now();
        const target = milestone.TargetDate ? new Date(milestone.TargetDate).getTime() : null;
        const remainingMs = target ? target - now : null;
        const formatted = target ? new Date(milestone.TargetDate).toLocaleString() : 'No target date';
        let countdownDisplay = 'N/A';
        let countdownClass = 'slds-text-body_regular';
        if (remainingMs !== null && !milestone.IsCompleted) {
            if (remainingMs <= 0) {
                countdownDisplay = 'Overdue';
                countdownClass = 'slds-text-color_error slds-text-body_regular';
            } else {
                const hours = Math.floor(remainingMs / 3600000);
                const minutes = Math.floor((remainingMs % 3600000) / 60000);
                countdownDisplay = hours + 'h ' + minutes + 'm remaining';
                countdownClass = remainingMs < SLA_WARNING_THRESHOLD_MS
                    ? 'slds-text-color_error slds-text-body_regular'
                    : 'slds-text-color_success slds-text-body_regular';
            }
        } else if (milestone.IsCompleted) {
            countdownDisplay = 'Completed';
            countdownClass = 'slds-text-color_success slds-text-body_regular';
        }
        return { ...milestone, formattedTargetDate: formatted, countdownDisplay, countdownClass };
    }

    _startSlaTimer() {
        this._clearSlaTimer();
        this._slaTimerInterval = setInterval(() => {
            if (this.caseData && this.caseData.milestones) {
                this._slaCountdowns = this.caseData.milestones.map(m => this._buildMilestoneDisplay(m));
            }
        }, TIMER_INTERVAL_MS);
    }

    _clearSlaTimer() {
        if (this._slaTimerInterval) {
            clearInterval(this._slaTimerInterval);
            this._slaTimerInterval = null;
        }
    }

    _extractError(err) {
        if (err && err.body && err.body.message) { return err.body.message; }
        if (err && err.message) { return err.message; }
        return 'An unexpected error occurred. Please refresh.';
    }

    handleKnowledgeSearchChange(event) { this.knowledgeSearchTerm = event.target.value; }
    handleKnowledgeSearch() { this._runKnowledgeSearch(); }

    get isReady() { return !this.isLoading && !this.hasError && this.caseData !== null; }
    get hasError() { return !!this.errorMessage; }
    get hasMilestones() { return this._slaCountdowns && this._slaCountdowns.length > 0; }
    get hasNoMilestones() { return !this.hasMilestones; }
    get slaCountdowns() { return this._slaCountdowns; }
    get hasRecommendations() {
        return this.caseData && this.caseData.recommendations && this.caseData.recommendations.length > 0;
    }
    get hasNoRecommendations() { return !this.hasRecommendations; }
    get hasEmails() { return this.interactions && this.interactions.emails && this.interactions.emails.length > 0; }
    get hasTasks() { return this.interactions && this.interactions.tasks && this.interactions.tasks.length > 0; }
    get hasPriorCases() {
        return this.interactions && this.interactions.priorCases && this.interactions.priorCases.length > 0;
    }
    get hasNoInteractions() {
        return !this.isLoadingInteractions && this.interactions !== null
            && !this.hasEmails && !this.hasTasks && !this.hasPriorCases;
    }
    get emailCount() { return this.interactions && this.interactions.emails ? this.interactions.emails.length : 0; }
    get taskCount() { return this.interactions && this.interactions.tasks ? this.interactions.tasks.length : 0; }
    get priorCaseCount() {
        return this.interactions && this.interactions.priorCases ? this.interactions.priorCases.length : 0;
    }
    get hasKnowledgeArticles() { return this.knowledgeArticles && this.knowledgeArticles.length > 0; }
    get showNoArticlesMessage() {
        return this._knowledgeSearched && !this.isLoadingKnowledge
            && !this.hasKnowledgeArticles && !this.knowledgeError;
    }
    get hasNoCustomer() {
        return this.caseData && !this.caseData.accountRecord && !this.caseData.contactRecord;
    }
    get contactEmailLink() {
        if (this.caseData && this.caseData.contactRecord && this.caseData.contactRecord.Email) {
            return 'mailto:' + this.caseData.contactRecord.Email;
        }
        return '#';
    }
}