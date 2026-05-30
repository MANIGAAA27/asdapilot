/**
 * @file        TestDataFactory.cls
 * @description Shared test data factory for the Custom Lead Conversion Screen Flow
 *              project. Provides builder-style methods for inserting Lead test
 *              records and properly converting them via Database.convertLead()
 *              so that IsConverted is set by the platform (it is a read-only
 *              system field that cannot be set via direct DML).
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-05-30
 * @lastModified 2026-05-30
 * @group       TestSupport
 *
 * @dependencies (none in this changeset)
 * @calledBy    CustomLeadConversionFlowHandlerTest
 * @testClass   (none — factory is itself @isTest-scoped via class annotation)
 */
@isTest
public class TestDataFactory {

    // ─────────────────────────────────────────────────────────────────────────
    // Lead Builders
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and inserts a basic Lead with the supplied last name.
     * Fields are populated to satisfy required-field validation in standard orgs.
     *
     * @param  leadName  Used as the Lead's LastName.
     * @return           The inserted Lead record.
     */
    public static Lead createLead(String leadName) {
        Lead lead = new Lead(
            FirstName   = 'Test',
            LastName    = leadName,
            Company     = 'Test Company',
            Email       = 'test.' + leadName.replace(' ', '').toLowerCase() + '@example.com',
            Phone       = '5555550100',
            MobilePhone = '5555550101',
            Title       = 'Manager',
            Industry    = 'Technology',
            Website     = 'https://example.com',
            Street      = '123 Main St',
            City        = 'Chicago',
            State       = 'IL',
            PostalCode  = '60601',
            Country     = 'US'
        );
        insert lead;
        return lead;
    }

    /**
     * Creates and inserts multiple Lead records for bulk-path testing.
     *
     * @param  count  Number of Lead records to create.
     * @return        List of inserted Lead records.
     */
    public static List<Lead> createLeads(Integer count) {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < count; i++) {
            leads.add(new Lead(
                FirstName = 'Bulk',
                LastName  = 'Lead ' + i,
                Company   = 'Bulk Corp ' + i,
                Email     = 'bulk.' + i + '@example.com'
            ));
        }
        insert leads;
        return leads;
    }

    /**
     * Creates, inserts, and converts a Lead so that IsConverted=true.
     * Calls Database.convertLead() because IsConverted is a platform-managed
     * read-only field that cannot be set directly via DML.
     *
     * @param  leadName  Used as the Lead's LastName.
     * @return           The re-queried Lead with Id and IsConverted populated.
     */
    public static Lead createConvertedLead(String leadName) {
        Lead lead = createLead(leadName);

        LeadStatus convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ];

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(lead.Id);
        lc.setConvertedStatus(convertedStatus.MasterLabel);
        lc.setDoNotCreateOpportunity(true);
        Database.convertLead(lc);

        return [SELECT Id, IsConverted, Status FROM Lead WHERE Id = :lead.Id];
    }
}
