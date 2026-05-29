/**
 * @file        DealRegistrationHandlerTest.cls
 * @description Tests DealRegistrationHandler — covers Opportunity creation on
 *              insert, CMT-driven field mapping, synchronization on update,
 *              approval-status lock, and bulk 200-record paths.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-05-29
 * @lastModified 2026-05-29
 * @testFor     DealRegistrationHandler
 * @coverage    Target >= 90%.
 */
@isTest
private class DealRegistrationHandlerTest {

    // ─── Helpers ──────────────────────────────────────────────────────────────

    /** Returns a single-entry CMT override mapping Estimated_Deal_Value__c → Amount. */
    private static List<Deal_Field_Mapping__mdt> amountMapping() {
        return new List<Deal_Field_Mapping__mdt>{
            new Deal_Field_Mapping__mdt(
                Source_Field_API_Name__c = 'Estimated_Deal_Value__c',
                Target_Field_API_Name__c = 'Amount',
                Is_Active__c            = true
            )
        };
    }

    /** Returns CMT override entries covering Amount and CloseDate mappings. */
    private static List<Deal_Field_Mapping__mdt> fullFieldMappings() {
        return new List<Deal_Field_Mapping__mdt>{
            new Deal_Field_Mapping__mdt(
                Source_Field_API_Name__c = 'Estimated_Deal_Value__c',
                Target_Field_API_Name__c = 'Amount',
                Is_Active__c            = true
            ),
            new Deal_Field_Mapping__mdt(
                Source_Field_API_Name__c = 'Projected_Close_Date__c',
                Target_Field_API_Name__c = 'CloseDate',
                Is_Active__c            = true
            )
        };
    }

    // ─── Test: insert creates linked Opportunity ──────────────────────────────

    @isTest
    static void test_afterInsert_createsLinkedOpportunity() {
        // Use empty CMT override — we test linkage, not field mapping here
        DealRegistrationHandler.testMappingOverride = new List<Deal_Field_Mapping__mdt>();

        Deal_Registration__c dr = new Deal_Registration__c(
            Status__c = 'Pending'
        );

        Test.startTest();
        insert dr;
        Test.stopTest();

        // Re-query DR to pick up the Opportunity__c that the handler wrote back
        Deal_Registration__c updatedDr = [
            SELECT Id, Name, Opportunity__c
            FROM   Deal_Registration__c
            WHERE  Id = :dr.Id
        ];
        System.assertNotEquals(
            null, updatedDr.Opportunity__c,
            'Deal Registration should have a linked Opportunity after insert'
        );

        // Verify Opportunity was created with correct defaults and bi-directional link
        Opportunity opp = [
            SELECT Id, Name, StageName, Deal_Registration__c
            FROM   Opportunity
            WHERE  Id = :updatedDr.Opportunity__c
        ];
        System.assertNotEquals(
            null, opp.Name,
            'Opportunity Name should be populated from the auto-generated Deal Registration Name'
        );
        System.assertEquals(
            'Qualification', opp.StageName,
            'Opportunity Stage should default to Qualification'
        );
        System.assertEquals(
            dr.Id, opp.Deal_Registration__c,
            'Opportunity should link back to the originating Deal Registration'
        );
    }

    // ─── Test: CMT field mappings are applied on insert ───────────────────────

    @isTest
    static void test_afterInsert_mapsFieldsFromCMT() {
        DealRegistrationHandler.testMappingOverride = fullFieldMappings();

        Date closeDate = Date.today().addDays(30);
        Deal_Registration__c dr = new Deal_Registration__c(
            Status__c               = 'Pending',
            Estimated_Deal_Value__c = 25000,
            Projected_Close_Date__c = closeDate
        );

        Test.startTest();
        insert dr;
        Test.stopTest();

        Deal_Registration__c updatedDr = [
            SELECT Opportunity__c
            FROM   Deal_Registration__c
            WHERE  Id = :dr.Id
        ];
        System.assertNotEquals(null, updatedDr.Opportunity__c, 'Opportunity should be created');

        Opportunity opp = [
            SELECT Amount, CloseDate
            FROM   Opportunity
            WHERE  Id = :updatedDr.Opportunity__c
        ];
        System.assertEquals(
            25000, opp.Amount,
            'Amount should be mapped from Estimated_Deal_Value__c'
        );
        System.assertEquals(
            closeDate, opp.CloseDate,
            'CloseDate should be mapped from Projected_Close_Date__c'
        );
    }

    // ─── Test: mapped fields sync on update when not Approved ─────────────────

