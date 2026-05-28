/**
 * @file              leadConversionWizard.js
 * @description       Multi-step wizard LWC for the Custom Lead Conversion feature.
 *                    Exposed as a lightning__FlowScreen component. Loads Lead data,
 *                    surfaces potential Account/Contact matches, collects user choices,
 *                    and invokes LeadConversionController.performConversion() to
 *                    execute the conversion. On success navigates to the converted
 *                    Account record and signals the enclosing flow to finish.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-28
 * @lastModified      2026-05-28
 */

import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { FlowNavigationCancelEvent, FlowNavigationFinishEvent } from 'lightning/flowSupport';
import getLeadData from '@salesforce/apex/LeadConversionController.getLeadData';
import findMatchingAccounts from '@salesforce/apex/LeadConversionController.findMatchingAccounts';
import findMatchingContacts from '@salesforce/apex/LeadConversionController.findMatchingContacts';
import getQuarterEndDate from '@salesforce/apex/LeadConversionController.getQuarterEndDate';
import performConversion from '@salesforce/apex/LeadConversionController.performConversion';

const STEPS = ['account', 'contact', 'opportunity'];

/**
 * Formats a Salesforce Date (YYYY-MM-DD string returned by Apex @AuraEnabled)
 * into the ISO date string required by lightning-input type="date".
 * Returns an empty string when the input is null/undefined.
 */
function formatApexDate(apexDate) {
    if (!apexDate) return '';
    // Apex Date values serialise as 'YYYY-MM-DD' already; pass through.
    return typeof apexDate === 'string' ? apexDate : '';
}

export default class LeadConversionWizard extends NavigationMixin(LightningElement) {

    // ─── Flow input property ─────────────────────────────────────────────────
    @api recordId;

    // ─── Loading / error state ───────────────────────────────────────────────
    @track isLoading        = true;
    @track isConverting     = false;
    @track isAlreadyConverted = false;
    @track errorMessage     = '';

    // ─── Wizard step ─────────────────────────────────────────────────────────
    @track currentStep = 'account';

    // ─── Lead data ───────────────────────────────────────────────────────────
    @track leadData = {};

    // ─── Account state ───────────────────────────────────────────────────────
    @track matchingAccounts          = [];
    @track accountChoice             = 'new';
    @track selectedAccountId         = '';
    @track newAccountName            = '';
    @track newAccountIndustry        = '';
    @track newAccountWebsite         = '';
    @track newAccountPhone           = '';
    @track newAccountBillingStreet   = '';
    @track newAccountBillingCity     = '';
    @track newAccountBillingState    = '';
    @track newAccountBillingPostalCode = '';

    // ─── Contact state ───────────────────────────────────────────────────────
    @track matchingContacts     = [];
    @track contactChoice        = 'new';
    @track selectedContactId    = '';
    @track newContactFirstName  = '';
    @track newContactLastName   = '';
    @track newContactTitle      = '';
    @track newContactEmail      = '';
    @track newContactMobilePhone = '';

    // ─── Opportunity state ───────────────────────────────────────────────────
    @track createOpportunity   = true;
    @track opportunityName     = '';
    @track opportunityAmount;
    @track opportunityCloseDate = '';

