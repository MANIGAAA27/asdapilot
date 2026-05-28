/**
 * @file              LeadConversionService.cls
 * @description       Service layer encapsulating all Lead conversion business logic.
 *                    Handles field mapping, record creation/association, Lead status
 *                    update, and relationship establishment. Enforces FLS via
 *                    Security.stripInaccessible and respects sharing rules.
 * @author            ASDA Dev Agent
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             LeadConversion
 *
 * @dependencies      LeadConversionException
 * @calledBy          LeadConversionController
 * @testClass         LeadConversionServiceTest
 *
 * @see               LLD - LWC Lead Conversion (Keneland Technology)
 */
public with sharing class LeadConversionService {

    // ─────────────────────────────────────────────────────────────────────────
    // Inner wrapper classes
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Wrapper returned to the LWC containing the Lead record and pre-mapped
     * field values for Account, Contact, and Opportunity.
     */
    public class LeadData {
        @AuraEnabled public Lead leadRecord { get; set; }
        @AuraEnabled public AccountFields accountFields { get; set; }
        @AuraEnabled public ContactFields contactFields { get; set; }
        @AuraEnabled public OpportunityFields opportunityFields { get; set; }
        @AuraEnabled public Date fiscalQuarterEndDate { get; set; }
    }

    /** Mapped Account field values derived from the Lead. */
    public class AccountFields {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String industry { get; set; }
        @AuraEnabled public String website { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String billingStreet { get; set; }
        @AuraEnabled public String billingCity { get; set; }
        @AuraEnabled public String billingState { get; set; }
        @AuraEnabled public String billingPostalCode { get; set; }
    }

    /** Mapped Contact field values derived from the Lead. */
    public class ContactFields {
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String mobilePhone { get; set; }
    }

    /** Mapped Opportunity field values derived from the Lead. */
    public class OpportunityFields {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Date closeDate { get; set; }
    }

    /**
     * Request payload sent from the LWC when the user clicks Convert.
     * All Id fields are nullable — null means "create new".
     */
    public class ConversionRequest {
        @AuraEnabled public Id leadId { get; set; }

        // Account
        @AuraEnabled public Id existingAccountId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String accountIndustry { get; set; }
        @AuraEnabled public String accountWebsite { get; set; }
        @AuraEnabled public String accountPhone { get; set; }
        @AuraEnabled public String accountBillingStreet { get; set; }
        @AuraEnabled public String accountBillingCity { get; set; }
        @AuraEnabled public String accountBillingState { get; set; }
        @AuraEnabled public String accountBillingPostalCode { get; set; }

        // Contact
        @AuraEnabled public Id existingContactId { get; set; }
        @AuraEnabled public String contactFirstName { get; set; }
        @AuraEnabled public String contactLastName { get; set; }
        @AuraEnabled public String contactTitle { get; set; }
        @AuraEnabled public String contactEmail { get; set; }
        @AuraEnabled public String contactMobilePhone { get; set; }

        // Opportunity
        @AuraEnabled public Boolean createOpportunity { get; set; }
        @AuraEnabled public Id existingOpportunityId { get; set; }
        @AuraEnabled public String opportunityName { get; set; }
        @AuraEnabled public Decimal opportunityAmount { get; set; }
        @AuraEnabled public Date opportunityCloseDate { get; set; }
    }

    /**
     * Result returned to the LWC after a successful conversion.
     */
    public class ConversionResult {
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public String contactName { get; set; }
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public String opportunityName { get; set; }
        @AuraEnabled public Boolean opportunityCreated { get; set; }
        @AuraEnabled public String successMessage { get; set; }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public service methods
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Loads the Lead record and builds pre-mapped field wrappers for the modal.
     *
     * @param  leadId   Id of the Lead to load.
     * @return          LeadData wrapper with mapped fields.
     * @throws          LeadConversionException when Lead not found or already converted.
     *
     * @calledBy    LeadConversionController.getLeadData
     * @testMethods test_getLeadData_validId_returnsWrapper, test_getLeadData_convertedLead_throws,
     *              test_getLeadData_notFound_throws
     */
    public static LeadData getLeadData(Id leadId) {
        if (leadId == null) {
            throw new LeadConversionException('Lead Id is required.');
        }

        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Company, Title, Email, Phone,
                   MobilePhone, Industry, Website, Street, City, State,
                   PostalCode, IsConverted, Status
            FROM Lead
            WHERE Id = :leadId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (leads.isEmpty()) {
            throw new LeadConversionException('Lead record not found.');
        }

        Lead leadRecord = leads[0];

        if (leadRecord.IsConverted) {
            throw new LeadConversionException('This Lead has already been converted.');
        }

        LeadData data = new LeadData();
        data.leadRecord = leadRecord;
        data.accountFields = buildAccountFields(leadRecord);
        data.contactFields = buildContactFields(leadRecord);
        data.opportunityFields = buildOpportunityFields(leadRecord);
        data.fiscalQuarterEndDate = getFiscalQuarterEndDate();

        return data;
    }

    /**
     * Executes the full Lead conversion: creates or links Account, Contact,
     * and optionally Opportunity, then marks the Lead as Converted.
     *
     * @param  req   ConversionRequest populated by the LWC modal.
     * @return       ConversionResult with Ids and names of created/linked records.
     * @throws       LeadConversionException on validation or DML failure.
     *
     * @calledBy    LeadConversionController.convertLead
     * @testMethods test_convertLead_newRecords_succeeds, test_convertLead_existingAccount_succeeds,
     *              test_convertLead_skipOpportunity_succeeds, test_convertLead_missingRequired_throws
     */
    public static ConversionResult convertLead(ConversionRequest req) {
        validateConversionRequest(req);

        Savepoint sp = Database.setSavepoint();
        try {
            // Step 1 — Account
            Id accountId = resolveAccount(req);

            // Step 2 — Contact
            Id contactId = resolveContact(req, accountId);

            // Step 3 — Opportunity (optional)
            Id opportunityId = null;
            Boolean oppCreated = false;
            if (req.createOpportunity == true) {
                if (req.existingOpportunityId != null) {
                    opportunityId = req.existingOpportunityId;
                } else {
                    opportunityId = createOpportunity(req, accountId);
                    oppCreated = true;
                }
            }

            // Step 4 — Mark Lead converted
            markLeadConverted(req.leadId, accountId, contactId, opportunityId);

            // Build result
            ConversionResult result = new ConversionResult();
            result.accountId = accountId;
            result.contactId = contactId;
            result.opportunityId = opportunityId;
            result.opportunityCreated = oppCreated;
            result.successMessage = buildSuccessMessage(oppCreated);

            // Populate display names
            populateResultNames(result);

            return result;

        } catch (LeadConversionException lce) {
            Database.rollback(sp);
            throw lce;
        } catch (Exception ex) {
            Database.rollback(sp);
            throw new LeadConversionException('Conversion failed: ' + ex.getMessage());
        }
    }

    /**
     * Returns the last day of the current fiscal quarter.
     * Fiscal quarters are calendar-aligned (Q1=Jan-Mar, Q2=Apr-Jun,
     * Q3=Jul-Sep, Q4=Oct-Dec).
     *
     * @return  Date — last day of the current fiscal quarter.
     *
     * @calledBy    LeadConversionController.getFiscalQuarterEndDate, getLeadData
     * @testMethods test_getFiscalQuarterEndDate_returnsLastDayOfQuarter
     */
    public static Date getFiscalQuarterEndDate() {
        Date today = Date.today();
        Integer month = today.month();
        Integer year = today.year();

        // Determine quarter end month
        Integer quarterEndMonth;
        if (month <= 3) {
            quarterEndMonth = 3;
        } else if (month <= 6) {
            quarterEndMonth = 6;
        } else if (month <= 9) {
            quarterEndMonth = 9;
        } else {
            quarterEndMonth = 12;
        }

        // Last day of the quarter end month
        Integer lastDay = Date.daysInMonth(year, quarterEndMonth);
        return Date.newInstance(year, quarterEndMonth, lastDay);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Builds AccountFields wrapper from a Lead record. */
    private static AccountFields buildAccountFields(Lead leadRecord) {
        AccountFields af = new AccountFields();
        af.name = leadRecord.Company;
        af.industry = leadRecord.Industry;
        af.website = leadRecord.Website;
        af.phone = leadRecord.Phone;
        af.billingStreet = leadRecord.Street;
        af.billingCity = leadRecord.City;
        af.billingState = leadRecord.State;
        af.billingPostalCode = leadRecord.PostalCode;
        return af;
    }

    /** Builds ContactFields wrapper from a Lead record. */
    private static ContactFields buildContactFields(Lead leadRecord) {
        ContactFields cf = new ContactFields();
        cf.firstName = leadRecord.FirstName;
        cf.lastName = leadRecord.LastName;
        cf.title = leadRecord.Title;
        cf.email = leadRecord.Email;
        cf.mobilePhone = leadRecord.MobilePhone;
        return cf;
    }

    /**
     * Builds OpportunityFields wrapper from a Lead record.
     * Amount defaults to null — the user can enter it in the modal.
     * The Lead.Amount__c custom field is intentionally omitted here to avoid
     * a compile-time field-existence dependency; the field is still deployed
     * via objects/Lead/fields/Amount__c.field-meta.xml and can be wired in
     * once confirmed present in the target org.
     */
    private static OpportunityFields buildOpportunityFields(Lead leadRecord) {
        OpportunityFields oppFields = new OpportunityFields();
        oppFields.name = leadRecord.Company;
        oppFields.amount = null;
        oppFields.closeDate = getFiscalQuarterEndDate();
        return oppFields;
    }

    /** Validates required fields on the ConversionRequest. */
    private static void validateConversionRequest(ConversionRequest req) {
        if (req == null) {
            throw new LeadConversionException('Conversion request is required.');
        }
        if (req.leadId == null) {
            throw new LeadConversionException('Lead Id is required.');
        }
        if (req.existingAccountId == null && String.isBlank(req.accountName)) {
            throw new LeadConversionException('Account Name is required when creating a new Account.');
        }
        if (req.existingContactId == null && String.isBlank(req.contactLastName)) {
            throw new LeadConversionException('Contact Last Name is required when creating a new Contact.');
        }
        if (req.createOpportunity == true
                && req.existingOpportunityId == null
                && String.isBlank(req.opportunityName)) {
            throw new LeadConversionException('Opportunity Name is required when creating a new Opportunity.');
        }
    }

    /**
     * Returns an existing Account Id or creates a new Account and returns its Id.
     */
    private static Id resolveAccount(ConversionRequest req) {
        if (req.existingAccountId != null) {
            return req.existingAccountId;
        }

        Account acct = new Account();
        acct.Name = req.accountName;
        acct.Industry = req.accountIndustry;
        acct.Website = req.accountWebsite;
        acct.Phone = req.accountPhone;
        acct.BillingStreet = req.accountBillingStreet;
        acct.BillingCity = req.accountBillingCity;
        acct.BillingState = req.accountBillingState;
        acct.BillingPostalCode = req.accountBillingPostalCode;

        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<Account>{ acct });
        List<Account> sanitised = (List<Account>) decision.getRecords();
        insert sanitised;
        return sanitised[0].Id;
    }

    /**
     * Returns an existing Contact Id or creates a new Contact and returns its Id.
     */
    private static Id resolveContact(ConversionRequest req, Id accountId) {
        if (req.existingContactId != null) {
            return req.existingContactId;
        }

        Contact con = new Contact();
        con.FirstName = req.contactFirstName;
        con.LastName = req.contactLastName;
        con.Title = req.contactTitle;
        con.Email = req.contactEmail;
        con.MobilePhone = req.contactMobilePhone;
        con.AccountId = accountId;

        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<Contact>{ con });
        List<Contact> sanitised = (List<Contact>) decision.getRecords();
        insert sanitised;
        return sanitised[0].Id;
    }

    /**
     * Creates a new Opportunity and returns its Id.
     */
    private static Id createOpportunity(ConversionRequest req, Id accountId) {
        Opportunity opp = new Opportunity();
        opp.Name = req.opportunityName;
        opp.AccountId = accountId;
        opp.Amount = req.opportunityAmount;
        opp.CloseDate = req.opportunityCloseDate != null
            ? req.opportunityCloseDate
            : getFiscalQuarterEndDate();
        opp.StageName = 'Prospecting';

        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<Opportunity>{ opp });
        List<Opportunity> sanitised = (List<Opportunity>) decision.getRecords();
        insert sanitised;
        return sanitised[0].Id;
    }

    /**
     * Updates the Lead record to mark it as Converted using the standard
     * Database.convertLead API.
     */
    private static void markLeadConverted(
            Id leadId, Id accountId, Id contactId, Id opportunityId) {

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadId);
        lc.setAccountId(accountId);
        lc.setContactId(contactId);
        lc.setDoNotCreateOpportunity(opportunityId == null);
        if (opportunityId != null) {
            lc.setOpportunityId(opportunityId);
        }

        LeadStatus convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ];
        lc.setConvertedStatus(convertedStatus.MasterLabel);

        List<Database.LeadConvertResult> results =
            Database.convertLead(new List<Database.LeadConvert>{ lc });

        for (Database.LeadConvertResult lcr : results) {
            if (!lcr.isSuccess()) {
                String errorMsg = '';
                for (Database.Error err : lcr.getErrors()) {
                    errorMsg += err.getMessage() + ' ';
                }
                throw new LeadConversionException('Lead conversion failed: ' + errorMsg.trim());
            }
        }
    }

    /** Populates display names on the ConversionResult for the success toast. */
    private static void populateResultNames(ConversionResult result) {
        if (result.accountId != null) {
            List<Account> accts = [SELECT Name FROM Account WHERE Id = :result.accountId LIMIT 1];
            if (!accts.isEmpty()) {
                result.accountName = accts[0].Name;
            }
        }
        if (result.contactId != null) {
            List<Contact> cons = [
                SELECT Name FROM Contact WHERE Id = :result.contactId LIMIT 1
            ];
            if (!cons.isEmpty()) {
                result.contactName = cons[0].Name;
            }
        }
        if (result.opportunityId != null) {
            List<Opportunity> opps = [
                SELECT Name FROM Opportunity WHERE Id = :result.opportunityId LIMIT 1
            ];
            if (!opps.isEmpty()) {
                result.opportunityName = opps[0].Name;
            }
        }
    }

    /** Builds a user-friendly success message. */
    private static String buildSuccessMessage(Boolean oppCreated) {
        String msg = 'Lead successfully converted. Account and Contact records have been created or linked.';
        if (oppCreated) {
            msg += ' An Opportunity has also been created.';
        }
        return msg;
    }
}
