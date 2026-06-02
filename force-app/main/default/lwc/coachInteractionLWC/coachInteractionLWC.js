import { LightningElement, api, track } from 'lwc';
import logInteraction from '@salesforce/apex/OpportunityInteractionLogger.logInteraction';

export default class CoachInteractionLWC extends LightningElement {
    /** Opportunity record Id passed from the record page. */
    @api opportunityId;

    @track recommendationId = '';
    @track isLoading = false;
    @track errorMessage = '';
    @track successMessage = '';

    handleRecommendationChange(event) {
        this.recommendationId = event.target.value;
    }

    handleLogInteraction() {
        this.errorMessage = '';
        this.successMessage = '';

        if (!this.recommendationId || this.recommendationId.trim() === '') {
            this.errorMessage = 'Please enter a recommendation ID before logging.';
            return;
        }

        this.isLoading = true;

        logInteraction({
            opportunityId: this.opportunityId,
            recommendationId: this.recommendationId
        })
            .then(() => {
                this.successMessage = 'Interaction logged successfully.';
                this.recommendationId = '';
                this.dispatchEvent(
                    new CustomEvent('recommendationAdopted', {
                        detail: {
                            opportunityId: this.opportunityId,
                            recommendationId: this.recommendationId
                        },
                        bubbles: true,
                        composed: true
                    })
                );
            })
            .catch((error) => {
                this.errorMessage =
                    (error && error.body && error.body.message)
                        ? error.body.message
                        : 'An unexpected error occurred while logging the interaction.';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}