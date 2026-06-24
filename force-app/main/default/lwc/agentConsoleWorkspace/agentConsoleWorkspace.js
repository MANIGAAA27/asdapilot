/**
 * @file        agentConsoleWorkspace.js
 * @description Controller for the Agent Console Workspace LWC. Provides a unified
 *              case-handling view: case context, customer profile, SLA milestones,
 *              AI recommendations, knowledge articles, and prior interactions.
 * @project     Agent Console Workspace
 * @lld         LLD-AgentConsoleWorkspace
 */
// MODIFIED 2026-06-24 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
import { LightningElement, api, track } from 'lwc';
import getCaseContext from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseContext';
import getInteractions from '@salesforce/apex/AgentConsoleWorkspaceService.getInteractions';
import searchKnowledge from '@salesforce/apex/AgentConsoleWorkspaceService.searchKnowledge';
import markWorkspaceUsed from '@salesforce/apex/AgentConsoleWorkspaceService.markWorkspaceUsed';

const SLA_REFRESH_INTERVAL_MS = 60000;

export default class AgentConsoleWorkspace extends LightningElement {

    @api recordId;

    @track caseContext = null;
    @track interactions = null;
    @track knowledgeArticles = [];

    @track isLoading = true;
    @track isInteractionsLoading = true;
    @track isKnowledgeLoading = true;

    @track contextError = false;
    @track contextErrorMessage = '';

    _slaInterval = null;

    connectedCallback() {
        this._loadCaseContext();
    }

    disconnectedCallback() {
        if (this._slaInterval) {
            clearInterval(this._slaInterval);
        }
    }

    async _loadCaseContext() {
        if (!this.recordId) {
            this.isLoading = false;
            this.contextError = true;
            this.contextErrorMessage = 'No Case Id available. Place this component on a Case record page.';
            return;
        }
        try {
            this.isLoading = true;
            this.contextError = false;
            const context = await getCaseContext({ caseId: this.recordId });
            this.caseContext = context;
            this._markUsage();
            this._slaInterval = setInterval(() => { this._refreshSla(); }, SLA_REFRESH_INTERVAL_MS);
            this._loadInteractions(context);
            this._loadKnowledge(context);
        } catch (err) {
            this.contextError = true;
            this.contextErrorMessage = this._extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    async _loadInteractions(context) {
        this.isInteractionsLoading = true;
        try {
            const contactId = context && context.caseRecord && context.caseRecord.ContactId
                ? context.caseRecord.ContactId : null;
            this.interactions = await getInteractions({ caseId: this.recordId, contactId: contactId });
        } catch (err) {
            console.error('[AgentConsoleWorkspace] Interactions load error:', this._extractError(err));
        } finally {
            this.isInteractionsLoading = false;
        }
    }

    async _loadKnowledge(context) {
        this.isKnowledgeLoading = true;
        try {
            const subject = context && context.caseRecord && context.caseRecord.Subject
                ? context.caseRecord.Subject : '';
            this.knowledgeArticles = subject
                ? await searchKnowledge({ searchTerm: subject })
                : [];
        } catch (err) {
            console.error('[AgentConsoleWorkspace] Knowledge search error:', this._extractError(err));
            this.knowledgeArticles = [];
        } finally {
            this.isKnowledgeLoading = false;
        }
    }

    async _markUsage() {
        try {
            await markWorkspaceUsed({ caseId: this.recordId });
        } catch (err) {
            console.warn('[AgentConsoleWorkspace] markWorkspaceUsed error:', this._extractError(err));
        }
    }

    _refreshSla() {
        // SLA TargetDate is in caseContext.milestones — future enhancement: render live countdown
    }

    handleKnowledgeRefresh() {
        if (this.caseContext) {
            this._loadKnowledge(this.caseContext);
        }
    }

    get caseHeaderTitle() {
        return this.caseContext && this.caseContext.caseRecord
            ? 'Case ' + this.caseContext.caseRecord.CaseNumber
            : 'Agent Console Workspace';
    }

    get hasMilestones() {
        return this.caseContext && this.caseContext.milestones && this.caseContext.milestones.length > 0;
    }

    get hasRecommendations() {
        return this.caseContext && this.caseContext.recommendations && this.caseContext.recommendations.length > 0;
    }

    get hasKnowledgeArticles() {
        return this.knowledgeArticles && this.knowledgeArticles.length > 0;
    }

    get hasPriorCases() {
        return this.interactions && this.interactions.priorCases && this.interactions.priorCases.length > 0;
    }

    get hasEmails() {
        return this.interactions && this.interactions.emails && this.interactions.emails.length > 0;
    }

    get hasAnyInteractions() {
        return this.hasPriorCases || this.hasEmails;
    }

    _extractError(err) {
        if (!err) { return 'Unknown error.'; }
        if (err.body && err.body.message) { return err.body.message; }
        if (err.message) { return err.message; }
        return String(err);
    }
}