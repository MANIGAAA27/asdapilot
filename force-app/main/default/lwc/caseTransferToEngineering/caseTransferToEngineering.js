import { LightningElement, api, wire } from 'lwc';
import getObjectInfo from '@salesforce/apex/CaseTransferService.getEngineeringQueueId';
import submitTransfer from '@salesforce/apex/CaseTransferService.submitTransfer';
import { getObjectInfo as getUiObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import CASE_OBJECT from '@salesforce/schema/Case';
import REPRODUCTION_STEPS_FIELD from '@salesforce/schema/Case.Reproduction_Steps__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CaseTransferToEngineering extends LightningElement {
    @api recordId;
    acceptedFormats = ['.txt', '.log', '.zip', '.json', '.csv'];
    selectedReproductionSteps = [];
    troubleshootingSteps = '';
    uploadedFiles = [];
    reproductionOptions = [];
    errorBanner;
    fileError;
    reproError;
    troubleshootingError;
    isSubmitting = false;

    @wire(getUiObjectInfo, { objectApiName: CASE_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: REPRODUCTION_STEPS_FIELD
    })
    wiredPicklistValues({ data }) {
        if (data) {
            this.reproductionOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
        }
    }

    connectedCallback() {
        getObjectInfo().catch(() => {});
    }

    handleUploadFinished(event) {
        this.uploadedFiles = event.detail.files || [];
        this.fileError = '';
        this.errorBanner = '';
    }

    handleReproductionChange(event) {
        this.selectedReproductionSteps = event.detail.value;
        this.reproError = '';
        this.errorBanner = '';
    }

    handleTroubleshootingChange(event) {
        this.troubleshootingSteps = event.target.value;
        this.troubleshootingError = '';
        this.errorBanner = '';
    }

    validate() {
        const messages = [];
        this.fileError = '';
        this.reproError = '';
        this.troubleshootingError = '';

        if (!this.uploadedFiles || this.uploadedFiles.length === 0) {
            this.fileError = 'Please attach at least one relevant log file before transferring to Engineering.';
            messages.push(this.fileError);
        }
        if (!this.selectedReproductionSteps || this.selectedReproductionSteps.length === 0) {
            this.reproError = 'Please select at least one reproduction step.';
            messages.push(this.reproError);
        }
        if (!this.troubleshootingSteps || this.troubleshootingSteps.trim().length < 20) {
            this.troubleshootingError = 'Please document troubleshooting steps already taken with at least 20 characters.';
            messages.push(this.troubleshootingError);
        }

        this.errorBanner = messages.length ? messages.join(' ') : '';
        return messages.length === 0;
    }

    handleSubmit() {
        if (!this.validate()) {
            return;
        }

        this.isSubmitting = true;
        submitTransfer({
            caseId: this.recordId,
            troubleshootingSteps: this.troubleshootingSteps,
            reproductionSteps: this.selectedReproductionSteps
        })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Case transferred to Engineering successfully.',
                        variant: 'success'
                    })
                );
                this.errorBanner = '';
            })
            .catch(error => {
                this.errorBanner =
                    error && error.body && error.body.message
                        ? error.body.message
                        : 'Unable to complete the transfer.';
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }
}
