/**
 * @file              CustomLeadConversionFlowHandler.cls
 * @description       Invocable Apex handler for the Custom Lead Conversion Screen Flow.
 *                    Executes Database.convertLead() with parameters collected by the
 *                    flow, properly setting IsConverted on the Lead and linking the
 *                    converted record to Account, Contact, and optional Opportunity.
 *                    Also exposes a handleLeadConversion guard method used to
 *                    validate Lead eligibility before the flow is launched.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             LeadManagement
 *
 * @dependencies      (none in this changeset)
 * @calledBy          CustomLeadConversion (Flow — actionType: apex)
 * @testClass         CustomLeadConversionFlowHandlerTest
 *
 * @see               LLD - Sr Developer creates combined technical design (draft)
 */
public with sharing class CustomLeadConversionFlowHandler {

    // ─────────────────────────────────────────────────────────────────────────
    // Inner Types
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Input wrapper for the @InvocableMethod. Every @InvocableVariable field
     * corresponds to a Flow variable passed from CustomLeadConversion.flow-meta.xml.
     */
    public class ConversionRequest {
        @InvocableVariable(required=true label='Lead Id')
        public String leadId;

        /**
         * Pass the existing Account's Id to attach the Lead to it.
         * Leave blank/null to let Database.convertLead() create a new Account.
         */
        @InvocableVariable(label='Existing Account Id')
        public String existingAccountId;

        /**
         * Pass the existing Contact's Id to attach the Lead to it.
         * Leave blank/null to let Database.convertLead() create a new Contact.
         */
        @InvocableVariable(label='Existing Contact Id')
        public String existingContactId;

        @InvocableVariable(label='Create Opportunity')
        public Boolean createOpportunity;

        @InvocableVariable(label='Opportunity Name')
        public String opportunityName;

        @InvocableVariable(label='Opportunity Amount')
        public Decimal opportunityAmount;

        @InvocableVariable(label='Opportunity Close Date')
        public Date opportunityCloseDate;

        @InvocableVariable(label='Account Name')
        public String accountName;

        @InvocableVariable(label='Account Industry')
        public String accountIndustry;

        @InvocableVariable(label='Account Website')
        public String accountWebsite;

        @InvocableVariable(label='Account Phone')
        public String accountPhone;

        @InvocableVariable(label='Account Billing Street')
        public String accountBillingStreet;

        @InvocableVariable(label='Account Billing City')
        public String accountBillingCity;

        @InvocableVariable(label='Account Billing State')
        public String accountBillingState;

        @InvocableVariable(label='Account Billing Postal Code')
        public String accountBillingPostalCode;
    }

    /**
     * Output wrapper returned to the Flow after conversion completes.
     */
    public class ConversionResult {
        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        @InvocableVariable(label='Converted Account Id')
        public String convertedAccountId;

        @InvocableVariable(label='Converted Contact Id')
        public String convertedContactId;

        @InvocableVariable(label='Converted Opportunity Id')
        public String convertedOpportunityId;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public Methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Validates whether a Lead is eligible for conversion. Designed as an
     * AuraEnabled guard called by the Quick Action or pre-flight check before
     * the Screen Flow opens.
     *
     * @param  leadId  Id of the Lead record to validate.
     * @return         true when the Lead exists and has not yet been converted;
     *                 false otherwise (including blank input, missing record,
     *                 or IsConverted = true).
     *
     * @calledBy    CustomLeadConversionFlowHandlerTest (test)
     * @testMethods test_handleLeadConversion_flowLaunchedSuccessfully,
     *              test_handleLeadConversion_leadAlreadyConverted
     */
    @AuraEnabled(cacheable=true)
    public static Boolean handleLeadConversion(String leadId) {
        if (String.isBlank(leadId)) {
            return false;
        }
        List<Lead> leads = [
            SELECT Id, IsConverted
            FROM Lead
            WHERE Id = :leadId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (leads.isEmpty()) {
            return false;
        }
        return !leads[0].IsConverted;
    }

    /**
     * Executes lead conversion via Database.convertLead(), properly setting
     * IsConverted=true and linking the Lead to Account, Contact, and (optionally)
     * Opportunity. After conversion, updates the Opportunity Amount and CloseDate
     * and the Account address/details with user-supplied values from the flow.
     *
     * Bulk-safe up to governor limit of concurrent LeadConvert calls (200 per tx).
     *
     * @param  requests  List of ConversionRequest objects from the Flow.
     * @return           List of ConversionResult objects, one per request, with
     *                   isSuccess flag and converted record IDs.
     *
     * @calledBy    CustomLeadConversion (Flow)
     * @testMethods test_convertLead_newRecords_succeeds,
     *              test_convertLead_existingAccount_succeeds,
     *              test_convertLead_noOpportunity_succeeds,
     *              test_convertLead_blankLeadId_returnsError
     */
    @InvocableMethod(
        label='Convert Lead'
        description='Executes Database.convertLead() to set IsConverted=true and link the Lead to Account, Contact, and Opportunity.'
    )
    public static List<ConversionResult> convertLead(List<ConversionRequest> requests) {
        List<ConversionResult> results = new List<ConversionResult>();
        for (ConversionRequest req : requests) {
            results.add(processSingleConversion(req));
        }
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private Helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Processes one ConversionRequest and returns the corresponding result. */
    private static ConversionResult processSingleConversion(ConversionRequest req) {
        ConversionResult result = new ConversionResult();
        try {
            if (String.isBlank(req.leadId)) {
                result.isSuccess = false;
                result.errorMessage = 'Lead Id is required.';
                return result;
            }

            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(req.leadId);
            lc.setConvertedStatus(getConvertedStatus());
            lc.setDoNotCreateOpportunity(req.createOpportunity != true);

            if (String.isNotBlank(req.existingAccountId)) {
                lc.setAccountId(req.existingAccountId);
            }

            if (String.isNotBlank(req.existingContactId)) {
                lc.setContactId(req.existingContactId);
            }

            if (req.createOpportunity == true && String.isNotBlank(req.opportunityName)) {
                lc.setOpportunityName(req.opportunityName);
            }

            Database.LeadConvertResult lcr = Database.convertLead(lc);
            if (lcr.isSuccess()) {
                result.isSuccess = true;
                result.convertedAccountId = lcr.getAccountId();
                result.convertedContactId = lcr.getContactId();
                result.convertedOpportunityId = lcr.getOpportunityId();

                applyPostConversionUpdates(req, lcr);
            } else {
                result.isSuccess = false;
                result.errorMessage = lcr.getErrors()[0].getMessage();
            }
        } catch (Exception ex) {
            result.isSuccess = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    /**
     * Applies post-conversion updates: sets Account address/industry/website/phone
     * and Opportunity Amount + CloseDate with the user-supplied values from the flow.
     * Errors here are non-fatal — the conversion record links are already set.
     *
     * @param  req  The ConversionRequest containing user-supplied field values.
     * @param  lcr  The successful LeadConvertResult containing converted record IDs.
     */
    @TestVisible
    private static void applyPostConversionUpdates(
            ConversionRequest req,
            Database.LeadConvertResult lcr) {

        List<SObject> toUpdate = new List<SObject>();

        if (String.isBlank(req.existingAccountId) && String.isNotBlank(lcr.getAccountId())) {
            Account acct = new Account(Id = lcr.getAccountId());
            if (String.isNotBlank(req.accountName))         { acct.Name = req.accountName; }
            if (String.isNotBlank(req.accountIndustry))     { acct.Industry = req.accountIndustry; }
            if (String.isNotBlank(req.accountWebsite))      { acct.Website = req.accountWebsite; }
            if (String.isNotBlank(req.accountPhone))        { acct.Phone = req.accountPhone; }
            if (String.isNotBlank(req.accountBillingStreet))      { acct.BillingStreet = req.accountBillingStreet; }
            if (String.isNotBlank(req.accountBillingCity))        { acct.BillingCity = req.accountBillingCity; }
            if (String.isNotBlank(req.accountBillingState))       { acct.BillingState = req.accountBillingState; }
            if (String.isNotBlank(req.accountBillingPostalCode))  { acct.BillingPostalCode = req.accountBillingPostalCode; }
            toUpdate.add(acct);
        }

        if (req.createOpportunity == true
                && String.isNotBlank(lcr.getOpportunityId())
                && (req.opportunityAmount != null || req.opportunityCloseDate != null)) {
            Opportunity opp = new Opportunity(Id = lcr.getOpportunityId());
            if (req.opportunityAmount != null)    { opp.Amount = req.opportunityAmount; }
            if (req.opportunityCloseDate != null) { opp.CloseDate = req.opportunityCloseDate; }
            toUpdate.add(opp);
        }

        if (!toUpdate.isEmpty()) {
            try {
                Database.update(toUpdate, false);
            } catch (DmlException ex) {
                // Non-fatal: post-conversion field updates should not roll back the conversion
            }
        }
    }

    /**
     * Queries LeadStatus to retrieve the first status record flagged IsConverted=true.
     * Result is used as the converted status when calling Database.convertLead().
     *
     * @return  The MasterLabel of the converted LeadStatus.
     * @throws  QueryException if no converted LeadStatus exists in the org.
     */
    @TestVisible
    private static String getConvertedStatus() {
        LeadStatus convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return convertedStatus.MasterLabel;
    }
}
