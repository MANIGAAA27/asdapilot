import { LightningElement, api } from 'lwc';

export default class CoachInteractionLWC extends LightningElement {
    @api recommendation;

    get recommendationTitle() {
        return this.recommendation?.title || 'Coaching Recommendation';
    }

    get recommendationSummary() {
        return this.recommendation?.summary || this.recommendation?.comments || 'No additional details.';
    }

    handleClick(event) {
        const interactionType = event.currentTarget.dataset.action;
        this.dispatchEvent(new CustomEvent('loginteraction', {
            detail: {
                interactionType: interactionType,
                comments: this.recommendationSummary,
                summary: this.recommendationSummary
            },
            bubbles: true,
            composed: true
        }));
    }
}
