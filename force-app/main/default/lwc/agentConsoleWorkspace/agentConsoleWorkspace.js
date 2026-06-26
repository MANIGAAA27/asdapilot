/**
 * @file              agentConsoleWorkspace.js
 * @description       Controller for the Agent Console Workspace LWC. Aggregates
 *                    case details, customer profile, interactions, knowledge articles,
 *                    AI recommendations, and SLA milestone data into a unified view.
 *                    Uses imperative Apex calls for initial data load and a client-side
 *                    interval timer for the SLA countdown.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-26
 * @lastModified      2026-06-26
 * @group             AgentConsoleWorkspace
 * @see               LLD-AgentConsoleWorkspace (Project: Agent Console Workspace)
 */

// MODIFIED 2026-06-26 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
import { LightningElement, api, track } from 'lwc';
import getWorkspaceData       from '@salesforce/apex/AgentConsoleWorkspaceService.getWorkspaceData';
import getRelatedActivities   from '@salesforce/apex/AgentConsoleWorkspaceService.getRelatedActivities';
import getRelatedEmailMessages from '@salesforce/apex/AgentConsoleWorkspaceService.getRelatedEmailMessages';
import getPreviousCases       from '@salesforce/apex/AgentConsoleWorkspaceService.getPreviousCases';
import getKnowledgeArticles   from '@salesforce/apex/AgentConsoleWorkspaceService.getKnowledgeArticles';
import getAIRecommendations   from '@salesforce/apex/AgentConsoleWorkspaceService.getAIRecommendations';
import getCaseMilestones      from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseMilestones';
import markWorkspaceUsed      from '@salesforce/apex/AgentConsoleWorkspaceService.markWorkspaceUsed';

/** Number of milliseconds between SLA timer refreshes (60 s). */
const TIMER_INTERVAL_MS = 60000;

/** Hours remaining thresholds for SLA colour coding. */
const CRITICAL_HOURS = 2;
const WARNING_HOURS  = 8;

export default class AgentConsoleWorkspace extends LightningElement {

    /** Record Id injected by the Lightning record page. */
    @api recordId;

    // ── Reactive state ─────────────────────────────────────────────────────

    @track isLoading           = true;
    @track errorMessage        = null;

    @track caseRecord          = null;
    @track accountRecord       = null;
    @track contactRecord       = null;

    @track activities          = [];
    @track emailMessages       = [];
    @track priorCases          = [];
    @track knowledgeArticles   = [];
    @track recommendations     = [];
    @track milestones          = [];

    @track knowledgeSearchTerm = '';
    @track slaCountdown        = '';
    @track slaTimerClass       = 'sla-timer sla-ok';
    @track activeMilestoneName = '';
    @track activeMilestoneTarget = '';

    // ── Private fields ──────────────────────────────────────────────────────

    _timerRef = null;

    // ── Lifecycle ───────────────────────────────────────────────────────────

    connectedCallback() {
        this._loadAllData();
    }

    disconnectedCallback() {
        this._clearTimer();
    }

    // ── Public computed getters ─────────────────────────────────────────────

    get hasTasks()             { return this.activities.length > 0; }
    get hasEmails()            { return this.emailMessages.length > 0; }
    get hasPriorCases()        { return this.priorCases.length > 0; }
    get hasKnowledgeArticles() { return this.knowledgeArticles.length > 0; }
    get hasRecommendations()   { return this.recommendations.length > 0; }
    get hasMilestone()         { return this.activeMilestoneName !== ''; }

    // ── Private helpers ─────────────────────────────────────────────────────

    /**
     * Orchestrates all Apex calls in parallel using Promise.all for fast initial load.
     * Imperative calls are used so that markWorkspaceUsed (non-cacheable) can also run.
     */
    async _loadAllData() {
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }
        this.isLoading = true;
        this.errorMessage = null;