    @isTest
    static void test_afterUpdate_syncsFieldsWhenNotApproved() {
        DealRegistrationHandler.testMappingOverride = amountMapping();

        Deal_Registration__c dr = new Deal_Registration__c(
            Status__c               = 'Pending',
            Estimated_Deal_Value__c = 10000
        );
        insert dr;

        dr = [SELECT Id, Opportunity__c FROM Deal_Registration__c WHERE Id = :dr.Id];
        System.assertNotEquals(null, dr.Opportunity__c, 'Opportunity must exist before update test');

        Test.startTest();
        dr.Estimated_Deal_Value__c = 50000;
        update dr;
        Test.stopTest();

        Opportunity opp = [
            SELECT Amount
            FROM   Opportunity
            WHERE  Id = :dr.Opportunity__c
        ];
        System.assertEquals(
            50000, opp.Amount,
            'Opportunity Amount should be updated when Deal Registration is not Approved'
        );
    }

    // ─── Test: sync halts when status changes to Approved ─────────────────────

    @isTest
    static void test_afterUpdate_stopsWhenApproved() {
        DealRegistrationHandler.testMappingOverride = amountMapping();

        Deal_Registration__c dr = new Deal_Registration__c(
            Status__c               = 'Pending',
            Estimated_Deal_Value__c = 10000
        );
        insert dr;

        dr = [SELECT Id, Opportunity__c FROM Deal_Registration__c WHERE Id = :dr.Id];

        // Capture the Amount the Opportunity received during insert
        Opportunity initialOpp = [
            SELECT Amount
            FROM   Opportunity
            WHERE  Id = :dr.Opportunity__c
        ];
        Decimal lockedAmount = initialOpp.Amount;

        Test.startTest();
        // Approve the Deal Registration AND change the mapped field simultaneously
        dr.Status__c              = 'Approved';
        dr.Estimated_Deal_Value__c = 99999;
        update dr;
        Test.stopTest();

        Opportunity opp = [
            SELECT Amount
            FROM   Opportunity
            WHERE  Id = :dr.Opportunity__c
        ];
        System.assertEquals(
            lockedAmount, opp.Amount,
            'Opportunity Amount must NOT change once Deal Registration is Approved'
        );
    }

    // ─── Test: no-op when no mapped fields changed ────────────────────────────

    @isTest
    static void test_afterUpdate_noOp_whenNoMappedFieldsChanged() {
        DealRegistrationHandler.testMappingOverride = amountMapping();

        Deal_Registration__c dr = new Deal_Registration__c(
            Status__c               = 'Pending',
            Estimated_Deal_Value__c = 7500
        );
        insert dr;

        dr = [SELECT Id, Opportunity__c FROM Deal_Registration__c WHERE Id = :dr.Id];

        // Record Opportunity state before a non-mapped field update
        Opportunity before = [SELECT Amount FROM Opportunity WHERE Id = :dr.Opportunity__c];

        Test.startTest();
        // Change Status__c (not a mapped field); Estimated_Deal_Value__c unchanged
        dr.Status__c = 'In Review';
        update dr;
        Test.stopTest();

        Opportunity after = [SELECT Amount FROM Opportunity WHERE Id = :dr.Opportunity__c];
        System.assertEquals(
            before.Amount, after.Amount,
            'Opportunity Amount should remain unchanged when no mapped source field changes'
        );
    }

    // ─── Test: bulk insert — 200 records ──────────────────────────────────────

    @isTest
    static void test_bulkInsert_200Records() {
        DealRegistrationHandler.testMappingOverride = new List<Deal_Field_Mapping__mdt>();

        List<Deal_Registration__c> drs = new List<Deal_Registration__c>();
        for (Integer i = 0; i < 200; i++) {
            drs.add(new Deal_Registration__c(
                Status__c = 'Pending'
            ));
        }

        Test.startTest();
        insert drs;
        Test.stopTest();

        // All 200 Deal Registrations should have a linked Opportunity
        List<Deal_Registration__c> updatedDrs = [
            SELECT Opportunity__c
            FROM   Deal_Registration__c
            WHERE  Id IN :drs
        ];
        Integer linkedCount = 0;
        for (Deal_Registration__c updated : updatedDrs) {
            if (updated.Opportunity__c != null) {
                linkedCount++;
            }
        }
        System.assertEquals(
            200, linkedCount,
            'All 200 Deal Registrations should link to a created Opportunity'
        );

        // Verify 200 Opportunities were created with back-links
        Integer oppCount = [
            SELECT COUNT()
            FROM   Opportunity
            WHERE  Deal_Registration__c IN :drs
        ];
        System.assertEquals(
            200, oppCount,
            'Exactly 200 Opportunities should be created for 200 Deal Registrations'
        );
    }
}
