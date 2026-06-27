/**
 * @file              agentConsoleWorkspace.js
 * @description       Controller for the Agent Console Workspace LWC.
 *                    Loads case/account/contact/milestones/recommendations on
 *                    connectedCallback, lazy-loads interactions on demand,
 *                    debounces knowledge article search, and runs a 60-second
 *                    SLA countdown timer configured from SLA_Config__mdt.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-27
 * @project           Agent Console Workspace
 * @see               LLD-AgentConsoleWorkspace | AgentConsoleWorkspaceService.cls
 */
import { LightningElement, api, track } from 'lwc';
import getCaseWorkspaceData    from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseWorkspaceData';
import getPreviousInteractions from '@salesforce/apex/AgentConsoleWorkspaceService.getPreviousInteractions';
import searchKnowledgeArticles from '@salesforce/apex/AgentConsoleWorkspaceService.searchKnowledgeArticles';
import getSlaConfig            from '@salesforce/apex/AgentConsoleWorkspaceService.getSlaConfig';
import markWorkspaceOpened     from '@salesforce/apex/AgentConsoleWorkspaceService.markWorkspaceOpened';

const DEFAULT_WARN_HOURS     = 2;
const DEFAULT_CRIT_HOURS     = 1;
const TIMER_INTERVAL_MS      = 60000;
const SEARCH_DEBOUNCE_MS     = 500;

export default class AgentConsoleWorkspace extends LightningElement {

    @api recordId;

    @track workspaceData      = null;
    @track workspaceError     = null;
    @track isLoading          = false;

    @track interactionData    = null;
    @track interactionsLoaded = false;
    @track isLoadingInteractions = false;

    @track knowledgeArticles  = [];
    @track knowledgeSearchTerm = '';
    @track knowledgeSearched  = false;
    @track isLoadingKnowledge = false;

    @track slaCountdown   = '';
    @track slaTimerClass  = 'sla-timer sla-ok';

    _slaTimerHandle  = null;
    _slaTargetDate   = null;
    _warnMs          = DEFAULT_WARN_HOURS * 3600000;
    _critMs          = DEFAULT_CRIT_HOURS * 3600000;
    _searchDebounce  = null;

    // ── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        if (this.recordId) {
            this._loadWorkspace();
        }
    }

    disconnectedCallback() {
        this._clearTimer();
    }

    // ── Data loading ─────────────────────────────────────────────────────────

    async _loadWorkspace() {
        this.isLoading = true;
        this.workspaceError = null;
        try {
            const slaConfig = await getSlaConfig();
            if (slaConfig) {
                this._warnMs = (slaConfig.Warning_Threshold_Hours__c  || DEFAULT_WARN_HOURS) * 3600000;
                this._critMs = (slaConfig.Critical_Threshold_Hours__c || DEFAULT_CRIT_HOURS) * 3600000;
            }

            const data = await getCaseWorkspaceData({ caseId: this.recordId });
            this.workspaceData = data;

            if (data.milestones && data.milestones.length > 0) {
                this._slaTargetDate = new Date(data.milestones[0].TargetDate);
                this._updateSlaTimer();
                this._startSlaTimer();
            }

            markWorkspaceOpened({ caseId: this.recordId }).catch((err) => {
                console.warn('agentConsoleWorkspace: markWorkspaceOpened failed', err);
            });
        } catch (err) {
            this.workspaceError = this._extractErrorMessage(err);
        } finally {
            this.isLoading = false;
        }
    }

    async handleLoadInteractions() {
        if (!this.workspaceData) { return; }
        this.isLoadingInteractions = true;
        try {
            const contactId = this.workspaceData.caseRecord ? this.workspaceData.caseRecord.ContactId : null;
            const accountId = this.workspaceData.caseRecord ? this.workspaceData.caseRecord.AccountId : null;
            const data = await getPreviousInteractions({
                caseId: this.recordId,
                contactId: contactId,
                accountId: accountId
            });
            this.interactionData    = data;
            this.interactionsLoaded = true;
        } catch (err) {
            this.workspaceError = this._extractErrorMessage(err);
        } finally {
            this.isLoadingInteractions = false;
        }
    }

    handleKnowledgeSearch(event) {
        const term = event.target.value;
        this.knowledgeSearchTerm = term;
        if (this._searchDebounce) { clearTimeout(this._searchDebounce); }
        if (!term || term.trim().length === 0) {
            this.knowledgeArticles   = [];
            this.knowledgeSearched   = false;
            return;
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchDebounce = setTimeout(() => { this._doKnowledgeSearch(term.trim()); }, SEARCH_DEBOUNCE_MS);
    }

    async _doKnowledgeSearch(term) {
        this.isLoadingKnowledge = true;
        try {
            const results = await searchKnowledgeArticles({ searchTerm: term });
            this.knowledgeArticles = results || [];
            this.knowledgeSearched = true;
        } catch (err) {
            this.knowledgeArticles = [];
            this.knowledgeSearched = true;
        } finally {
            this.isLoadingKnowledge = false;
        }
    }

    // ── SLA Timer ────────────────────────────────────────────────────────────

    _startSlaTimer() {
        this._clearTimer();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._slaTimerHandle = setInterval(() => { this._updateSlaTimer(); }, TIMER_INTERVAL_MS);
    }

    _clearTimer() {
        if (this._slaTimerHandle) {
            clearInterval(this._slaTimerHandle);
            this._slaTimerHandle = null;
        }
    }

    _updateSlaTimer() {
        if (!this._slaTargetDate) { return; }
        const remainingMs = this._slaTargetDate.getTime() - Date.now();
        if (remainingMs <= 0) {
            this.slaCountdown  = 'SLA BREACHED';
            this.slaTimerClass = 'sla-timer sla-critical';
            this._clearTimer();
            return;
        }
        const totalMin = Math.floor(remainingMs / 60000);
        const hrs      = Math.floor(totalMin / 60);
        const mins     = totalMin % 60;
        this.slaCountdown  = hrs > 0 ? `${hrs}h ${mins}m remaining` : `${mins}m remaining`;
        this.slaTimerClass = remainingMs <= this._critMs ? 'sla-timer sla-critical'
                           : remainingMs <= this._warnMs ? 'sla-timer sla-warning'
                           :                               'sla-timer sla-ok';
    }

    // ── Computed properties ───────────────────────────────────────────────────

    get caseNumber()      { return this.workspaceData?.caseRecord?.CaseNumber    || ''; }
    get caseSubject()     { return this.workspaceData?.caseRecord?.Subject        || ''; }
    get caseStatus()      { return this.workspaceData?.caseRecord?.Status         || ''; }
    get casePriority()    { return this.workspaceData?.caseRecord?.Priority       || ''; }
    get caseOrigin()      { return this.workspaceData?.caseRecord?.Origin         || ''; }
    get caseCreatedDate() { return this.workspaceData?.caseRecord?.CreatedDate    || null; }
    get caseDescription() { return this.workspaceData?.caseRecord?.Description   || ''; }

    get hasMilestone()     { return !!(this.workspaceData?.milestones?.length > 0); }
    get hasCustomerContext(){ return !!(this.workspaceData?.accountRecord || this.workspaceData?.contactRecord); }
    get hasRecommendations(){ return !!(this.workspaceData?.recommendations?.length > 0); }

    get contactEmailLink() {
        const email = this.workspaceData?.contactRecord?.Email;
        return email ? 'mailto:' + email : '#';
    }

    get hasEmails()       { return !!(this.interactionData?.emails?.length > 0); }
    get hasTasks()        { return !!(this.interactionData?.tasks?.length > 0); }
    get hasRelatedCases() { return !!(this.interactionData?.relatedCases?.length > 0); }

    get emailTabLabel()       { return `Emails (${this.interactionData?.emails?.length || 0})`; }
    get taskTabLabel()        { return `Tasks (${this.interactionData?.tasks?.length || 0})`; }
    get relatedCasesTabLabel(){ return `Prior Cases (${this.interactionData?.relatedCases?.length || 0})`; }

    get hasKnowledgeResults() { return !!(this.knowledgeArticles?.length > 0); }

    // ── Utility ──────────────────────────────────────────────────────────────

    _extractErrorMessage(err) {
        if (!err)                       { return 'An unknown error occurred.'; }
        if (typeof err === 'string')    { return err; }
        if (err.body?.message)          { return err.body.message; }
        if (err.message)                { return err.message; }
        return 'An unexpected error occurred loading the workspace.';
    }
}
