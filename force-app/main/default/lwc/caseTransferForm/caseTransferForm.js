import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import validateCaseTransfer from "@salesforce/apex/CaseTransferController.validateCaseTransfer";

export default class CaseTransferForm extends LightningElement {
    @api recordId;
    @track reproductionSteps;
    @track reproductionStepOptions = [];
    @track troubleshootingSteps = "";

    handleReproductionStepChange(event) {
        this.reproductionSteps = event.detail.value;
    }

    handleTroubleshootingChange(event) {
        this.troubleshootingSteps = event.target.value;
    }

    handleUploadFinished(event) {
        // Process completed uploads
    }

    handleSubmit(event) {
        event.preventDefault();
        validateCaseTransfer({
            caseId: this.recordId,
            reproductionSteps: this.reproductionSteps,
            troubleshootingSteps: this.troubleshootingSteps
        })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Success",
                        message: "Case transfer details saved",
                        variant: "success"
                    })
                );
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Error",
                        message: error.body.message,
                        variant: "error"
                    })
                );
            });
    }
}