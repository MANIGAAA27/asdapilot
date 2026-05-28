/**
 * @file        leadConversionModal.js
 * @description Main LWC controller for the Lead Conversion modal. Launched via
 *              Quick Action on the Lead record page. Orchestrates Account, Contact,
 *              and Opportunity creation/association and delegates conversion to
 *              LeadConversionController Apex methods.
 * @author      ASDA Dev Agent
 * @created     2026-05-28
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getLeadData from '@salesforce/apex/LeadConversionController.getLeadData';
import searchAccounts from '@salesforce/apex/LeadConversionController.searchAccounts';
import searchContacts from '@salesforce/apex/LeadConversionController.searchContacts';
import convertLead from '@salesforce/apex/LeadConversionController.convertLead';
import getFiscalQuarterEndDate from '@salesforce/apex/LeadConversionController.getFiscalQuarterEndDate';

const ACCOUNT_MODE_NEW = 'new';
const ACCOUNT_MODE_EXISTING = 'existing';
const CONTACT_MODE_NEW = 'new';
const CONTACT_MODE_EXISTING = 'existing';
const OPP_MODE_NEW = 'new';
const OPP_MODE_EXISTING = 'existing';
const OPP_MODE_NONE = 'none';

export default class LeadConversionModal extends LightningElement {
    @api recordId; // Lead record Id passed by Quick Action

    @track isLoading = true;
    @track isConverting = false;
    @track conversionComplete = false;
    @track errorMessage = '';
    @track successMessage = '';

    // Lead data
    @track leadName = '';

    // Account state
    @track accountMode = ACCOUNT_MODE_NEW;
    @track accountValues = {};
    @track selectedAccountId = null;
    @track selectedAccountName = '';

    // Contact state
    @track contactMode = CONTACT_MODE_NEW;
    @track contactValues = {};
    @track selectedContactId = null;
    @track selectedContactName = '';

    // Opportunity state
    @track opportunityMode = OPP_MODE_NEW;
    @track opportunityValues = {};
    @track selectedOpportunityId = null;
    @track selectedOpportunityName = '';

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    connectedCallback() {
        this.loadLeadData();
    }

    async loadLeadData() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const [leadData, fiscalDate] = await Promise.all([
                getLeadData({ leadId: this.recordId }),
                getFiscalQuarterEndDate()
            ]);

            const lead = leadData.leadRecord;
            this.leadName = (lead.FirstName ? lead.FirstName + ' ' : '') + (lead.LastName || '');

            // Pre-populate Account values
            this.accountValues = {
                name: leadData.accountFields.name || '',
                industry: leadData.accountFields.industry || '',
                website: leadData.accountFields.website || '',
                phone: leadData.accountFields.phone || '',
                billingStreet: leadData.accountFields.billingStreet || '',
                billingCity: leadData.accountFields.billingCity || '',
                billingState: leadData.accountFields.billingState || '',
                billingPostalCode: leadData.accountFields.billingPostalCode || ''
            };

            // Pre-populate Contact values
            this.contactValues = {
                firstName: leadData.contactFields.firstName || '',
                lastName: leadData.contactFields.lastName || '',
                title: leadData.contactFields.title || '',
                email: leadData.contactFields.email || '',
                mobilePhone: leadData.contactFields.mobilePhone || ''
            };

            // Pre-populate Opportunity values
            const closeDateStr = fiscalDate
                ? fiscalDate
                : (leadData.opportunityFields.closeDate || '');
            this.opportunityValues = {
                name: leadData.opportunityFields.name || '',
                amount: leadData.opportunityFields.amount || '',
                closeDate: closeDateStr
            };

        } catch (err) {
            this.errorMessage = this.extractErrorMessage(err);
        } finally {
            this.isLoading = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Mode options (radio groups)
    // ─────────────────────────────────────────────────────────────────────────

    get accountModeOptions() {
        return [
            { label: 'Create New Account', value: ACCOUNT_MODE_NEW },
            { label: 'Use Existing Account', value: ACCOUNT_MODE_EXISTING }
        ];
    }

    get contactModeOptions() {
        return [
            { label: 'Create New Contact', value: CONTACT_MODE_NEW },
            { label: 'Use Existing Contact', value: CONTACT_MODE_EXISTING }
        ];
    }

    get opportunityModeOptions() {
        return [
            { label: 'Create New Opportunity', value: OPP_MODE_NEW },
            { label: 'Use Existing Opportunity', value: OPP_MODE_EXISTING },
            { label: 'Do Not Create Opportunity', value: OPP_MODE_NONE }
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Visibility getters
    // ─────────────────────────────────────────────────────────────────────────

    get showAccountFields() {
        return this.accountMode === ACCOUNT_MODE_NEW;
    }

    get showAccountSearch() {
        return this.accountMode === ACCOUNT_MODE_EXISTING;
    }

    get showContactFields() {
        return this.contactMode === CONTACT_MODE_NEW;
    }

    get showContactSearch() {
        return this.contactMode === CONTACT_MODE_EXISTING;
    }

    get showOpportunityFields() {
        return this.opportunityMode === OPP_MODE_NEW;
    }

    get showOpportunitySearch() {
        return this.opportunityMode === OPP_MODE_EXISTING;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Field definitions for fieldMappingComponent
    // ─────────────────────────────────────────────────────────────────────────

    get accountFieldDefs() {
        return [
            { key: 'name', label: 'Account Name', type: 'text', required: true },
            { key: 'industry', label: 'Industry', type: 'text', required: false },
            { key: 'website', label: 'Website', type: 'url', required: false },
            { key: 'phone', label: 'Phone', type: 'tel', required: false },
            { key: 'billingStreet', label: 'Billing Street', type: 'text', required: false },
            { key: 'billingCity', label: 'Billing City', type: 'text', required: false },
            { key: 'billingState', label: 'Billing State', type: 'text', required: false },
            { key: 'billingPostalCode', label: 'Billing Postal Code', type: 'text', required: false }
        ];
    }

    get contactFieldDefs() {
        return [
            { key: 'firstName', label: 'First Name', type: 'text', required: false },
            { key: 'lastName', label: 'Last Name', type: 'text', required: true },
            { key: 'title', label: 'Title', type: 'text', required: false },
            { key: 'email', label: 'Email', type: 'email', required: false },
            { key: 'mobilePhone', label: 'Mobile Phone', type: 'tel', required: false }
        ];
    }

    get opportunityFieldDefs() {
        return [
            { key: 'name', label: 'Opportunity Name', type: 'text', required: true },
            { key: 'amount', label: 'Amount', type: 'number', required: false },
            { key: 'closeDate', label: 'Close Date', type: 'date', required: true }
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Event handlers — mode changes
    // ─────────────────────────────────────────────────────────────────────────

    handleAccountModeChange(event) {
        this.accountMode = event.detail.value;
        this.selectedAccountId = null;
        this.selectedAccountName = '';
        this.errorMessage = '';
    }

    handleContactModeChange(event) {
        this.contactMode = event.detail.value;
        this.selectedContactId = null;
        this.selectedContactName = '';
        this.errorMessage = '';
    }

    handleOpportunityModeChange(event) {
        this.opportunityMode = event.detail.value;
        this.selectedOpportunityId = null;
        this.selectedOpportunityName = '';
        this.errorMessage = '';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Event handlers — record selection from recordSearchComponent
    // ─────────────────────────────────────────────────────────────────────────

    handleAccountSelected(event) {
        this.selectedAccountId = event.detail.recordId;
        this.selectedAccountName = event.detail.recordName;
        this.errorMessage = '';
    }

    handleContactSelected(event) {
        this.selectedContactId = event.detail.recordId;
        this.selectedContactName = event.detail.recordName;
        this.errorMessage = '';
    }

    handleOpportunitySelected(event) {
        this.selectedOpportunityId = event.detail.recordId;
        this.selectedOpportunityName = event.detail.recordName;
        this.errorMessage = '';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Event handlers — field value changes from fieldMappingComponent
    // ─────────────────────────────────────────────────────────────────────────

    handleAccountValueChange(event) {
        this.accountValues = Object.assign({}, this.accountValues, event.detail);
    }

    handleContactValueChange(event) {
        this.contactValues = Object.assign({}, this.contactValues, event.detail);
    }

    handleOpportunityValueChange(event) {
        this.opportunityValues = Object.assign({}, this.opportunityValues, event.detail);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Conversion
    // ─────────────────────────────────────────────────────────────────────────

    async handleConvert() {
        this.errorMessage = '';
        if (!this.validateForm()) {
            return;
        }

        this.isConverting = true;
        try {
            const req = this.buildConversionRequest();
            const result = await convertLead({ conversionRequest: JSON.stringify(req) });

            this.successMessage = result.successMessage;
            this.conversionComplete = true;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Lead Converted',
                message: result.successMessage,
                variant: 'success'
            }));

        } catch (err) {
            this.errorMessage = this.extractErrorMessage(err);
        } finally {
            this.isConverting = false;
        }
    }

    buildConversionRequest() {
        const createOpp = this.opportunityMode !== OPP_MODE_NONE;
        return {
            leadId: this.recordId,

            // Account
            existingAccountId: this.accountMode === ACCOUNT_MODE_EXISTING
                ? this.selectedAccountId : null,
            accountName: this.accountValues.name,
            accountIndustry: this.accountValues.industry,
            accountWebsite: this.accountValues.website,
            accountPhone: this.accountValues.phone,
            accountBillingStreet: this.accountValues.billingStreet,
            accountBillingCity: this.accountValues.billingCity,
            accountBillingState: this.accountValues.billingState,
            accountBillingPostalCode: this.accountValues.billingPostalCode,

            // Contact
            existingContactId: this.contactMode === CONTACT_MODE_EXISTING
                ? this.selectedContactId : null,
            contactFirstName: this.contactValues.firstName,
            contactLastName: this.contactValues.lastName,
            contactTitle: this.contactValues.title,
            contactEmail: this.contactValues.email,
            contactMobilePhone: this.contactValues.mobilePhone,

            // Opportunity
            createOpportunity: createOpp,
            existingOpportunityId: this.opportunityMode === OPP_MODE_EXISTING
                ? this.selectedOpportunityId : null,
            opportunityName: this.opportunityValues.name,
            opportunityAmount: this.opportunityValues.amount
                ? parseFloat(this.opportunityValues.amount) : null,
            opportunityCloseDate: this.opportunityValues.closeDate
        };
    }

    validateForm() {
        let valid = true;
        const messages = [];

        if (this.accountMode === ACCOUNT_MODE_NEW && !this.accountValues.name) {
            messages.push('Account Name is required.');
            valid = false;
        }
        if (this.accountMode === ACCOUNT_MODE_EXISTING && !this.selectedAccountId) {
            messages.push('Please select an existing Account.');
            valid = false;
        }
        if (this.contactMode === CONTACT_MODE_NEW && !this.contactValues.lastName) {
            messages.push('Contact Last Name is required.');
            valid = false;
        }
        if (this.contactMode === CONTACT_MODE_EXISTING && !this.selectedContactId) {
            messages.push('Please select an existing Contact.');
            valid = false;
        }
        if (this.opportunityMode === OPP_MODE_NEW) {
            if (!this.opportunityValues.name) {
                messages.push('Opportunity Name is required.');
                valid = false;
            }
            if (!this.opportunityValues.closeDate) {
                messages.push('Opportunity Close Date is required.');
                valid = false;
            }
        }
        if (this.opportunityMode === OPP_MODE_EXISTING && !this.selectedOpportunityId) {
            messages.push('Please select an existing Opportunity.');
            valid = false;
        }

        if (!valid) {
            this.errorMessage = messages.join(' ');
        }
        return valid;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Close
    // ─────────────────────────────────────────────────────────────────────────

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Utility
    // ─────────────────────────────────────────────────────────────────────────

    extractErrorMessage(err) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        if (err && err.message) {
            return err.message;
        }
        return 'An unexpected error occurred. Please try again.';
    }
}