/**
 * @file        agentConsoleWorkspace.js
 * @description Agent Console Workspace LWC — consolidates Case, customer profile,
 *              interaction history, knowledge articles, AI recommendations, and
 *              SLA countdown timer into a single unified view for Service Managers
 *              and Support Agents.
 *
 *              Imperative Apex calls allow controlled load sequencing:
 *              1. getCaseDetails     — case header + customer profile
 *              2. getCaseMilestones  — SLA countdown data
 *              3. getRecentInteractions — email/comment/task/prior-case history
 *              4. getCaseRecommendations — AI guidance panel
 *
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-25
 * @see         AgentConsoleWorkspaceService.cls
 */

// MODIFIED 2026-06-25 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
import { LightningElement, api, track } from 'lwc';
import getCaseDetails from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseDetails';
import getRecentInteractions from '@salesforce/apex/AgentConsoleWorkspaceService.getRecentInteractions';
import getCaseMilestones from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseMilestones';
import getCaseRecommendations from '@salesforce/apex/AgentConsoleWorkspaceService.getCaseRecommendations';
import searchKnowledgeArticles from '@salesforce/apex/AgentConsoleWorkspaceService.searchKnowledgeArticles';
import trackWorkspaceOpened from '@salesforce/apex/AgentConsoleWorkspaceService.trackWorkspaceOpened';

/** Warning threshold in milliseconds (4 hours). */
const WARNING_THRESHOLD_MS = 4 * 60 * 60 * 1000;
/** Critical threshold in milliseconds (2 hours). */
const CRITICAL_THRESHOLD_MS = 2 * 60 * 60 * 1000;
/** SLA timer refresh interval in milliseconds (60 seconds). */
const TIMER_INTERVAL_MS = 60000;

export default class AgentConsoleWorkspace extends LightningElement {
    /** Case record Id injected by the Lightning record page. */
    @api recordId;

    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';
    @track isReady = false;

    @track caseData = null;
    @track interactions = null;
    @track recommendations = [];
    @track milestones = [];

    @track slaRemaining = null;
    @track slaTimerClass = 'sla-banner slds-box slds-m-bottom_small slds-theme_shade';

    @track knowledgeSearchTerm = '';
    @track knowledgeArticles = [];
    @track isSearchingKnowledge = false;
    @track knowledgeSearchDone = false;

    _timerInterval = null;

    // ── Computed properties ────────────────────────────────────────────────

    get hasEmails() {
        return this.interactions && this.interactions.emails && this.interactions.emails.length > 0;
    }

    get hasComments() {
        return this.interactions && this.interactions.comments && this.interactions.comments.length > 0;
    }

    get hasPriorCases() {
        return this.interactions && this.interactions.priorCases && this.interactions.priorCases.length > 0;
    }

    get hasRecommendations() {
        return this.recommendations && this.recommendations.length > 0;
    }

    get hasKnowledgeArticles() {
        return this.knowledgeArticles && this.knowledgeArticles.length > 0;
    }

    get contactEmailHref() {
        if (this.caseData && this.caseData.contactRecord && this.caseData.contactRecord.Email) {
            return 'mailto:' + this.caseData.contactRecord.Email;
        }
        return '#';
    }

    // ── Lifecycle hooks ────────────────────────────────────────────────────

    connectedCallback() {
        if (this.recordId) {
            this._loadWorkspace();
        }
    }

    disconnectedCallback() {
        this._clearSlaTimer();
    }

    // ── Private load orchestration ─────────────────────────────────────────

