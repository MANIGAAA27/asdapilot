/**
 * @file          lwcValidationReport.js
 * @description   Parent/dashboard Lightning Web Component for the validation report component tree.
 *                Hosts the armtValidationReport child component and handles the 'validationcomplete'
 *                event dispatched by the child, updating the dashboard state accordingly.
 * @author        ASDA Dev Agent
 * @created       2026-06-06
 * @see           HLD-ARMT-V1.0 Section 3.4, HLD-CMP-023
 */

import { LightningElement, track } from 'lwc';

export default class LwcValidationReport extends LightningElement {

    /** Whether the validation step has been marked complete by the user. */
    @track isValidationComplete = false;

    /** Summary data from the validationcomplete event. */
    @track completionSummary = {
        blockerCount: 0,
        warningCount: 0,
        infoCount: 0,
        totalCount: 0
    };

    /**
     * Handles the 'validationcomplete' custom event dispatched by the child armtValidationReport component.
     * Updates the dashboard state to show the completion banner.
     *
     * @param {CustomEvent} event - The validationcomplete event with detail payload.
     */
    handleValidationComplete(event) {
        this.completionSummary = {
            blockerCount: event.detail.blockerCount || 0,
            warningCount: event.detail.warningCount || 0,
            infoCount: event.detail.infoCount || 0,
            totalCount: event.detail.totalCount || 0
        };
        this.isValidationComplete = true;
    }
}
