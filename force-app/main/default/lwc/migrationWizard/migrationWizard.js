/**
 * @file        migrationWizard.js
 * @description Top-level LWC for the wizard-driven CPQ-to-ARM migration interface.
 *              Manages a three-step wizard: configure → validate → initiate.
 *              Delegates all business logic to Apex controllers (MigrationValidator,
 *              MigrationProcessHandler); the component is purely presentational.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-23
 */

// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import validateConfiguration from '@salesforce/apex/MigrationValidator.validateConfiguration';
import getObjectMappings from '@salesforce/apex/MigrationValidator.getObjectMappings';
import startMigrationAsync from '@salesforce/apex/MigrationProcessHandler.startMigrationAsync';

const MAPPING_COLUMNS = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Source Object', fieldName: 'Source_Object__c' },
    { label: 'Target Object', fieldName: 'Target_Object__c' }
];

export default class MigrationWizard extends LightningElement {
    /** Current wizard step: 1 = Configure, 2 = Validate results, 3 = Initiated. */
    @track currentStep = 1;

    /** User-entered source CPQ object API name. */
    @track sourceObject = '';

    /** User-entered target ARM object API name. */
    @track targetObject = '';

    /** True when validation returned isValid = true. */
    @track validationSuccess = false;

    /** Error messages returned by MigrationValidator. */
    @track validationErrors = [];

    /** Warning messages returned by MigrationValidator. */
    @track validationWarnings = [];

    /** Audit record ID returned by MigrationProcessHandler.startMigrationAsync. */
    @track auditRecordId = '';

    /** Controls spinner visibility during async calls. */
    @track isLoading = false;

    /** List of ARM_Object_Mapping__c records for the mappings table. */
    @track objectMappings = [];

    /** Column definitions for the mappings datatable. */
    mappingColumns = MAPPING_COLUMNS;

    // -------------------------------------------------------------------------
    // Wire: load existing object mappings on component init
    // -------------------------------------------------------------------------

    @wire(getObjectMappings)
    wiredMappings({ data, error }) {
        if (data) {
            this.objectMappings = data;
        } else if (error) {
            // Non-fatal: table remains empty if user lacks access
            this.objectMappings = [];
        }
    }

    // -------------------------------------------------------------------------
    // Computed properties for template visibility
    // -------------------------------------------------------------------------

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get hasMappings() { return this.objectMappings && this.objectMappings.length > 0; }
    get hasWarnings() { return this.validationWarnings && this.validationWarnings.length > 0; }

    // -------------------------------------------------------------------------
    // Event handlers
    // -------------------------------------------------------------------------

    handleSourceChange(event) {
        this.sourceObject = event.target.value;
    }

    handleTargetChange(event) {
        this.targetObject = event.target.value;
    }

    /**
     * Calls MigrationValidator.validateConfiguration with a JSON payload
     * built from the user-entered source/target object names.
     * Navigates to step 2 with results on success or failure.
     */
    handleValidate() {
        if (!this.sourceObject || !this.targetObject) {
            this.dispatchToastEvent('error', 'Required Fields', 'Source and Target object names are required.');
            return;
        }

        this.isLoading = true;
        const configJson = JSON.stringify({
            sourceObject: this.sourceObject,
            targetObject: this.targetObject
        });

        validateConfiguration({ configJson })
            .then(result => {
                this.validationSuccess = result.isValid;
                this.validationErrors = result.errors || [];
                this.validationWarnings = result.warnings || [];
                this.currentStep = 2;
            })
            .catch(error => {
                this.validationSuccess = false;
                this.validationErrors = [this.extractErrorMessage(error)];
                this.validationWarnings = [];
                this.currentStep = 2;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Calls MigrationProcessHandler.startMigrationAsync to enqueue the migration
     * pipeline. Navigates to step 3 on success.
     */
    handleStartMigration() {
        this.isLoading = true;

        startMigrationAsync({ cpqRecordIds: [] })
            .then(auditId => {
                this.auditRecordId = auditId;
                this.currentStep = 3;
                this.dispatchToastEvent('success', 'Migration Started', 'Migration pipeline has been queued.');
            })
            .catch(error => {
                this.dispatchToastEvent('error', 'Migration Failed', this.extractErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleBack() {
        this.currentStep = 1;
        this.validationErrors = [];
        this.validationWarnings = [];
    }

    handleReset() {
        this.currentStep = 1;
        this.sourceObject = '';
        this.targetObject = '';
        this.validationSuccess = false;
        this.validationErrors = [];
        this.validationWarnings = [];
        this.auditRecordId = '';
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /** Dispatches a platform ShowToastEvent. */
    dispatchToastEvent(variant, title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    /** Extracts a readable message from an Apex or network error object. */
    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }
}