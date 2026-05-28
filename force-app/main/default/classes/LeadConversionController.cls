/**
 * @file              LeadConversionController.cls
 * @description       AuraEnabled Apex controller for the leadConversionWizard LWC.
 *                    Exposes Lead data retrieval, duplicate-matching lookups,
 *                    quarter-end date calculation, and the conversion execution
 *                    endpoint. Delegates all business logic to LeadConversionService.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             LeadConversion
 *
 * @dependencies      LeadConversionService
 * @calledBy          leadConversionWizard (LWC)
 * @testClass         LeadConversionControllerTest
 *
 * @see               LLD-001 Custom Lead Conversion (Feature: Custom Lead Conversion)
 */

/**
 * Lightning controller exposing read and write operations for the Lead
 * Conversion Wizard LWC component.
 *
 * Responsibilities:
 *   - Provide cached read endpoints for Lead data and matching records.
 *   - Expose the quarter-end date for pre-populating Opportunity CloseDate.
 *   - Accept a ConversionPayload from the LWC and delegate to LeadConversionService.
 *   - Translate service exceptions into AuraHandledExceptions for client display.
 *
 * Threading: synchronous only.
 *
 * @testClass LeadConversionControllerTest
 */
public with sharing class LeadConversionController {

    // ─────────────────────────────────────────────────────────────────────────
    //  Read Endpoints (cacheable)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns the Lead record with all fields needed by the conversion wizard.
     * Cacheable — safe for @wire in the LWC; does not mutate data.
     *
     * @param  leadId  Id of the Lead to retrieve.
     * @return Lead SObject with conversion fields populated.
     * @throws AuraHandledException on query or FLS failure.
     *
     * @calledBy    leadConversionWizard.js (getLeadData imperative call)
     * @testMethods test_getLeadData_validId_returnsLead,
     *              test_getLeadData_convertedLead_returnsLead
     */
    @AuraEnabled(cacheable=true)
    public static Lead getLeadData(Id leadId) {
        try {
            return LeadConversionService.getLeadForConversion(leadId);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /**
     * Returns existing Accounts matching the given company name.
     * Cacheable — used to pre-populate the "Use Existing Account" list.
     *
     * @param  companyName  Lead.Company value to match against Account.Name.
     * @return List<Account> — up to 10 matches; empty list if none.
     * @throws AuraHandledException on query or FLS failure.
     *
     * @calledBy    leadConversionWizard.js (findMatchingAccounts imperative call)
     * @testMethods test_findMatchingAccounts_matchFound_returnsAccounts,
     *              test_findMatchingAccounts_noMatch_returnsEmpty
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> findMatchingAccounts(String companyName) {
        try {
            return LeadConversionService.findMatchingAccounts(companyName);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /**
     * Returns existing Contacts matching the given email address.
     * Cacheable — used to pre-populate the "Use Existing Contact" list.
     *
     * @param  email  Lead.Email value to match against Contact.Email.
     * @return List<Contact> — up to 10 matches; empty list if none.
     * @throws AuraHandledException on query or FLS failure.
     *
     * @calledBy    leadConversionWizard.js (findMatchingContacts imperative call)
     * @testMethods test_findMatchingContacts_matchFound_returnsContacts,
     *              test_findMatchingContacts_noMatch_returnsEmpty
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> findMatchingContacts(String email) {
        try {
            return LeadConversionService.findMatchingContacts(email);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /**
     * Returns the last day of the current calendar quarter.
     * Used to pre-populate Opportunity.CloseDate in the LWC wizard.
     * Cacheable — pure computation, no side effects.
     *
     * @return Date — last day of current quarter (e.g., 2026-06-30 for Q2).
     *
     * @calledBy    leadConversionWizard.js (getQuarterEndDate imperative call)
     * @testMethods test_getQuarterEndDate_returnsExpectedDate
     */
    @AuraEnabled(cacheable=true)
    public static Date getQuarterEndDate() {
        return LeadConversionService.getQuarterEndDate();
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Write Endpoint
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Executes the lead conversion using the values collected by the LWC wizard.
     * Builds a LeadConversionService.ConversionRequest from the payload, delegates
     * to the service, and wraps the result in a ConversionResultWrapper for the LWC.
     *
     * @param  payload  ConversionPayload instance deserialized from the LWC's JS object.
     * @return ConversionResultWrapper containing success flag and converted record IDs.
     * @throws AuraHandledException on unexpected exceptions (validation errors are
     *         surfaced via ConversionResultWrapper.success = false).
     *
     * @calledBy    leadConversionWizard.js (performConversion imperative call)
     * @testMethods test_performConversion_newRecords_success,
     *              test_performConversion_existingAccount_success,
     *              test_performConversion_noOpportunity_success,
     *              test_performConversion_nullLeadId_returnsFailure
     */
    @AuraEnabled
    public static ConversionResultWrapper performConversion(ConversionPayload payload) {
        try {
            LeadConversionService.ConversionRequest req = buildServiceRequest(payload);

            List<LeadConversionService.ConversionResult> results =
                LeadConversionService.convertLead(
                    new List<LeadConversionService.ConversionRequest>{ req }
                );

            LeadConversionService.ConversionResult svcResult = results[0];

            ConversionResultWrapper wrapper = new ConversionResultWrapper();
            wrapper.success              = svcResult.success;
            wrapper.errorMessage         = svcResult.errorMessage;
            wrapper.convertedAccountId   = svcResult.convertedAccountId != null
                ? String.valueOf(svcResult.convertedAccountId) : null;
            wrapper.convertedContactId   = svcResult.convertedContactId != null
                ? String.valueOf(svcResult.convertedContactId) : null;
            wrapper.convertedOpportunityId = svcResult.convertedOpportunityId != null
                ? String.valueOf(svcResult.convertedOpportunityId) : null;
            return wrapper;

        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Private Helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Maps ConversionPayload fields to a LeadConversionService.ConversionRequest. */
    private static LeadConversionService.ConversionRequest buildServiceRequest(
        ConversionPayload payload
    ) {
        LeadConversionService.ConversionRequest req = new LeadConversionService.ConversionRequest();
        req.leadId                = payload.leadId;
        req.useExistingAccount    = payload.useExistingAccount;
        req.existingAccountId     = payload.existingAccountId;
        req.newAccountName        = payload.newAccountName;
        req.leadIndustry          = payload.leadIndustry;
        req.leadWebsite           = payload.leadWebsite;
        req.leadPhone             = payload.leadPhone;
        req.leadBillingStreet     = payload.leadBillingStreet;
        req.leadBillingCity       = payload.leadBillingCity;
        req.leadBillingState      = payload.leadBillingState;
        req.leadBillingPostalCode = payload.leadBillingPostalCode;
        req.useExistingContact    = payload.useExistingContact;
        req.existingContactId     = payload.existingContactId;
        req.leadTitle             = payload.leadTitle;
        req.leadMobilePhone       = payload.leadMobilePhone;
        req.createOpportunity     = payload.createOpportunity;
        req.opportunityName       = payload.opportunityName;
        req.opportunityAmount     = payload.opportunityAmount;
        req.opportunityCloseDate  = payload.opportunityCloseDate;
        return req;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Inner Classes — Payload / Result Wrappers
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Deserialization target for the JavaScript object sent by leadConversionWizard.js.
     * Property names MUST match the JS object keys exactly (case-sensitive).
     */
    public class ConversionPayload {
        @AuraEnabled public Id      leadId;
        @AuraEnabled public Boolean useExistingAccount;
        @AuraEnabled public Id      existingAccountId;
        @AuraEnabled public String  newAccountName;
        @AuraEnabled public String  leadIndustry;
        @AuraEnabled public String  leadWebsite;
        @AuraEnabled public String  leadPhone;
        @AuraEnabled public String  leadBillingStreet;
        @AuraEnabled public String  leadBillingCity;
        @AuraEnabled public String  leadBillingState;
        @AuraEnabled public String  leadBillingPostalCode;
        @AuraEnabled public Boolean useExistingContact;
        @AuraEnabled public Id      existingContactId;
        @AuraEnabled public String  leadTitle;
        @AuraEnabled public String  leadMobilePhone;
        @AuraEnabled public Boolean createOpportunity;
        @AuraEnabled public String  opportunityName;
        @AuraEnabled public Decimal opportunityAmount;
        @AuraEnabled public Date    opportunityCloseDate;
    }

    /**
     * Serialization source returned to leadConversionWizard.js after conversion.
     * All Id fields are exposed as String to allow easy null-checking in JS.
     */
    public class ConversionResultWrapper {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  errorMessage;
        @AuraEnabled public String  convertedAccountId;
        @AuraEnabled public String  convertedContactId;
        @AuraEnabled public String  convertedOpportunityId;
    }
}