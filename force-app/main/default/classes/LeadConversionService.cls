/**
 * @file              LeadConversionService.cls
 * @description       Core service for the Custom Lead Conversion feature.
 *                    Provides an invocable method for Screen Flow orchestration,
 *                    lead data retrieval with FLS enforcement, duplicate-record
 *                    matching, and fiscal quarter-end date calculation.
 *                    Delegates record creation to Database.convertLead() for
 *                    proper Salesforce conversion semantics, then applies
 *                    additional field mappings to the resulting records.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             LeadConversion
 *
 * @dependencies      (none in this changeset)
 * @calledBy          LeadConversionController, Convert_Lead_Flow
 * @testClass         LeadConversionServiceTest
 *
 * @see               LLD-001 Custom Lead Conversion (Feature: Custom Lead Conversion)
 */

/**
 * Service layer for custom Lead-to-Account/Contact/Opportunity conversion.
 *
 * Responsibilities:
 *   - Execute lead conversion via Database.convertLead().
 *   - Retrieve Lead records with field-level security enforcement.
 *   - Find matching Accounts (by company name) and Contacts (by email).
 *   - Calculate the last calendar day of the current fiscal quarter.
 *   - Apply additional field mappings post-conversion (industry, billing
 *     address, mobile phone, opportunity amount/close date).
 *
 * Threading: synchronous only — not designed for @future or Queueable contexts.
 *
 * @testClass LeadConversionServiceTest
 */
