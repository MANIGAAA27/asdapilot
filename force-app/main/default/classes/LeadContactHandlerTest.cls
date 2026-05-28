/**
 * @file        LeadContactHandlerTest.cls
 * @description Tests LeadContactHandler — covers single Lead creation,
 *              bulk Lead creation (200 records), field mapping validation,
 *              null field handling, and empty list safety.
 * @testFor     LeadContactHandler
 * @coverage    Target ≥ 90%.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-05-28
 * @lastModified 2026-05-28
 * @group       LeadAutomation
 */
@isTest
private class LeadContactHandlerTest {

    // ─── Helper ──────────────────────────────────────────────────────────────

    /** Builds a Lead SObject without inserting it. */
    private static Lead buildLead(String firstName, String lastName,
                                   String email, String phone) {
        return new Lead(
            FirstName  = firstName,
            LastName   = lastName,
            Email      = email,
            Phone      = phone,
            Company    = 'Keneland LLC'   // required field on Lead
        );
    }

    // ─── Tests ───────────────────────────────────────────────────────────────

    @isTest
    static void test_processLeads_singleLead_createsContact() {
        Lead testLead = buildLead('Alice', 'Smith', 'alice@example.com', '5550001111');
        insert testLead;

        Test.startTest();
        // Re-query to simulate trigger context data
        List<Lead> insertedLeads = [SELECT Id, FirstName, LastName, Email, Phone
                                    FROM Lead WHERE Id = :testLead.Id];
        new LeadContactHandler().processLeads(insertedLeads);
        Test.stopTest();

        List<Contact> contacts = [SELECT FirstName, LastName, Email, Phone
                                  FROM Contact WHERE Email = 'alice@example.com'];
        System.assertEquals(1, contacts.size(), 'Expected exactly one Contact created');
        System.assertEquals('Alice',              contacts[0].FirstName, 'FirstName mismatch');
        System.assertEquals('Smith',              contacts[0].LastName,  'LastName mismatch');
        System.assertEquals('alice@example.com',  contacts[0].Email,     'Email mismatch');
        System.assertEquals('5550001111',         contacts[0].Phone,     'Phone mismatch');
    }

    @isTest
    static void test_processLeads_bulkLeads_createsContacts() {
        Integer recordCount = 200;
        List<Lead> leadsToInsert = new List<Lead>();
        for (Integer i = 0; i < recordCount; i++) {
            leadsToInsert.add(buildLead('Bulk', 'Lead' + i,
                                        'bulk' + i + '@example.com', '555' + String.valueOf(i).leftPad(7, '0')));
        }
        insert leadsToInsert;

        List<Lead> insertedLeads = [SELECT Id, FirstName, LastName, Email, Phone FROM Lead];

        Test.startTest();
        new LeadContactHandler().processLeads(insertedLeads);
        Test.stopTest();

        Integer contactCount = [SELECT COUNT() FROM Contact];
        System.assertEquals(recordCount, contactCount,
            'Expected one Contact per Lead for bulk insert');
    }

    @isTest
    static void test_processLeads_fieldMapping_isCorrect() {
        Lead testLead = buildLead('Bob', 'Jones', 'bob@example.com', '5559998888');
        insert testLead;

        List<Lead> leads = [SELECT Id, FirstName, LastName, Email, Phone
                            FROM Lead WHERE Id = :testLead.Id];

        Test.startTest();
        new LeadContactHandler().processLeads(leads);
        Test.stopTest();

        Contact created = [SELECT FirstName, LastName, Email, Phone
                           FROM Contact WHERE Email = 'bob@example.com' LIMIT 1];
        System.assertEquals(testLead.FirstName, created.FirstName, 'FirstName must match Lead');
        System.assertEquals(testLead.LastName,  created.LastName,  'LastName must match Lead');
        System.assertEquals(testLead.Email,     created.Email,     'Email must match Lead');
        System.assertEquals(testLead.Phone,     created.Phone,     'Phone must match Lead');
    }

    @isTest
    static void test_processLeads_nullFields_handledGracefully() {
        // LastName is required on Lead; FirstName/Email/Phone left null
        Lead testLead = buildLead(null, 'Doe', null, null);
        insert testLead;

        List<Lead> leads = [SELECT Id, FirstName, LastName, Email, Phone
                            FROM Lead WHERE Id = :testLead.Id];

        Test.startTest();
        new LeadContactHandler().processLeads(leads);
        Test.stopTest();

        List<Contact> contacts = [SELECT FirstName, LastName, Email, Phone
                                  FROM Contact WHERE LastName = 'Doe'];
        System.assertEquals(1,     contacts.size(),        'Expected one Contact for null-field Lead');
        System.assertEquals(null,  contacts[0].FirstName,  'FirstName should be null');
        System.assertEquals('Doe', contacts[0].LastName,   'LastName must be populated');
        System.assertEquals(null,  contacts[0].Email,      'Email should be null');
        System.assertEquals(null,  contacts[0].Phone,      'Phone should be null');
    }

    @isTest
    static void test_processLeads_emptyList_noError() {
        Test.startTest();
        // Must not throw any exception for an empty list
        new LeadContactHandler().processLeads(new List<Lead>());
        Test.stopTest();

        Integer contactCount = [SELECT COUNT() FROM Contact];
        System.assertEquals(0, contactCount, 'No Contacts should be created for empty input');
    }

    @isTest
    static void test_processLeads_nullInput_noError() {
        Test.startTest();
        new LeadContactHandler().processLeads(null);
        Test.stopTest();

        Integer contactCount = [SELECT COUNT() FROM Contact];
        System.assertEquals(0, contactCount, 'No Contacts should be created for null input');
    }
}