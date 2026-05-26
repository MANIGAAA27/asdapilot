/**
 * Canonical Apex test class. Emit this file IMMEDIATELY AFTER the production
 * class (SF_DEVELOPER_INSTRUCTIONS, Apex Rule 11 — test-first emit). It defines
 * the API contract the production class must satisfy.
 *
 * @isTest classes MUST NOT use `extends` or `implements`.
 * @isTest classes MUST NOT call methods that don't exist on the production class.
 */
@isTest
private class MyControllerTest {

    @TestSetup
    static void setupData() {
        insert new My_Object__c(Name = 'Seed', My_Field__c = 'Seed value');
    }

    @isTest
    static void getRecentRecords_returnsSeedRow() {
        Test.startTest();
        List<My_Object__c> rows = MyController.getRecentRecords(10);
        Test.stopTest();
        System.assertEquals(1, rows.size(), 'Expected exactly the seeded row');
        System.assertEquals('Seed', rows[0].Name, 'Name field round-trip');
    }

    @isTest
    static void createRecord_persistsRow() {
        Test.startTest();
        Id newId = MyController.createRecord('Hello');
        Test.stopTest();
        My_Object__c reread = [SELECT My_Field__c FROM My_Object__c WHERE Id = :newId];
        System.assertEquals('Hello', reread.My_Field__c, 'My_Field__c persisted');
    }

    @isTest
    static void createRecord_blankRejected() {
        Test.startTest();
        try {
            MyController.createRecord('');
            System.assert(false, 'Expected AuraHandledException for blank input');
        } catch (AuraHandledException ex) {
            // Note: caught into `ex`, never `exception` — reserved identifier.
            System.assert(true, 'AuraHandledException correctly thrown');
        }
        Test.stopTest();
    }
}
