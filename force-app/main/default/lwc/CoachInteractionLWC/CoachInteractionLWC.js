import { LightningElement, api, track } from 'lwc';
import logInteraction from '@salesforce/apex/OpportunityInteractionLogger.logInteraction';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CoachInteractionLWC extends LightningElement {
    @api recordId;
    @api recommendation;
    @track interactionType = 'Viewed';
    @track comments = '';

    get interactionTypeOptions() {
        return [
            { label: 'Viewed', value: 'Viewed' },
            { label: 'Updated', value: 'Updated' },
            { label: 'Ignored', value: 'Ignored' }
        ];
    }

    handleTypeChange(event) {
        this.interactionType = event.detail.value;
    }

    handleCommentsChange(event) {
        this.comments = event.detail.value;
    }

    handleLogInteraction() {
        const payload = {
            opportunityId: this.recordId,
            recommendation: this.recommendation,
            interactionType: this.interactionType,
            comments: this.comments,
            interactionDate: new Date().toISOString().slice(0, 10)
        };
        logInteraction({ request: payload })
            .then((result) => {
                this.dispatchEvent(new CustomEvent('interactionlogged', { detail: result }));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Interaction logged successfully.',
                        variant: 'success'
                    })
                );
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error logging interaction',
                        message: error?.body?.message || 'Unknown error',
                        variant: 'error'
                    })
                );
            });
    }
}