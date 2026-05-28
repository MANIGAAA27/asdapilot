/**
 * @file              LeadConversionController.cls
 * @description       AuraEnabled controller that serves as the entry point for the
 *                    LWC Lead Conversion modal. Delegates all business logic to
 *                    LeadConversionService and LeadMatchingUtil. Enforces with sharing
 *                    to respect org-level record visibility.
 * @author            ASDA Dev Agent
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             LeadConversion
 *
 * @dependencies      LeadConversionService, LeadMatchingUtil, LeadConversionException
 * @calledBy          (none in this changeset — called by LWC leadConversionModal via @salesforce/apex)
 * @testClass         LeadConversionControllerTest
 *
 * @see               LLD - LWC Lead Conversion (Keneland Technology)
 */
public with sharing class LeadConversionController {

    /**
     * Retrieves the Lead record with all fields required for the conversion modal,
     * applying FLS via Security.stripInaccessible.
     *
     * @param  leadId   Id of the Lead record to load.
     * @return          LeadConversionService.LeadData wrapper containing the Lead and
     *                  pre-mapped field values for Account, Contact, and Opportunity.
     * @throws          LeadConversionException when the Lead is not found or already converted.
     *
     * @calledBy    leadConversionModal LWC (connectedCallback)
     * @testMethods test_getLeadData_validId_returnsWrapper, test_getLeadData_convertedLead_throws
     */
    @AuraEnabled(cacheable=true)
    public static LeadConversionService.LeadData getLeadData(Id leadId) {
        try {
            return LeadConversionService.getLeadData(leadId);
        } catch (LeadConversionException lce) {
            throw new AuraHandledException(lce.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Unexpected error loading Lead: ' + ex.getMessage());
        }
    }

    /**
     * Searches for existing Account records matching the supplied criteria.
     * Used by the RecordSearchComponent sub-component.
     *
     * @param  searchRequest   JSON-serialised LeadMatchingUtil.AccountSearchRequest.
     * @return                 List of LeadMatchingUtil.MatchResult wrappers.
     *
     * @calledBy    recordSearchComponent LWC
     * @testMethods test_searchAccounts_byName_returnsMatches, test_searchAccounts_noMatch_returnsEmpty
     */
    @AuraEnabled(cacheable=false)
    public static List<LeadMatchingUtil.MatchResult> searchAccounts(String searchRequest) {
        try {
            LeadMatchingUtil.AccountSearchRequest req =
                (LeadMatchingUtil.AccountSearchRequest) JSON.deserialize(
                    searchRequest, LeadMatchingUtil.AccountSearchRequest.class);
            return LeadMatchingUtil.findMatchingAccounts(req);
        } catch (LeadConversionException lce) {
            throw new AuraHandledException(lce.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Error searching Accounts: ' + ex.getMessage());
        }
    }

    /**
     * Searches for existing Contact records matching the supplied criteria.
     *
     * @param  searchRequest   JSON-serialised LeadMatchingUtil.ContactSearchRequest.
     * @return                 List of LeadMatchingUtil.MatchResult wrappers.
     *
     * @calledBy    recordSearchComponent LWC
     * @testMethods test_searchContacts_byEmail_returnsMatches, test_searchContacts_noMatch_returnsEmpty
     */
    @AuraEnabled(cacheable=false)
    public static List<LeadMatchingUtil.MatchResult> searchContacts(String searchRequest) {
        try {
            LeadMatchingUtil.ContactSearchRequest req =
                (LeadMatchingUtil.ContactSearchRequest) JSON.deserialize(
                    searchRequest, LeadMatchingUtil.ContactSearchRequest.class);
            return LeadMatchingUtil.findMatchingContacts(req);
        } catch (LeadConversionException lce) {
            throw new AuraHandledException(lce.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Error searching Contacts: ' + ex.getMessage());
        }
    }

    /**
     * Executes the Lead conversion using the supplied conversion request.
     * Delegates to LeadConversionService.convertLead.
     *
     * @param  conversionRequest   JSON-serialised LeadConversionService.ConversionRequest.
     * @return                     LeadConversionService.ConversionResult with Ids of created/linked records.
     * @throws                     AuraHandledException on any failure.
     *
     * @calledBy    leadConversionModal LWC (handleConvert)
     * @testMethods test_convertLead_newRecords_succeeds, test_convertLead_existingAccount_succeeds,
     *              test_convertLead_missingRequired_throws
     */
    @AuraEnabled(cacheable=false)
    public static LeadConversionService.ConversionResult convertLead(String conversionRequest) {
        try {
            LeadConversionService.ConversionRequest req =
                (LeadConversionService.ConversionRequest) JSON.deserialize(
                    conversionRequest, LeadConversionService.ConversionRequest.class);
            return LeadConversionService.convertLead(req);
        } catch (LeadConversionException lce) {
            throw new AuraHandledException(lce.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Conversion failed: ' + ex.getMessage());
        }
    }

    /**
     * Returns the last day of the current fiscal quarter as a Date.
     * Used to pre-populate the Opportunity CloseDate in the modal.
     *
     * @return  Date representing the last day of the current fiscal quarter.
     *
     * @calledBy    leadConversionModal LWC (connectedCallback)
     * @testMethods test_getFiscalQuarterEndDate_returnsLastDayOfQuarter
     */
    @AuraEnabled(cacheable=true)
    public static Date getFiscalQuarterEndDate() {
        return LeadConversionService.getFiscalQuarterEndDate();
    }
}