public with sharing class LeadConversionService {

    // ─────────────────────────────────────────────────────────────────────────
    //  Constants
    // ─────────────────────────────────────────────────────────────────────────
    private static final String CONVERTED_STATUS    = 'Converted';
    private static final Integer MAX_MATCHING_RECORDS = 10;

    // ─────────────────────────────────────────────────────────────────────────
    //  Invocable Method
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Invocable entry point consumed by the Convert Lead Screen Flow.
     * Converts the specified Lead using Database.convertLead() and then applies
     * the additional field mappings (Industry, Website, Phone, BillingAddress,
     * Title, MobilePhone, Amount, CloseDate) to the resulting records.
     *
     * @param  requests  List of ConversionRequest objects (the flow passes a
     *                   single-element list per standard invocable-method convention).
     * @return           Parallel list of ConversionResult objects, one per request.
     *
     * @calledBy    Convert_Lead_Flow (Apex Action flow element)
     * @testMethods test_convertLead_newRecords_success,
     *              test_convertLead_existingAccount_success,
     *              test_convertLead_noOpportunity_success,
     *              test_convertLead_nullLeadId_fails
     */
    @InvocableMethod(
        label='Convert Lead'
        description='Converts a Lead to Account, Contact, and optional Opportunity using Database.convertLead()'
    )
    public static List<ConversionResult> convertLead(List<ConversionRequest> requests) {
        List<ConversionResult> results = new List<ConversionResult>();
        for (ConversionRequest req : requests) {
            results.add(executeConversion(req));
        }
        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Public Service Methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Retrieves a Lead record with all fields required for the conversion wizard.
     * Enforces field-level security via WITH SECURITY_ENFORCED.
     *
     * @param  leadId  Salesforce Id of the Lead to retrieve.
     * @return Lead record with conversion-relevant fields populated.
     * @throws System.QueryException if the Lead is not found or inaccessible.
     *
     * @calledBy    LeadConversionController.getLeadData
     * @testMethods test_getLeadForConversion_validId_returnsLead
     */
    public static Lead getLeadForConversion(Id leadId) {
        return [
            SELECT  Id, FirstName, LastName, Name, Company, Email,
                    Phone, MobilePhone, Industry, Website, Title,
                    Conversion_Amount__c,
                    Street, City, State, PostalCode, Country,
                    IsConverted, Status
            FROM    Lead
            WHERE   Id = :leadId
            WITH    SECURITY_ENFORCED
        ];
    }

    /**
     * Finds existing Account records whose Name matches the given company name.
     * Returns an empty list when companyName is blank or no matches exist.
     *
     * @param  companyName  Value of the Lead's Company field.
     * @return List<Account> with up to 10 matches; never null.
     *
     * @calledBy    LeadConversionController.findMatchingAccounts
     * @testMethods test_findMatchingAccounts_matchFound_returnsAccounts,
     *              test_findMatchingAccounts_noMatch_returnsEmpty,
     *              test_findMatchingAccounts_blankInput_returnsEmpty
     */
    public static List<Account> findMatchingAccounts(String companyName) {
        if (String.isBlank(companyName)) {
            return new List<Account>();
        }
        return [
            SELECT  Id, Name, Industry, Website, Phone,
                    BillingStreet, BillingCity, BillingState, BillingPostalCode
            FROM    Account
            WHERE   Name = :companyName
            WITH    SECURITY_ENFORCED
            LIMIT   :MAX_MATCHING_RECORDS
        ];
    }

    /**
     * Finds existing Contact records whose Email matches the given email address.
     * Returns an empty list when email is blank or no matches exist.
     *
     * @param  email  Value of the Lead's Email field.
     * @return List<Contact> with up to 10 matches; never null.
     *
     * @calledBy    LeadConversionController.findMatchingContacts
     * @testMethods test_findMatchingContacts_matchFound_returnsContacts,
     *              test_findMatchingContacts_noMatch_returnsEmpty,
     *              test_findMatchingContacts_blankInput_returnsEmpty
     */
    public static List<Contact> findMatchingContacts(String email) {
        if (String.isBlank(email)) {
            return new List<Contact>();
        }
        return [
            SELECT  Id, Name, FirstName, LastName, Email, Phone, MobilePhone,
                    Title, AccountId, Account.Name
            FROM    Contact
            WHERE   Email = :email
            WITH    SECURITY_ENFORCED
            LIMIT   :MAX_MATCHING_RECORDS
        ];
    }

    /**
     * Calculates the last calendar day of the current quarter.
     * Quarter definitions: Q1=Jan–Mar (31st), Q2=Apr–Jun (30th),
     *                      Q3=Jul–Sep (30th), Q4=Oct–Dec (31st).
     *
     * @return Date representing the last day of the current fiscal quarter.
     *
     * @calledBy    LeadConversionController.getQuarterEndDate
     * @testMethods test_getQuarterEndDate_q1_returnsMarThirtyFirst,
     *              test_getQuarterEndDate_q2_returnsJunThirtieth,
     *              test_getQuarterEndDate_q3_returnsSepThirtieth,
     *              test_getQuarterEndDate_q4_returnsDecThirtyFirst
     */
    public static Date getQuarterEndDate() {
        Integer currentMonth = Date.today().month();
        Integer currentYear  = Date.today().year();
        Integer quarterEndMonth = (Integer) Math.ceil(currentMonth / 3.0) * 3;
        Integer daysInMonth = Date.daysInMonth(currentYear, quarterEndMonth);
        return Date.newInstance(currentYear, quarterEndMonth, daysInMonth);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Private Implementation
    // ─────────────────────────────────────────────────────────────────────────

    /** Executes a single lead conversion request and returns the result. */
    private static ConversionResult executeConversion(ConversionRequest req) {
        ConversionResult result = new ConversionResult();
        try {
            validateConversionRequest(req);

            Database.LeadConvert lc = buildLeadConvert(req);
            Database.LeadConvertResult lcr = Database.convertLead(lc);

            if (!lcr.isSuccess()) {
                result.success = false;
                result.errorMessage = buildErrorMessage(lcr.getErrors());
                return result;
            }

            result.success              = true;
            result.convertedAccountId   = lcr.getAccountId();
            result.convertedContactId   = lcr.getContactId();
            result.convertedOpportunityId = lcr.getOpportunityId();

            applyAdditionalFieldMappings(req, lcr);

        } catch (LeadConversionServiceException svcEx) {
            result.success      = false;
            result.errorMessage = svcEx.getMessage();
        } catch (Exception ex) {
            result.success      = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    /** Validates that the minimum required fields are present on the request. */
    private static void validateConversionRequest(ConversionRequest req) {
        if (req == null || req.leadId == null) {
            throw new LeadConversionServiceException('Lead ID is required for conversion.');
        }
    }

    /**
     * Constructs a Database.LeadConvert instance from the user-supplied request.
     * When useExistingAccount is true and an existingAccountId is provided, the
     * conversion reuses that account instead of creating a new one.
     * When createOpportunity is false or null, opportunity creation is suppressed.
     */
    private static Database.LeadConvert buildLeadConvert(ConversionRequest req) {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(req.leadId);
        lc.setConvertedStatus(CONVERTED_STATUS);

        if (req.useExistingAccount == true && req.existingAccountId != null) {
            lc.setAccountId(req.existingAccountId);
        }

        if (req.useExistingContact == true && req.existingContactId != null) {
            lc.setContactId(req.existingContactId);
        }

        Boolean skipOpportunity = (req.createOpportunity == null || req.createOpportunity == false);
        lc.setDoNotCreateOpportunity(skipOpportunity);

        if (!skipOpportunity && String.isNotBlank(req.opportunityName)) {
            lc.setOpportunityName(req.opportunityName);
        }

        return lc;
    }

    /**
     * Applies Lead-to-Account, Lead-to-Contact, and Lead-to-Opportunity field
     * mappings that are not handled natively by Database.convertLead().
     * Executes a single bulkified Database.update() call for all affected records.
     *
     * Field mappings applied:
     *   Account: Industry, Website, Phone, BillingStreet/City/State/PostalCode, Name (override)
     *   Contact: Title, MobilePhone
     *   Opportunity: Amount, CloseDate
     */
    private static void applyAdditionalFieldMappings(
        ConversionRequest req,
        Database.LeadConvertResult lcr
    ) {
        List<SObject> recordsToUpdate = new List<SObject>();

        if (req.useExistingAccount != true && lcr.getAccountId() != null) {
            Account acct = new Account(Id = lcr.getAccountId());
            if (String.isNotBlank(req.newAccountName)) {
                acct.Name = req.newAccountName;
            }
            acct.Industry       = req.leadIndustry;
            acct.Website        = req.leadWebsite;
            acct.Phone          = req.leadPhone;
            acct.BillingStreet  = req.leadBillingStreet;
            acct.BillingCity    = req.leadBillingCity;
            acct.BillingState   = req.leadBillingState;
            acct.BillingPostalCode = req.leadBillingPostalCode;
            recordsToUpdate.add(acct);
        }

        if (req.useExistingContact != true && lcr.getContactId() != null) {
            Contact con = new Contact(Id = lcr.getContactId());
            con.Title       = req.leadTitle;
            con.MobilePhone = req.leadMobilePhone;
            recordsToUpdate.add(con);
        }

        if (req.createOpportunity == true && lcr.getOpportunityId() != null) {
            Opportunity opp = new Opportunity(Id = lcr.getOpportunityId());
            if (req.opportunityAmount != null) {
                opp.Amount = req.opportunityAmount;
            }
            if (req.opportunityCloseDate != null) {
                opp.CloseDate = req.opportunityCloseDate;
            }
            recordsToUpdate.add(opp);
        }

        if (!recordsToUpdate.isEmpty()) {
            Database.update(recordsToUpdate, false);
        }
    }

    /** Concatenates Database.Error messages into a single readable string. */
    private static String buildErrorMessage(List<Database.Error> errors) {
        List<String> messages = new List<String>();
        for (Database.Error err : errors) {
            messages.add(err.getMessage());
        }
        return String.join(messages, '; ');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Inner Classes — Request / Response / Exception
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Input parameter wrapper for the convertLead @InvocableMethod.
     * All fields correspond directly to Flow variable assignments.
     */
    public class ConversionRequest {

        @InvocableVariable(required=true label='Lead ID')
        public Id leadId;

        @InvocableVariable(label='Use Existing Account')
        public Boolean useExistingAccount;

        @InvocableVariable(label='Existing Account ID')
        public Id existingAccountId;

        @InvocableVariable(label='New Account Name')
        public String newAccountName;

        @InvocableVariable(label='Lead Industry')
        public String leadIndustry;

        @InvocableVariable(label='Lead Website')
        public String leadWebsite;

        @InvocableVariable(label='Lead Phone')
        public String leadPhone;

        @InvocableVariable(label='Lead Billing Street')
        public String leadBillingStreet;

        @InvocableVariable(label='Lead Billing City')
        public String leadBillingCity;

        @InvocableVariable(label='Lead Billing State')
        public String leadBillingState;

        @InvocableVariable(label='Lead Billing Postal Code')
        public String leadBillingPostalCode;

        @InvocableVariable(label='Use Existing Contact')
        public Boolean useExistingContact;

        @InvocableVariable(label='Existing Contact ID')
        public Id existingContactId;

        @InvocableVariable(label='Lead Title')
        public String leadTitle;

        @InvocableVariable(label='Lead Mobile Phone')
        public String leadMobilePhone;

        @InvocableVariable(label='Create Opportunity')
        public Boolean createOpportunity;

        @InvocableVariable(label='Opportunity Name')
        public String opportunityName;

        @InvocableVariable(label='Opportunity Amount')
        public Decimal opportunityAmount;

        @InvocableVariable(label='Opportunity Close Date')
        public Date opportunityCloseDate;
    }

    /**
     * Output parameter wrapper for the convertLead @InvocableMethod.
     * Consumed by the Convert Lead Flow to determine post-conversion navigation.
     */
    public class ConversionResult {

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        @InvocableVariable(label='Converted Account ID')
        public Id convertedAccountId;

        @InvocableVariable(label='Converted Contact ID')
        public Id convertedContactId;

        @InvocableVariable(label='Converted Opportunity ID')
        public Id convertedOpportunityId;
    }

    /** Custom exception surfaced to the flow and controller on validation failures. */
    public class LeadConversionServiceException extends Exception {}
}