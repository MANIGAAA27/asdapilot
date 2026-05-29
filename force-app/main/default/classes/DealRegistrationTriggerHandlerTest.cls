/**
 * Test class for DealRegistrationTriggerHandler.
 */
@isTest
private class DealRegistrationTriggerHandlerTest {

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Partner');
        insert acc;
        
        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert con;
    }

    @isTest
    static void afterInsert_createsLinkedOpportunity() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        Deal_Registration__c dr = new Deal_Registration__c(
            Partner_Account__c = acc.Id,
            Primary_Partner_Contact__c = con.Id,
            Estimated_Deal_Value__c = 50000,
            Projected_Close_Date__c = Date.today().addDays(30),
            Description__c = 'Test deal'
        );
        
        Test.startTest();
        insert dr;
        Test.stopTest();
        
        Deal_Registration__c updatedDr = [
            SELECT Linked_Opportunity__c 
            FROM Deal_Registration__c 
            WHERE Id = :dr.Id
        ];
        System.assertNotEquals(null, updatedDr.Linked_Opportunity__c, 'Opportunity should be created');
        
        Opportunity opp = [
            SELECT AccountId, Primary_Contact__c, Amount, CloseDate, Description, Linked_Deal_Registration__c
            FROM Opportunity 
            WHERE Id = :updatedDr.Linked_Opportunity__c
        ];
        System.assertEquals(dr.Id, opp.Linked_Deal_Registration__c, 'Bi-directional link');
        System.assertEquals(acc.Id, opp.AccountId, 'Account mapped');
        System.assertEquals(con.Id, opp.Primary_Contact__c, 'Contact mapped');
        System.assertEquals(50000, opp.Amount, 'Amount mapped');
        System.assertEquals(Date.today().addDays(30), opp.CloseDate, 'Close date mapped');
        System.assertEquals('Test deal', opp.Description, 'Description mapped');
    }

    @isTest
    static void afterUpdate_syncsFields() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Deal_Registration__c dr = new Deal_Registration__c(
            Partner_Account__c = acc.Id,
            Estimated_Deal_Value__c = 10000
        );
        insert dr;
        
        dr = [SELECT Id, Linked_Opportunity__c FROM Deal_Registration__c WHERE Id = :dr.Id];
        
        Test.startTest();
        dr.Estimated_Deal_Value__c = 20000;
        update dr;
        Test.stopTest();
        
        Opportunity opp = [SELECT Amount FROM Opportunity WHERE Id = :dr.Linked_Opportunity__c];
        System.assertEquals(20000, opp.Amount, 'Amount should sync');
    }

    @isTest
    static void afterUpdate_stopsWhenApproved() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Deal_Registration__c dr = new Deal_Registration__c(
            Partner_Account__c = acc.Id,
            Estimated_Deal_Value__c = 10000,
            Status__c = 'Pending'
        );
        insert dr;
        
        dr = [SELECT Id, Linked_Opportunity__c FROM Deal_Registration__c WHERE Id = :dr.Id];
        dr.Status__c = 'Approved';
        update dr;
        
        Test.startTest();
        dr.Estimated_Deal_Value__c = 99999;
        update dr;
        Test.stopTest();
        
        Opportunity opp = [SELECT Amount FROM Opportunity WHERE Id = :dr.Linked_Opportunity__c];
        System.assertEquals(10000, opp.Amount, 'Amount should NOT sync after Approved');
    }
}
