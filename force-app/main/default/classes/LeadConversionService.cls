/**
 * @file              LeadConversionService.cls
 * @description       Invocable Apex service that converts a Lead record into Account,
 *                    Contact, and optional Opportunity records, replicating the standard
 *                    Salesforce LEX lead conversion process with full field mapping control.
 *                    Designed to be called from the Lead_Conversion_Screen_Flow screen flow.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             LeadManagement
 *
 * @dependencies      (none in this changeset)
 * @calledBy          Lead_Conversion_Screen_Flow (Flow apex action)
 * @testClass         LeadConversionServiceTest
 *
 * @see               LLD - Salesforce Flows for Lead Conversion
 */

/**
 * Service providing Lead-to-Account/Contact/Opportunity conversion logic
 * via a single @InvocableMethod entry point.
 *
 * Responsibilities:
 *   - Accept conversion parameters collected by the Lead Conversion Screen Flow.
 *   - Resolve or create Account, Contact, and Opportunity with accurate field mapping.
 *   - Invoke Database.convertLead() to mark the Lead IsConverted and link child records.
 *   - Return IDs of the resulting records plus success/error state.
 *
 * Threading: Synchronous only — invoked from Screen Flow action; not batch-safe.
 *
 * @testClass LeadConversionServiceTest
 */
