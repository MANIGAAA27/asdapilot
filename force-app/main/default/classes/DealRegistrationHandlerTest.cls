/**
 * @file        DealRegistrationHandlerTest.cls
 * @description Tests DealRegistrationHandler — covers Opportunity creation on insert,
 *              bi-directional field linking, field synchronization on update when status
 *              is not Approved, synchronization lock when status becomes Approved,
 *              and bulk 200-record governor-limit paths.
 * @testFor     DealRegistrationHandler
 * @coverage    Target ≥ 90%.
 */
@isTest
private class DealRegistrationHandlerTest {

    // ─── Test Setup ────────────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        Account acct = TestDataFactory.createAccount('Keneland Partner Account');
        TestDataFactory.createContact('Partner Contact', acct.Id);
    }

    // ─── Insert Tests ───────────────────────────────────────────────────────────

    /**
     * Inserting a Deal Registration should automatically create a linked Opportunity
     * and populate bi-directional lookup fields on both records.
     */
    @isTest
    static void test_processAfterInsert_singleRecord_createsLinkedOpportunity() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Keneland Partner Account' LIMIT 1];

        Test.startTest();
        Deal_Registration__c dr = TestDataFactory.createDealRegistration('New Deal 001', acct.Id);
        Test.stopTest();

        Deal_Registration__c reloadedDr = [
            SELECT Id, Opportunity__c, Partner_Account__c
            FROM Deal_Registration__c
            WHERE Id = :dr.Id
        ];
        System.assertNotEquals(null, reloadedDr.Opportunity__c,
            'Opportunity__c should be populated on the Deal Registration after insert');

        Opportunity opp = [
            SELECT Id, Name, AccountId, Deal_Registration__c, StageName, Amount, CloseDate
            FROM Opportunity
            WHERE Id = :reloadedDr.Opportunity__c
        ];
        System.assertNotEquals(null, opp,
            'A linked Opportunity should exist in the database');
        System.assertEquals(acct.Id, opp.AccountId,
            'Opportunity AccountId should be mapped from DR Partner_Account__c');
        System.assertEquals(dr.Id, opp.Deal_Registration__c,
            'Opportunity Deal_Registration__c should link back to the source DR');
        System.assertEquals('Qualification', opp.StageName,
            'Opportunity StageName should default to Qualification');
        System.assertEquals(50000, opp.Amount,
            'Opportunity Amount should be mapped from DR Estimated_Deal_Value__c');
        System.assertNotEquals(null, opp.CloseDate,
            'Opportunity CloseDate should be populated from DR Projected_Close_Date__c or default');
    }

    /**
     * Bulk insert of 200 Deal Registrations should create exactly 200 linked
     * Opportunities without hitting governor limits.
     */
    @isTest
    static void test_processAfterInsert_bulk_createsOpportunitiesForAllRecords() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Keneland Partner Account' LIMIT 1];

        Test.startTest();
        List<Deal_Registration__c> drs = TestDataFactory.createDealRegistrations(200, acct.Id);
        Test.stopTest();

        List<Deal_Registration__c> reloadedDrs = [
            SELECT Id, Opportunity__c
            FROM Deal_Registration__c
            WHERE Id IN :drs
        ];
        Integer linkedCount = 0;
        for (Deal_Registration__c dr : reloadedDrs) {
            if (dr.Opportunity__c != null) {
                linkedCount++;
            }
        }
        System.assertEquals(200, linkedCount,
            'All 200 Deal Registrations should have a linked Opportunity__c after bulk insert');

        Integer oppCount = [
            SELECT COUNT()
            FROM Opportunity
            WHERE Deal_Registration__c IN :drs
        ];
        System.assertEquals(200, oppCount,
            'Exactly 200 Opportunities should exist after bulk insert of 200 Deal Registrations');
    }

    // ─── Update / Sync Tests ────────────────────────────────────────────────────

    /**
     * Updating a mapped field on a Deal Registration with Status != Approved should
     * synchronize the new value to the linked Opportunity.
     */
    @isTest
    static void test_processAfterUpdate_notApproved_syncsFields() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Keneland Partner Account' LIMIT 1];
        Deal_Registration__c dr = TestDataFactory.createDealRegistration('Sync Test DR', acct.Id);
        dr = [SELECT Id, Opportunity__c, Status__c FROM Deal_Registration__c WHERE Id = :dr.Id];
        System.assertNotEquals(null, dr.Opportunity__c,
            'Opportunity should be linked before the update test proceeds');

        Decimal updatedAmount = 99500;
        Test.startTest();
        dr.Estimated_Deal_Value__c = updatedAmount;
        dr.Status__c = 'Under Review';
        update dr;
        Test.stopTest();

        Opportunity updatedOpp = [
            SELECT Amount FROM Opportunity WHERE Id = :dr.Opportunity__c
        ];
        System.assertEquals(updatedAmount, updatedOpp.Amount,
            'Opportunity Amount should be synchronized from updated Estimated_Deal_Value__c when not Approved');
    }

    /**
     * Once a Deal Registration Status is Approved, further updates to mapped
     * fields should NOT propagate to the linked Opportunity.
     */
    @isTest
    static void test_processAfterUpdate_approved_doesNotSync() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Keneland Partner Account' LIMIT 1];
        Deal_Registration__c dr = TestDataFactory.createDealRegistration('Lock Test DR', acct.Id);
        dr = [SELECT Id, Opportunity__c FROM Deal_Registration__c WHERE Id = :dr.Id];

        Opportunity baseOpp = [SELECT Amount FROM Opportunity WHERE Id = :dr.Opportunity__c];
        Decimal originalAmount = baseOpp.Amount;
        System.assertEquals(50000, originalAmount,
            'Opportunity Amount should be 50000 after initial insert mapping');

        Test.startTest();
        dr.Status__c               = 'Approved';
        dr.Estimated_Deal_Value__c = 999999;
        update dr;
        Test.stopTest();

        Opportunity lockedOpp = [SELECT Amount FROM Opportunity WHERE Id = :dr.Opportunity__c];
        System.assertEquals(originalAmount, lockedOpp.Amount,
            'Opportunity Amount must NOT change after Deal Registration is set to Approved');
    }

    /**
     * Updating a Deal Registration that has no linked Opportunity should not throw
     * an exception (handles edge case of Opportunity__c being null).
     */
    @isTest
    static void test_processAfterUpdate_noLinkedOpportunity_doesNotThrow() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Keneland Partner Account' LIMIT 1];
        Deal_Registration__c dr = TestDataFactory.createDealRegistration('Unlinked DR', acct.Id);

        // Detach the Opportunity lookup to simulate the edge case
        dr = [SELECT Id, Opportunity__c FROM Deal_Registration__c WHERE Id = :dr.Id];
        Deal_Registration__c detached = new Deal_Registration__c(
            Id             = dr.Id,
            Opportunity__c = null
        );
        update detached;

        Boolean caughtError = false;
        Test.startTest();
        try {
            detached.Estimated_Deal_Value__c = 12345;
            update detached;
        } catch (Exception ex) {
            caughtError = true;
        }
        Test.stopTest();

        System.assertEquals(false, caughtError,
            'No exception should be thrown when Opportunity__c is null on update');
    }

    /**
     * Updating a Deal Registration with Status Approved should not cause
     * any DML on the Opportunity even when all mapped fields change.
     */
    @isTest
    static void test_processAfterUpdate_bulkApproved_noOppsUpdated() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Keneland Partner Account' LIMIT 1];
        List<Deal_Registration__c> drs = TestDataFactory.createDealRegistrations(10, acct.Id);
        List<Deal_Registration__c> reloaded = [
            SELECT Id, Opportunity__c FROM Deal_Registration__c WHERE Id IN :drs
        ];

        // Approve all DRs
        for (Deal_Registration__c dr : reloaded) {
            dr.Status__c = 'Approved';
        }
        update reloaded;

        // Capture Opportunity amounts before the attempted sync
        List<Id> oppIds = new List<Id>();
        for (Deal_Registration__c dr : reloaded) {
            if (dr.Opportunity__c != null) {
                oppIds.add(dr.Opportunity__c);
            }
        }
        Map<Id, Opportunity> oppsBefore = new Map<Id, Opportunity>(
            [SELECT Id, Amount FROM Opportunity WHERE Id IN :oppIds]
        );

        Test.startTest();
        for (Deal_Registration__c dr : reloaded) {
            dr.Estimated_Deal_Value__c = 888888;
        }
        update reloaded;
        Test.stopTest();

        List<Opportunity> oppsAfter = [SELECT Id, Amount FROM Opportunity WHERE Id IN :oppIds];
        for (Opportunity opp : oppsAfter) {
            System.assertEquals(oppsBefore.get(opp.Id).Amount, opp.Amount,
                'Opportunity Amount should be unchanged after update on Approved Deal Registrations');
        }
    }
}
