/**
 * @file              LeadContactHandler.cls
 * @description       Handler class for the LeadAfterInsertTrigger. Processes newly
 *                    inserted Lead records and creates a corresponding Contact record
 *                    for each Lead using the defined field mapping:
 *                    Lead.FirstName → Contact.FirstName
 *                    Lead.LastName  → Contact.LastName
 *                    Lead.Email     → Contact.Email
 *                    Lead.Phone     → Contact.Phone
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             LeadAutomation
 *
 * @dependencies      (none)
 * @calledBy          LeadAfterInsertTrigger
 * @testClass         LeadContactHandlerTest
 *
 * @see               LLD - Lead Automation (Feature: Lead Automation)
 */

/**
 * Handles Contact creation logic triggered by new Lead insertions.
 *
 * Responsibilities:
 *   - Accept a bulk list of newly inserted Lead records.
 *   - Map Lead fields to Contact fields per the LLD specification.
 *   - Perform a single bulk DML insert to create all Contact records.
 *   - Log DML failures to the debug log.
 *
 * Threading: Designed for synchronous after-insert trigger context.
 * Bulkified — handles up to 200 records per governor-limit transaction.
 *
 * @testClass LeadContactHandlerTest
 */
public with sharing class LeadContactHandler {

    /**
     * Processes the provided list of newly inserted Lead records, creating one
     * corresponding Contact record for each Lead. Uses a single bulk DML insert
     * to stay within Salesforce governor limits.
     *
     * Field mapping applied:
     *   Lead.FirstName → Contact.FirstName
     *   Lead.LastName  → Contact.LastName
     *   Lead.Email     → Contact.Email
     *   Lead.Phone     → Contact.Phone
     *
     * @param  newLeads  List of Lead records from Trigger.new. Must not be null.
     * @return           void
     *
     * @calledBy  LeadAfterInsertTrigger
     * @testMethods
     *   test_processLeads_singleLead_createsContact,
     *   test_processLeads_bulkLeads_createsContacts,
     *   test_processLeads_fieldMapping_isCorrect,
     *   test_processLeads_nullFields_handledGracefully,
     *   test_processLeads_emptyList_noError
     */
    public void processLeads(List<Lead> newLeads) {
        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }

        List<Contact> contactsToInsert = new List<Contact>();

        for (Lead sourceLead : newLeads) {
            Contact newContact = new Contact(
                FirstName = sourceLead.FirstName,
                LastName  = sourceLead.LastName,
                Email     = sourceLead.Email,
                Phone     = sourceLead.Phone
            );
            contactsToInsert.add(newContact);
        }

        if (!contactsToInsert.isEmpty()) {
            try {
                insert contactsToInsert;
            } catch (DmlException ex) {
                System.debug(LoggingLevel.ERROR,
                    'LeadContactHandler.processLeads - DML failure inserting Contacts: '
                    + ex.getMessage());
                throw ex;
            }
        }
    }
}