        try {
            // Fire all read calls in parallel
            const [wd, tasks, emails, priorCasesResult, recs, milestoneList] =
                await Promise.all([
                    getWorkspaceData({ caseId: this.recordId }),
                    getRelatedActivities({ caseId: this.recordId }),
                    getRelatedEmailMessages({ caseId: this.recordId }),
                    getPreviousCases({ caseId: this.recordId }),
                    getAIRecommendations({ caseId: this.recordId }),
                    getCaseMilestones({ caseId: this.recordId })
                ]);

            this.caseRecord    = wd.caseRecord;
            this.accountRecord = wd.accountRecord;
            this.contactRecord = wd.contactRecord;
            this.activities    = tasks;
            this.emailMessages = emails;
            this.priorCases    = priorCasesResult;
            this.recommendations = recs;
            this.milestones    = milestoneList;

            this._initSlaTimer();
            this._markUsed();
        } catch (err) {
            this.errorMessage = this._extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    /** Stamps workspace-usage fields on the Case (fire-and-forget). */
    async _markUsed() {
        try {
            await markWorkspaceUsed({ caseId: this.recordId });
        } catch (err) {
            // Non-blocking — log to console but do not surface to user
            console.error('AgentConsoleWorkspace: markWorkspaceUsed failed', err);
        }
    }

    /**
     * Sets up the SLA countdown timer. Finds the earliest incomplete milestone
     * and starts a 60-second interval to refresh the displayed countdown.
     */
    _initSlaTimer() {
        this._clearTimer();
        this._updateSlaDisplay();
        this._timerRef = setInterval(() => {
            this._updateSlaDisplay();
        }, TIMER_INTERVAL_MS);
    }

    /** Recalculates the countdown string and colour class from current milestones. */
    _updateSlaDisplay() {
        const active = this.milestones.find(m => !m.IsCompleted && !m.IsViolated);
        if (!active) {
            this.activeMilestoneName   = '';
            this.activeMilestoneTarget = '';
            this.slaCountdown          = '';
            this.slaTimerClass         = 'sla-timer sla-ok';
            return;
        }

        this.activeMilestoneName   = active.MilestoneType ? active.MilestoneType.Name : 'Milestone';
        this.activeMilestoneTarget = active.TargetDate ? new Date(active.TargetDate).toLocaleString() : '';

        const now           = Date.now();
        const targetMs      = new Date(active.TargetDate).getTime();
        const remainingMs   = targetMs - now;

        if (remainingMs <= 0) {
            this.slaCountdown  = 'BREACHED';
            this.slaTimerClass = 'sla-timer sla-critical';
            return;
        }

        const totalMinutes  = Math.floor(remainingMs / 60000);
        const hours         = Math.floor(totalMinutes / 60);
        const minutes       = totalMinutes % 60;
        this.slaCountdown   = `${hours}h ${minutes}m`;

        if (hours < CRITICAL_HOURS) {
            this.slaTimerClass = 'sla-timer sla-critical';
        } else if (hours < WARNING_HOURS) {
            this.slaTimerClass = 'sla-timer sla-warning';
        } else {
            this.slaTimerClass = 'sla-timer sla-ok';
        }
    }

    /** Cancels the running interval timer. */
    _clearTimer() {
        if (this._timerRef) {
            clearInterval(this._timerRef);
            this._timerRef = null;
        }
    }

    /** Extracts a human-readable error string from various error shapes. */
    _extractError(err) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        if (err && err.message) {
            return err.message;
        }
        return 'An unexpected error occurred. Please refresh the page.';
    }

    // ── Event handlers ──────────────────────────────────────────────────────

    /** Two-way binds the knowledge search input. */
    handleKnowledgeSearch(event) {
        this.knowledgeSearchTerm = event.target.value;
    }

    /** Executes the knowledge article search against the Apex service. */
    async searchKnowledge() {
        if (!this.knowledgeSearchTerm || this.knowledgeSearchTerm.trim() === '') {
            return;
        }
        try {
            this.knowledgeArticles = await getKnowledgeArticles({
                searchTerm: this.knowledgeSearchTerm
            });
        } catch (err) {
            this.errorMessage = this._extractError(err);
        }
    }

    /**
     * Placeholder for the Apply Recommendation action.
     * In a production implementation this would call an Apex method to mark
     * Is_Applied__c = true and log the selection for analytics.
     */
    handleApplyRecommendation(event) {
        const recId = event.currentTarget.dataset.recId;
        this.recommendations = this.recommendations.map(rec => {
            if (rec.Id === recId) {
                return Object.assign({}, rec, { Is_Applied__c: true });
            }
            return rec;
        });
    }
}