    // ─────────────────────────────────────────────────────────────────────────
    //  Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    connectedCallback() {
        this.loadInitialData();
    }

    async loadInitialData() {
        this.isLoading    = true;
        this.errorMessage = '';
        try {
            const [lead, quarterEnd] = await Promise.all([
                getLeadData({ leadId: this.recordId }),
                getQuarterEndDate()
            ]);

            if (lead.IsConverted) {
                this.isAlreadyConverted = true;
                return;
            }

            this.leadData = lead;

            // Pre-populate account fields from Lead
            this.newAccountName              = lead.Company    || '';
            this.newAccountIndustry          = lead.Industry   || '';
            this.newAccountWebsite           = lead.Website    || '';
            this.newAccountPhone             = lead.Phone      || '';
            this.newAccountBillingStreet     = lead.Street     || '';
            this.newAccountBillingCity       = lead.City       || '';
            this.newAccountBillingState      = lead.State      || '';
            this.newAccountBillingPostalCode = lead.PostalCode || '';

            // Pre-populate contact fields from Lead
            this.newContactFirstName   = lead.FirstName   || '';
            this.newContactLastName    = lead.LastName    || '';
            this.newContactTitle       = lead.Title       || '';
            this.newContactEmail       = lead.Email       || '';
            this.newContactMobilePhone = lead.MobilePhone || '';

            // Pre-populate opportunity fields from Lead
            this.opportunityName    = lead.Company || '';
            this.opportunityAmount  = lead.Conversion_Amount__c || null;
            this.opportunityCloseDate = formatApexDate(quarterEnd);

            // Find matching records (sequential — need lead data first)
            const [accounts, contacts] = await Promise.all([
                findMatchingAccounts({ companyName: lead.Company }),
                findMatchingContacts({ email: lead.Email })
            ]);

            this.matchingAccounts = accounts || [];
            this.matchingContacts = contacts || [];

            // Default to 'existing' when matches are found
            if (this.matchingAccounts.length > 0) {
                this.accountChoice    = 'existing';
                this.selectedAccountId = this.matchingAccounts[0].Id;
            }
            if (this.matchingContacts.length > 0) {
                this.contactChoice    = 'existing';
                this.selectedContactId = this.matchingContacts[0].Id;
            }

        } catch (err) {
            this.errorMessage = 'Error loading lead data: ' +
                (err.body ? err.body.message : err.message);
        } finally {
            this.isLoading = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Getters — Step visibility
    // ─────────────────────────────────────────────────────────────────────────

    get isAccountStep()     { return this.currentStep === 'account'; }
    get isContactStep()     { return this.currentStep === 'contact'; }
    get isOpportunityStep() { return this.currentStep === 'opportunity'; }
    get isLastStep()        { return this.currentStep === STEPS[STEPS.length - 1]; }

    get showBackButton() {
        return STEPS.indexOf(this.currentStep) > 0;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Getters — Account section
    // ─────────────────────────────────────────────────────────────────────────

    get hasMatchingAccounts() { return this.matchingAccounts.length > 0; }
    get showNewAccountForm()  { return this.accountChoice === 'new'; }
    get showExistingAccountList() {
        return this.accountChoice === 'existing' && this.hasMatchingAccounts;
    }

    get accountOptions() {
        const opts = [{ label: 'Create New Account', value: 'new' }];
        if (this.hasMatchingAccounts) {
            opts.unshift({ label: 'Attach to Existing Account', value: 'existing' });
        }
        return opts;
    }

    get matchingAccountOptions() {
        return this.matchingAccounts.map(a => ({
            label: a.Name + (a.Phone ? ' — ' + a.Phone : ''),
            value: a.Id
        }));
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Getters — Contact section
    // ─────────────────────────────────────────────────────────────────────────

    get hasMatchingContacts()  { return this.matchingContacts.length > 0; }
    get showNewContactForm()   { return this.contactChoice === 'new'; }
    get showExistingContactList() {
        return this.contactChoice === 'existing' && this.hasMatchingContacts;
    }

    get contactOptions() {
        const opts = [{ label: 'Create New Contact', value: 'new' }];
        if (this.hasMatchingContacts) {
            opts.unshift({ label: 'Attach to Existing Contact', value: 'existing' });
        }
        return opts;
    }

    get matchingContactOptions() {
        return this.matchingContacts.map(c => ({
            label: c.Name + ' — ' + c.Email,
            value: c.Id
        }));
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Event Handlers — Navigation
    // ─────────────────────────────────────────────────────────────────────────

    handleNext() {
        if (!this.validateCurrentStep()) return;
        const idx = STEPS.indexOf(this.currentStep);
        if (idx < STEPS.length - 1) {
            this.currentStep = STEPS[idx + 1];
        }
        this.errorMessage = '';
    }

    handleBack() {
        const idx = STEPS.indexOf(this.currentStep);
        if (idx > 0) {
            this.currentStep = STEPS[idx - 1];
        }
        this.errorMessage = '';
    }

    handleCancel() {
        this.dispatchEvent(new FlowNavigationCancelEvent());
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Event Handlers — Field changes
    // ─────────────────────────────────────────────────────────────────────────

    handleAccountChoiceChange(event) {
        this.accountChoice = event.detail.value;
    }

    handleExistingAccountSelect(event) {
        this.selectedAccountId = event.detail.value;
    }

    handleNewAccountNameChange(event) {
        this.newAccountName = event.detail.value;
    }

    handleContactChoiceChange(event) {
        this.contactChoice = event.detail.value;
    }

    handleExistingContactSelect(event) {
        this.selectedContactId = event.detail.value;
    }

    handleCreateOpportunityChange(event) {
        this.createOpportunity = event.detail.checked;
    }

    /** Generic handler for plain text/number/date fields using data-field attribute. */
    handleFieldChange(event) {
        const field = event.target.dataset.field;
        if (field) {
            this[field] = event.detail.value !== undefined
                ? event.detail.value
                : event.detail.checked;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Conversion
    // ─────────────────────────────────────────────────────────────────────────

    async handleConvert() {
        if (!this.validateCurrentStep()) return;

        this.isConverting = true;
        this.errorMessage = '';

        try {
            const payload = this.buildConversionPayload();
            const result  = await performConversion({ payload });

            if (!result.success) {
                this.errorMessage = result.errorMessage || 'Conversion failed. Please try again.';
                return;
            }

            // Navigate to the converted Account record
            if (result.convertedAccountId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId:      result.convertedAccountId,
                        objectApiName: 'Account',
                        actionName:    'view'
                    }
                });
            }

            // Signal the enclosing flow to finish
            this.dispatchEvent(new FlowNavigationFinishEvent());

        } catch (err) {
            this.errorMessage = 'Conversion error: ' +
                (err.body ? err.body.message : err.message);
        } finally {
            this.isConverting = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Private Helpers
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Validates the fields on the active wizard step.
     * Returns true when all required fields are populated.
     */
    validateCurrentStep() {
        if (this.currentStep === 'account') {
            if (this.accountChoice === 'new' && !this.newAccountName) {
                this.errorMessage = 'Account Name is required.';
                return false;
            }
            if (this.accountChoice === 'existing' && !this.selectedAccountId) {
                this.errorMessage = 'Please select an existing account.';
                return false;
            }
        }
        if (this.currentStep === 'contact') {
            if (this.contactChoice === 'new' && !this.newContactLastName) {
                this.errorMessage = 'Contact Last Name is required.';
                return false;
            }
            if (this.contactChoice === 'existing' && !this.selectedContactId) {
                this.errorMessage = 'Please select an existing contact.';
                return false;
            }
        }
        if (this.currentStep === 'opportunity') {
            if (this.createOpportunity) {
                if (!this.opportunityName) {
                    this.errorMessage = 'Opportunity Name is required.';
                    return false;
                }
                if (!this.opportunityCloseDate) {
                    this.errorMessage = 'Close Date is required.';
                    return false;
                }
            }
        }
        this.errorMessage = '';
        return true;
    }

    /** Assembles the ConversionPayload object sent to LeadConversionController. */
    buildConversionPayload() {
        return {
            leadId:                this.recordId,
            useExistingAccount:    this.accountChoice === 'existing',
            existingAccountId:     this.accountChoice === 'existing' ? this.selectedAccountId : null,
            newAccountName:        this.newAccountName,
            leadIndustry:          this.newAccountIndustry,
            leadWebsite:           this.newAccountWebsite,
            leadPhone:             this.newAccountPhone,
            leadBillingStreet:     this.newAccountBillingStreet,
            leadBillingCity:       this.newAccountBillingCity,
            leadBillingState:      this.newAccountBillingState,
            leadBillingPostalCode: this.newAccountBillingPostalCode,
            useExistingContact:    this.contactChoice === 'existing',
            existingContactId:     this.contactChoice === 'existing' ? this.selectedContactId : null,
            leadTitle:             this.newContactTitle,
            leadMobilePhone:       this.newContactMobilePhone,
            createOpportunity:     this.createOpportunity,
            opportunityName:       this.createOpportunity ? this.opportunityName : null,
            opportunityAmount:     this.createOpportunity ? this.opportunityAmount : null,
            opportunityCloseDate:  this.createOpportunity ? this.opportunityCloseDate : null
        };
    }
}