import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getRecentJobs from '@salesforce/apex/ARM_MigrationScheduler.getRecentJobs';
import startMigration from '@salesforce/apex/ARM_MigrationScheduler.startMigration';
import getJobStatus from '@salesforce/apex/ARM_MigrationScheduler.getJobStatus';

const COLUMNS = [
    { label: 'Job #', fieldName: 'Name', type: 'text', sortable: true },
    { label: 'Migration Name', fieldName: 'MigrationName__c', type: 'text', sortable: true },
    {
        label: 'Status',
        fieldName: 'MigrationStatus__c',
        type: 'text',
        sortable: true,
        cellAttributes: { iconName: { fieldName: 'statusIcon' } }
    },
    { label: 'Start Date', fieldName: 'StartDate__c', type: 'date', sortable: true,
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    { label: 'End Date', fieldName: 'EndDate__c', type: 'date', sortable: true,
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View Details', name: 'view' },
                { label: 'Start Migration', name: 'start' }
            ]
        }
    }
];

const TERMINAL_STATUSES = new Set(['Completed', 'Failed', 'Rollback Complete']);
const RUNNING_STATUSES = new Set(['Executing', 'Snapshotting', 'Validating', 'Comparing', 'Post-Processing', 'Rolling Back']);

/**
 * JobTrackerComponent — monitors migration job progress with real-time status updates.
 *
 * Displays a paginated list of ARMT_MigrationJob__c records with inline action
 * buttons to view job details and trigger migration execution via ARM_MigrationScheduler.
 */
export default class JobTrackerComponent extends LightningElement {

    @track isLoading = false;
    @track error;
    @track selectedJob;
    @track filterValue = '';
    @track jobs = [];

    _wiredJobsResult;
    _pollingInterval;

    columns = COLUMNS;

    // ─── Wire ────────────────────────────────────────────────────────────────

    @wire(getRecentJobs, { recordLimit: 50 })
    wiredJobs(result) {
        this._wiredJobsResult = result;
        if (result.data) {
            this.jobs = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = this._extractError(result.error);
            this.jobs = [];
        }
    }

    // ─── Getters ─────────────────────────────────────────────────────────────

    get hasJobs() {
        return this.filteredJobs && this.filteredJobs.length > 0;
    }

    get filteredJobs() {
        if (!this.filterValue) {
            return this.jobs;
        }
        const lowerFilter = this.filterValue.toLowerCase();
        return this.jobs.filter(job =>
            (job.Name && job.Name.toLowerCase().includes(lowerFilter)) ||
            (job.MigrationName__c && job.MigrationName__c.toLowerCase().includes(lowerFilter)) ||
            (job.MigrationStatus__c && job.MigrationStatus__c.toLowerCase().includes(lowerFilter))
        );
    }

    get isMigrationRunning() {
        if (!this.selectedJob) return false;
        return RUNNING_STATUSES.has(this.selectedJob.MigrationStatus__c);
    }

    get statusBadgeClass() {
        if (!this.selectedJob) return '';
        const status = this.selectedJob.MigrationStatus__c;
        if (status === 'Completed') return 'slds-theme_success';
        if (status === 'Failed') return 'slds-theme_error';
        if (RUNNING_STATUSES.has(status)) return 'slds-theme_info';
        return '';
    }

    // ─── Handlers ────────────────────────────────────────────────────────────

    handleFilterChange(event) {
        this.filterValue = event.target.value;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredJobsResult).finally(() => {
            this.isLoading = false;
        });
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view') {
            this.selectedJob = row;
            this._startPolling(row.Id);
        } else if (actionName === 'start') {
            this._triggerMigration(row.Id);
        }
    }

    handleStartMigration() {
        if (this.selectedJob) {
            this._triggerMigration(this.selectedJob.Id);
        }
    }

    handleCloseDetail() {
        this._stopPolling();
        this.selectedJob = undefined;
    }

    // ─── Private ─────────────────────────────────────────────────────────────

    _triggerMigration(jobId) {
        this.isLoading = true;
        startMigration({ jobId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Migration Started',
                    message: 'The migration batch job has been enqueued.',
                    variant: 'success'
                }));
                return refreshApex(this._wiredJobsResult);
            })
            .catch(err => {
                this.error = this._extractError(err);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Migration Failed',
                    message: this.error,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    _startPolling(jobId) {
        this._stopPolling();
        this._pollingInterval = setInterval(() => {
            getJobStatus({ jobId })
                .then(result => {
                    this.selectedJob = result;
                    if (TERMINAL_STATUSES.has(result.MigrationStatus__c)) {
                        this._stopPolling();
                        refreshApex(this._wiredJobsResult);
                    }
                })
                .catch(() => {
                    this._stopPolling();
                });
        }, 5000);
    }

    _stopPolling() {
        if (this._pollingInterval) {
            clearInterval(this._pollingInterval);
            this._pollingInterval = undefined;
        }
    }

    _extractError(err) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        if (err && err.message) {
            return err.message;
        }
        return 'An unexpected error occurred.';
    }

    disconnectedCallback() {
        this._stopPolling();
    }
}
