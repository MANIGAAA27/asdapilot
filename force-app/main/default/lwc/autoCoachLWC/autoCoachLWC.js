import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import logInteraction from '@salesforce/apex/OpportunityInteractionLogger.logInteraction';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import HEALTH_STATUS from '@salesforce/schema/Opportunity.Health_Status__c';
import LAST_RECOMMENDATION from '@salesforce/schema/Opportunity.Last_Coaching_Recommendation__c';
import RISK_STAGNANT from '@salesforce/schema/Opportunity.Risk_Stagnant__c';
import RISK_MISSING_CONTACT from '@salesforce/schema/Opportunity.Risk_Missing_Key_Contact__c';
import RISK_NO_MEETINGS from '@salesforce/schema/Opportunity.Risk_No_Recent_Meetings__c';
import RISK_NEXT_STEPS from '@salesforce/schema/Opportunity.Risk_Next_Steps_Undefined__c';

export default class AutoCoachLWC extends LightningElement {
    @api recordId;
    @track recommendations = [];
    @track showEmptyState = true;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [HEALTH_STATUS, LAST_RECOMMENDATION, RISK_STAGNANT, RISK_MISSING_CONTACT, RISK_NO_MEETINGS, RISK_NEXT_STEPS]
    })
    wiredOpportunity({ error, data }) {
        if (data) {
            const status = getFieldValue(data, HEALTH_STATUS);
            const lastRecommendation = getFieldValue(data, LAST_RECOMMENDATION);
            const risks = [];
            if (getFieldValue(data, RISK_STAGNANT)) risks.push({ id: 'stagnant', type: 'Stagnant', text: 'Follow up on a stagnant opportunity.' });
            if (getFieldValue(data, RISK_MISSING_CONTACT)) risks.push({ id: 'contact', type: 'Missing Key Contact', text: 'Add a decision maker contact role.' });
            if (getFieldValue(data, RISK_NO_MEETINGS)) risks.push({ id: 'meeting', type: 'No Recent Meetings', text: 'Schedule a meeting with the buyer.' });
            if (getFieldValue(data, RISK_NEXT_STEPS)) risks.push({ id: 'steps', type: 'Next Steps Undefined', text: 'Update the next step field.' });

            if (lastRecommendation || (status && status !== 'Healthy') || risks.length > 0) {
                this.recommendations = risks.length > 0 ? risks : [{ id: 'latest', type: status || 'Coach', text: lastRecommendation || 'Review this opportunity.' }];
                this.showEmptyState = false;
            } else {
                this.recommendations = [];
                this.showEmptyState = true;
            }
        } else if (error) {
            this.showEmptyState = true;
            this.recommendations = [];
        }
    }

    get hasRecommendations() {
        return this.recommendations && this.recommendations.length > 0;
    }

    async handleInteraction(event) {
        const { interactionType, comments, recommendationType } = event.detail;
        try {
            await logInteraction({
                opportunityId: this.recordId,
                interactionType: recommendationType || interactionType,
                interactionDate: new Date().toISOString().substring(0, 10),
                comments
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Interaction logged.',
                    variant: 'success'
                })
            );
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: e?.body?.message || 'Unable to log interaction.',
                    variant: 'error'
                })
            );
        }
    }
}