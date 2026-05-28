public with sharing class LeadToContactHandler {
    public void handleLeadInsert(List<Lead> newLeads) {
        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }

        List<Contact> contactsToInsert = new List<Contact>();
        for (Lead leadRecord : newLeads) {
            contactsToInsert.add(mapLeadToContact(leadRecord));
        }

        insertContacts(contactsToInsert);
    }

    private Contact mapLeadToContact(Lead leadRecord) {
        Contact contactRecord = new Contact();
        contactRecord.FirstName = leadRecord.FirstName;
        contactRecord.LastName = leadRecord.LastName;
        contactRecord.Email = leadRecord.Email;
        contactRecord.Phone = leadRecord.Phone;
        return contactRecord;
    }

    private void insertContacts(List<Contact> contactsToInsert) {
        if (contactsToInsert == null || contactsToInsert.isEmpty()) {
            return;
        }
        insert contactsToInsert;
    }
}