import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import HEALTH_STATUS from '@salesforce/schema/Opportunity.Health_Status__c';
import RISK_STAGNANT from '@salesforce/schema/Opportunity.Risk_Stagnant__c';
import RISK_MISSING_KEY_CONTACT from '@salesforce/schema/Opportunity.Risk_Missing_Key_Contact__c';
import RISK_NO_RECENT_MEETINGS from '@salesforce/schema/Opportunity.Risk_No_Recent_Meetings__c';
import RISK_NEXT_STEPS_UNDEFINED from '@salesforce/schema/Opportunity.Risk_Next_Steps_Undefined__c';
import LAST_RECOMMENDATION from '@salesforce/schema/Opportunity.Last_Coaching_Recommendation__c';

export default class AutoCoachLWC extends LightningElement {
    @api recordId;
    @track insights = [];

    fields = [
        HEALTH_STATUS,
        RISK_STAGNANT,
        RISK_MISSING_KEY_CONTACT,
        RISK_NO_RECENT_MEETINGS,
        RISK_NEXT_STEPS_UNDEFINED,
        LAST_RECOMMENDATION
    ];

    @wire(getRecord, { recordId: '$recordId', fields: ['$fields'] })
    opportunity;

    get hasInsights() {
        const record = this.opportunity?.data;
        if (!record) {
            return false;
        }
        const health = getFieldValue(record, HEALTH_STATUS);
        return health && health !== 'Healthy';
    }

    connectedCallback() {
        this.insights = [
            {
                key: '1',
                recommendation: 'Review opportunity health and take corrective action.',
                status: 'At Risk'
            }
        ];
    }

    handleInteractionLogged(event) {
        this.dispatchEvent(new CustomEvent('interactionlogged', {
            detail: event.detail,
            bubbles: true,
            composed: true
        }));
    }
}