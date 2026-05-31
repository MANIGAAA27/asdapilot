import { LightningElement, track } from 'lwc';
import transferCase from '@salesforce/apex/CaseTransferService.transferCase';
import getReproductionSteps from '@salesforce/apex/CaseTransferService.getReproductionSteps';

export default class CaseTransferForm extends LightningElement {
    @track troubleshootingSteps = '';
    @track selectedReproductionSteps = [];
    @track reproductionStepsOptions = [];

    connectedCallback() {
        this.loadReproductionSteps();
    }

    loadReproductionSteps() {
        getReproductionSteps()
            .then(result => {
                this.reproductionStepsOptions = result;
            })
            .catch(error => {
                console.error('Error loading reproduction steps:', error);
            });
    }

    handleInputChange(event) {
        this.troubleshootingSteps = event.target.value;
    }

    handleReproductionStepsChange(event) {
        this.selectedReproductionSteps = event.detail.value;
    }

    handleUploadFinished(event) {
        // Handle file upload logic
    }

    handleSubmit() {
        transferCase({ troubles: this.troubleshootingSteps, reproductions: this.selectedReproductionSteps })
            .then(() => {
                // Handle successful transfer
            })
            .catch(error => {
                console.error('Error during case transfer:', error);
            });
    }
}