public with sharing class LeadConversionService {

    /** Sentinel string passed by the Flow to indicate "create a new record". */
    @TestVisible
    private static final String NEW_RECORD_SENTINEL = 'new';

    // ─────────────────────────────────────────────────────────────────────────
    // Inner request / result classes
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Input envelope for the Lead conversion invocable action.
     * Every field maps to a Flow variable or screen-component output.
     */
    public class ConversionRequest {
        @InvocableVariable(required=true label='Lead ID')
        public Id leadId;

        /** ID of an existing Account, or the sentinel value "new". */
        @InvocableVariable(label='Account Choice (record ID or "new")')
        public String accountChoice;

        @InvocableVariable(label='New Account Name')
        public String newAccountName;

        @InvocableVariable(label='New Account Industry')
        public String newAccountIndustry;

        @InvocableVariable(label='New Account Website')
        public String newAccountWebsite;

        @InvocableVariable(label='New Account Phone')
        public String newAccountPhone;

        @InvocableVariable(label='New Account Billing Street')
        public String newAccountBillingStreet;

        @InvocableVariable(label='New Account Billing City')
        public String newAccountBillingCity;

        @InvocableVariable(label='New Account Billing State')
        public String newAccountBillingState;

        @InvocableVariable(label='New Account Billing Postal Code')
        public String newAccountBillingPostalCode;

        /** ID of an existing Contact, or the sentinel value "new". */
        @InvocableVariable(label='Contact Choice (record ID or "new")')
        public String contactChoice;

        @InvocableVariable(label='New Contact First Name')
        public String newContactFirstName;

        @InvocableVariable(label='New Contact Last Name')
        public String newContactLastName;

        @InvocableVariable(label='New Contact Title')
        public String newContactTitle;

        @InvocableVariable(label='New Contact Email')
        public String newContactEmail;

        @InvocableVariable(label='New Contact Mobile Phone')
        public String newContactMobilePhone;

        @InvocableVariable(label='Create Opportunity')
        public Boolean createOpportunity;

        @InvocableVariable(label='Opportunity Name')
        public String opportunityName;

        @InvocableVariable(label='Opportunity Close Date')
        public Date opportunityCloseDate;

        @InvocableVariable(label='Opportunity Amount')
        public Decimal opportunityAmount;
    }

    /**
     * Output envelope returned to the Flow after conversion completes.
     */
    public class ConversionResult {
        @InvocableVariable(label='Converted Account ID')
        public Id accountId;

        @InvocableVariable(label='Converted Contact ID')
        public Id contactId;

        @InvocableVariable(label='Converted Opportunity ID')
        public Id opportunityId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Invocable entry point
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Converts a Lead into Account, Contact, and optional Opportunity records.
     *
     * Process:
     * 1. Resolve or create the target Account from mapped Lead fields.
     * 2. Resolve or create the target Contact linked to the Account.
     * 3. Call Database.convertLead() with doNotCreateOpportunity=true so this
     *    service retains full control over Opportunity field mapping.
     * 4. Optionally insert an Opportunity mapped from the Lead, linked to the Account.
     *
     * @param  requests  Single-element list supplied by the Flow runtime.
     * @return           Single-element list carrying IDs and success/error state.
     *
     * @calledBy  Lead_Conversion_Screen_Flow
     * @testMethods test_convertLead_newAccountNewContact_succeeds,
     *              test_convertLead_existingAccount_succeeds,
     *              test_convertLead_noOpportunity_succeeds,
     *              test_convertLead_existingContact_succeeds
     */
    @InvocableMethod(
        label='Convert Lead'
        description='Converts a Lead into Account, Contact, and Opportunity records.'
    )
    public static List<ConversionResult> convertLead(List<ConversionRequest> requests) {
        List<ConversionResult> results = new List<ConversionResult>();
        for (ConversionRequest req : requests) {
            results.add(processConversion(req));
        }
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Orchestrates a single Lead conversion and wraps any exception in the result. */
    private static ConversionResult processConversion(ConversionRequest req) {
        ConversionResult res = new ConversionResult();
        try {
            Id resolvedAccountId = resolveAccount(req);
            Id resolvedContactId = resolveContact(req, resolvedAccountId);

            String convertedStatus = getConvertedStatus();
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(req.leadId);
            lc.setConvertedStatus(convertedStatus);
            lc.setAccountId(resolvedAccountId);
            lc.setContactId(resolvedContactId);
            lc.setDoNotCreateOpportunity(true);

            Database.LeadConvertResult lcr = Database.convertLead(lc);
            if (!lcr.isSuccess()) {
                res.isSuccess = false;
                res.errorMessage = lcr.getErrors()[0].getMessage();
                return res;
            }

            Id opportunityId = null;
            if (req.createOpportunity == true) {
                opportunityId = createOpportunity(req, lcr.getAccountId());
            }

            res.isSuccess      = true;
            res.accountId      = lcr.getAccountId();
            res.contactId      = lcr.getContactId();
            res.opportunityId  = opportunityId;

        } catch (Exception ex) {
            res.isSuccess   = false;
            res.errorMessage = ex.getMessage();
        }
        return res;
    }

    /**
     * Returns the existing Account Id from the request, or inserts a new Account
     * from the mapped Lead fields.
     *
     * @param  req  Conversion request carrying choice and new-account field values.
     * @return      Salesforce Id of the resolved Account.
     */
    private static Id resolveAccount(ConversionRequest req) {
        if (String.isNotBlank(req.accountChoice) && req.accountChoice != NEW_RECORD_SENTINEL) {
            return (Id) req.accountChoice;
        }
        Account acct = new Account(
            Name              = req.newAccountName,
            Industry          = req.newAccountIndustry,
            Website           = req.newAccountWebsite,
            Phone             = req.newAccountPhone,
            BillingStreet     = req.newAccountBillingStreet,
            BillingCity       = req.newAccountBillingCity,
            BillingState      = req.newAccountBillingState,
            BillingPostalCode = req.newAccountBillingPostalCode
        );
        insert acct;
        return acct.Id;
    }

    /**
     * Returns the existing Contact Id from the request, or inserts a new Contact
     * from the mapped Lead fields linked to the given Account.
     *
     * @param  req        Conversion request carrying choice and new-contact field values.
     * @param  accountId  The resolved Account Id to associate the new Contact with.
     * @return            Salesforce Id of the resolved Contact.
     */
    private static Id resolveContact(ConversionRequest req, Id accountId) {
        if (String.isNotBlank(req.contactChoice) && req.contactChoice != NEW_RECORD_SENTINEL) {
            return (Id) req.contactChoice;
        }
        Contact con = new Contact(
            FirstName   = req.newContactFirstName,
            LastName    = req.newContactLastName,
            Title       = req.newContactTitle,
            Email       = req.newContactEmail,
            MobilePhone = req.newContactMobilePhone,
            AccountId   = accountId
        );
        insert con;
        return con.Id;
    }

    /**
     * Inserts an Opportunity from the mapped Lead fields and links it to the Account.
     *
     * @param  req        Conversion request with opportunity field values.
     * @param  accountId  The resolved Account Id.
     * @return            New Opportunity Id.
     */
    private static Id createOpportunity(ConversionRequest req, Id accountId) {
        String oppName = String.isBlank(req.opportunityName)
            ? 'Converted Lead Opportunity'
            : req.opportunityName;
        Date closeDate = req.opportunityCloseDate != null
            ? req.opportunityCloseDate
            : Date.today().addDays(90);

        Opportunity opp = new Opportunity(
            Name      = oppName,
            AccountId = accountId,
            StageName = getDefaultOpportunityStage(),
            CloseDate = closeDate,
            Amount    = req.opportunityAmount
        );
        insert opp;
        return opp.Id;
    }

    /** Returns the MasterLabel of the first active converted LeadStatus. */
    private static String getConvertedStatus() {
        List<LeadStatus> statuses = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (statuses.isEmpty()) {
            throw new LeadConversionServiceException('No converted Lead Status found in this org.');
        }
        return statuses[0].MasterLabel;
    }

    /** Returns the MasterLabel of the first active Opportunity Stage, ordered by SortOrder. */
    private static String getDefaultOpportunityStage() {
        List<OpportunityStage> stages = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsActive = true
            WITH SECURITY_ENFORCED
            ORDER BY SortOrder ASC
            LIMIT 1
        ];
        if (stages.isEmpty()) {
            throw new LeadConversionServiceException('No active Opportunity Stage found in this org.');
        }
        return stages[0].MasterLabel;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Custom exception
    // ─────────────────────────────────────────────────────────────────────────

    /** Thrown when the org is not configured correctly for Lead conversion. */
    public class LeadConversionServiceException extends Exception {}
}