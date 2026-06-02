import { LightningElement, api } from 'lwc';

export default class CoachInteractionLWC extends LightningElement {
    @api recommendation;

    notifyInteraction(event) {
        const interactionType = event.currentTarget.dataset.type;
        this.dispatchEvent(
            new CustomEvent('interaction', {
                detail: {
                    interactionType,
                    recommendationType: this.recommendation?.type,
                    comments: ''
                },
                bubbles: true,
                composed: true
            })
        );
    }
}