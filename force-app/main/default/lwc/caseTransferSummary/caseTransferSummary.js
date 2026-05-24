import { LightningElement, api, wire } from 'lwc';
import getCaseTransferSummary from '@salesforce/apex/CaseTransferSummaryController.getCaseTransferSummary';
import { reduceErrors } from 'c/ldsUtils'; // A common utility for error handling

export default class CaseTransferSummary extends LightningElement {
    @api recordId;
    summary;
    error;
    isLoading = true;

    @wire(getCaseTransferSummary, { caseId: '$recordId' })
    wiredSummary({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.summary = data;
            this.error = undefined;
        } else if (error) {
            this.error = reduceErrors(error); // Use a utility to format the error
            this.summary = undefined;
            console.error('Error fetching case transfer summary:', JSON.stringify(this.error));
        }
    }

    get hasSummary() {
        return this.summary && this.summary.length > 0;
    }
}