    async _loadWorkspace() {
        this.isLoading = true;
        this.hasError = false;
        try {
            // 1. Load core case details (drives subsequent queries)
            this.caseData = await getCaseDetails({ caseId: this.recordId });

            const contactId = this.caseData.caseRecord ? this.caseData.caseRecord.ContactId : null;

            // 2-4. Load remaining panels in parallel for performance
            const [milestones, interactionData, recs] = await Promise.all([
                getCaseMilestones({ caseId: this.recordId }),
                getRecentInteractions({ caseId: this.recordId, contactId: contactId }),
                getCaseRecommendations({ caseId: this.recordId })
            ]);

            this.milestones = milestones || [];
            this.interactions = interactionData;
            this.recommendations = recs || [];

            // 5. Start SLA countdown timer
            this._startSlaTimer();

            // 6. Track workspace opened (fire-and-forget; failure is non-fatal)
            trackWorkspaceOpened({ caseId: this.recordId }).catch(() => {
                // Tracking failure is non-blocking — workspace continues to function.
            });

            // 7. Pre-populate knowledge search from case subject
            if (this.caseData.caseRecord && this.caseData.caseRecord.Subject) {
                this.knowledgeSearchTerm = this.caseData.caseRecord.Subject;
            }

            this.isReady = true;
        } catch (err) {
            this.hasError = true;
            this.errorMessage = this._extractErrorMessage(err);
        } finally {
            this.isLoading = false;
        }
    }

    // ── SLA countdown timer ────────────────────────────────────────────────

    _startSlaTimer() {
        this._clearSlaTimer();
        this._calculateSlaRemaining();
        this._timerInterval = setInterval(() => {
            this._calculateSlaRemaining();
        }, TIMER_INTERVAL_MS);
    }

    _clearSlaTimer() {
        if (this._timerInterval) {
            clearInterval(this._timerInterval);
            this._timerInterval = null;
        }
    }

    _calculateSlaRemaining() {
        if (!this.milestones || this.milestones.length === 0) {
            this.slaRemaining = null;
            this.slaTimerClass = 'sla-banner slds-box slds-m-bottom_small slds-theme_shade';
            return;
        }

        // Find the first active (not completed) milestone
        const activeMilestone = this.milestones.find(m => !m.IsCompleted);
        if (!activeMilestone || !activeMilestone.TargetDate) {
            this.slaRemaining = null;
            this.slaTimerClass = 'sla-banner slds-box slds-m-bottom_small slds-theme_shade';
            return;
        }

        const now = Date.now();
        const target = new Date(activeMilestone.TargetDate).getTime();
        const diffMs = target - now;

        if (diffMs <= 0) {
            this.slaRemaining = 'SLA Breached';
            this.slaTimerClass = 'sla-banner slds-box slds-m-bottom_small slds-theme_error';
        } else {
            const hours = Math.floor(diffMs / (1000 * 60 * 60));
            const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
            this.slaRemaining = hours + 'h ' + minutes + 'm remaining — ' + (activeMilestone.MilestoneType ? activeMilestone.MilestoneType.Name : '');

            if (diffMs < CRITICAL_THRESHOLD_MS) {
                this.slaTimerClass = 'sla-banner slds-box slds-m-bottom_small slds-theme_error';
            } else if (diffMs < WARNING_THRESHOLD_MS) {
                this.slaTimerClass = 'sla-banner slds-box slds-m-bottom_small slds-theme_warning';
            } else {
                this.slaTimerClass = 'sla-banner slds-box slds-m-bottom_small slds-theme_success';
            }
        }
    }

    // ── Knowledge article search ───────────────────────────────────────────

    handleKnowledgeSearchChange(event) {
        this.knowledgeSearchTerm = event.target.value;
    }

    async handleKnowledgeSearch() {
        if (!this.knowledgeSearchTerm || !this.knowledgeSearchTerm.trim()) {
            return;
        }
        this.isSearchingKnowledge = true;
        this.knowledgeSearchDone = false;
        this.knowledgeArticles = [];
        try {
            const results = await searchKnowledgeArticles({ searchTerm: this.knowledgeSearchTerm.trim() });
            this.knowledgeArticles = results || [];
        } catch (err) {
            this.knowledgeArticles = [];
        } finally {
            this.isSearchingKnowledge = false;
            this.knowledgeSearchDone = true;
        }
    }

    // ── Error handling ─────────────────────────────────────────────────────

    /** Extracts a human-readable message from LWC/Apex error shapes. */
    _extractErrorMessage(err) {
        if (!err) {
            return 'An unexpected error occurred while loading the workspace.';
        }
        if (typeof err === 'string') {
            return err;
        }
        if (err.body && err.body.message) {
            return err.body.message;
        }
        if (err.message) {
            return err.message;
        }
        return 'An unexpected error occurred while loading the workspace.';
    }
}