// MODIFIED 2026-06-08 — Project: Gift Basket | CodeImplementation-GiftBasket | ASDA
import { LightningElement, api, wire } from 'lwc';
import getCaseTransferSummary from '@salesforce/apex/CaseTransferSummaryController.getCaseTransferSummary';

export default class CaseTransferSummary extends LightningElement {
    @api recordId;
    summary;
    error;
    isLoading = true;

    @wire(getCaseTransferSummary, { caseId: '$recordId' })
    wiredSummary({ error, data }) {
        this.isLoading = false;
        if (data !== undefined) {
            this.summary = data;
            this.error = undefined;
        } else if (error) {
            this.error = this._reduceErrors(error);
            this.summary = undefined;
            console.error('Error fetching case transfer summary:', JSON.stringify(this.error));
        }
    }

    get hasSummary() {
        return this.summary && this.summary.length > 0;
    }

    /**
     * Reduces one or more LDS errors into a string[] of error messages.
     */
    _reduceErrors(errors) {
        if (!Array.isArray(errors)) {
            errors = [errors];
        }
        return errors
            .filter(error => !!error)
            .map(error => {
                if (Array.isArray(error.body)) {
                    return error.body.map(e => e.message);
                } else if (error.body && typeof error.body.message === 'string') {
                    return error.body.message;
                } else if (typeof error.message === 'string') {
                    return error.message;
                }
                return error.statusText;
            })
            .reduce((prev, curr) => prev.concat(curr), [])
            .filter(message => !!message);
    }
}