import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import logInteraction from '@salesforce/apex/OpportunityInteractionLogger.logInteraction';
import { getRecord } from 'lightning/uiRecordApi';

export default class AutoCoachLWC extends LightningElement {
    @api recordId;
    @track recommendations = [];

    @wire(getRecord, { recordId: '$recordId', fields: ['Opportunity.Health_Status__c', 'Opportunity.Last_Coaching_Recommendation__c'] })
    wiredOpportunity;

    get hasRecommendations() {
        return true;
    }

    handleLogInteraction(event) {
        const recommendation = event.detail;
        const request = {
            opportunityId: this.recordId,
            interactionType: recommendation.interactionType || 'Viewed',
            interactionDate: new Date().toISOString().substring(0, 10),
            comments: recommendation.comments || recommendation.summary || ''
        };

        logInteraction({ request })
            .then((result) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: result.message,
                        variant: 'success'
                    })
                );
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error logging interaction',
                        message: error?.body?.message || error.message,
                        variant: 'error'
                    })
                );
            });
    }
}
