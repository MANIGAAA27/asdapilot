import { LightningElement, track, wire } from 'lwc';
import { createRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDataMappings from '@salesforce/apex/ARM_MigrationScheduler.getDataMappings';

const CPQ_ARM_DATA_MAPPING_OBJECT = 'CPQ_ARM_DataMapping__c';

const MAPPING_COLUMNS = [
    { label: 'Mapping Name', fieldName: 'MappingName__c', type: 'text', sortable: true },
    { label: 'Source Entity', fieldName: 'SourceEntity__c', type: 'text', sortable: true },
    { label: 'Target Entity', fieldName: 'TargetEntity__c', type: 'text', sortable: true }
];

/**
 * DataMappingWizard — multi-step UI component for managing CPQ-to-ARM data mappings.
 *
 * Provides a three-step wizard:
 *   1. View existing CPQ_ARM_DataMapping__c records
 *   2. Configure a new mapping (source entity, target entity)
 *   3. Review and save the new mapping via LDS createRecord
 */
export default class DataMappingWizard extends LightningElement {

    @track currentStep = 'step1';
    @track error;
    @track isLoadingMappings = false;
    @track isSaving = false;
    @track hasError = false;
    @track mappings = [];

    @track newMapping = {
        mappingName: '',
        sourceEntity: '',
        targetEntity: ''
    };

    _wiredMappingsResult;
    mappingColumns = MAPPING_COLUMNS;

    // ─── Wire ────────────────────────────────────────────────────────────────

    @wire(getDataMappings, { recordLimit: 50 })
    wiredMappings(result) {
        this._wiredMappingsResult = result;
        if (result.data) {
            this.mappings = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = this._extractError(result.error);
            this.mappings = [];
        }
    }

    // ─── Getters ─────────────────────────────────────────────────────────────

    get isStep1() { return this.currentStep === 'step1'; }
    get isStep2() { return this.currentStep === 'step2'; }
    get isStep3() { return this.currentStep === 'step3'; }

    get hasMappings() {
        return this.mappings && this.mappings.length > 0;
    }

    get isStep2Invalid() {
        return !this.newMapping.mappingName ||
               !this.newMapping.sourceEntity ||
               !this.newMapping.targetEntity;
    }

    // ─── Handlers ────────────────────────────────────────────────────────────

    handleCreateNew() {
        this.newMapping = { mappingName: '', sourceEntity: '', targetEntity: '' };
        this.currentStep = 'step2';
        this.error = undefined;
    }

    handleInputChange(event) {
        const fieldName = event.target.name;
        this.newMapping = {
            ...this.newMapping,
            [fieldName]: event.target.value
        };
    }

    handleReview() {
        if (this.isStep2Invalid) {
            this.error = 'All mapping fields are required.';
            return;
        }
        this.error = undefined;
        this.currentStep = 'step3';
    }

    handleBack() {
        if (this.currentStep === 'step2') {
            this.currentStep = 'step1';
        } else if (this.currentStep === 'step3') {
            this.currentStep = 'step2';
        }
        this.error = undefined;
    }

    handleSave() {
        if (this.isStep2Invalid) {
            this.error = 'All mapping fields are required.';
            return;
        }

        this.isSaving = true;
        this.error = undefined;

        const fields = {
            MappingName__c: this.newMapping.mappingName,
            SourceEntity__c: this.newMapping.sourceEntity,
            TargetEntity__c: this.newMapping.targetEntity
        };

        const recordInput = { apiName: CPQ_ARM_DATA_MAPPING_OBJECT, fields };

        createRecord(recordInput)
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Data mapping saved successfully.',
                    variant: 'success'
                }));
                this.currentStep = 'step1';
                this.newMapping = { mappingName: '', sourceEntity: '', targetEntity: '' };
                return refreshApex(this._wiredMappingsResult);
            })
            .catch(err => {
                this.error = this._extractError(err);
                this.hasError = true;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Save Failed',
                    message: this.error,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    // ─── Private ─────────────────────────────────────────────────────────────

    _extractError(err) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        if (err && err.message) {
            return err.message;
        }
        return 'An unexpected error occurred.';
    }
}
