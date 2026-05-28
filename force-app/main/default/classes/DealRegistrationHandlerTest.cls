/**
 * @file              DealRegistrationHandlerTest.cls
 * @description       Tests DealRegistrationHandler — covers Opportunity
 *                    creation on Deal Registration insert, field mapping
 *                    synchronization on update, synchronization cessation
 *                    on Approved status, bulk operation handling (200+
 *                    records), and edge cases (no linked Opportunity,
 *                    minimal data).
 * @author            ASDA Dev Agent
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             PartnerRegistrationAutomation
 *
 * @testFor           DealRegistrationHandler
 * @coverage          Target >= 90%.
 *
 * @see               LLD - Partner Registration Automation (Feature: Partner Registration Automation)
 */
@isTest
private class DealRegistrationHandlerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Test: After Insert — single record creates Opportunity
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that inserting a single Deal Registration creates exactly one
     * Opportunity and establishes bi-directional linkage.
     */
    @isTest
    static void test_processAfterInsert_singleRecord_createsOpportunity() {
        Account acct = TestDataFactory.createAccount('Keneland Technology');
        Contact con = TestDataFactory.createContact(acct.Id, 'PartnerContact');

        Test.startTest();
        Deal_Registration__c dealReg = TestDataFactory.createDealRegistration(
            'Test Deal 001', acct.Id, con.Id
        );
        Test.stopTest();

        // Re-query to get trigger-populated Linked_Opportunity__c
        Deal_Registration__c updatedDealReg = [
            SELECT Id, Name, Linked_Opportunity__c, Status__c,
                   Partner_Account__c, Estimated_Deal_Value__c,
                   Projected_Close_Date__c
            FROM Deal_Registration__c
            WHERE Id = :dealReg.Id
        ];

        System.assertNotEquals(
            null,
            updatedDealReg.Linked_Opportunity__c,
            'Deal Registration should have a linked Opportunity after insert.'
        );

        Opportunity linkedOpp = [
            SELECT Id, Name, StageName, AccountId, Amount, CloseDate,
                   Deal_Registration__c
            FROM Opportunity
            WHERE Id = :updatedDealReg.Linked_Opportunity__c
        ];

        System.assertEquals(
            dealReg.Id,
            linkedOpp.Deal_Registration__c,
            'Opportunity Deal_Registration__c should point back to the source Deal Registration.'
        );
        System.assertEquals(
            acct.Id,
            linkedOpp.AccountId,
            'Opportunity AccountId should be mapped from Deal Registration Partner_Account__c.'
        );
        System.assertEquals(
            (Decimal) 50000,
            linkedOpp.Amount,
            'Opportunity Amount should be mapped from Deal Registration Estimated_Deal_Value__c.'
        );
        System.assertEquals(
            'Qualification',
            linkedOpp.StageName,
            'Opportunity StageName should default to Qualification.'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: After Insert — Opportunity Name derived from Deal Registration Name
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that the created Opportunity Name is derived from the Deal
     * Registration Name with the expected suffix.
     */
    @isTest
    static void test_processAfterInsert_opportunityName_derivedFromDealRegName() {
        Test.startTest();
        Deal_Registration__c dealReg = TestDataFactory.createMinimalDealRegistration('My Deal Reg');
        Test.stopTest();

        Deal_Registration__c updatedDealReg = [
            SELECT Id, Linked_Opportunity__c
            FROM Deal_Registration__c
            WHERE Id = :dealReg.Id
        ];

        System.assertNotEquals(
            null,
            updatedDealReg.Linked_Opportunity__c,
            'Linked Opportunity should be created even for minimal Deal Registration.'
        );

        Opportunity linkedOpp = [
            SELECT Id, Name
            FROM Opportunity
            WHERE Id = :updatedDealReg.Linked_Opportunity__c
        ];

        System.assertEquals(
            'My Deal Reg - Opportunity',
            linkedOpp.Name,
            'Opportunity Name should be Deal Registration Name + " - Opportunity".'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: After Insert — bulk 200 records
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that bulk inserting 200 Deal Registrations creates 200
     * Opportunities without governor limit violations and all bi-directional
     * links are established.
     */
    @isTest
    static void test_processAfterInsert_bulkRecords_createsOpportunities() {
        Account acct = TestDataFactory.createAccount('Bulk Partner Account');

        Test.startTest();
        List<Deal_Registration__c> dealRegs = TestDataFactory.createDealRegistrations(200, acct.Id);
        Test.stopTest();

        List<Deal_Registration__c> updatedDealRegs = [
            SELECT Id, Linked_Opportunity__c
            FROM Deal_Registration__c
            WHERE Id IN :dealRegs
        ];

        Integer linkedCount = 0;
        for (Deal_Registration__c dr : updatedDealRegs) {
            if (dr.Linked_Opportunity__c != null) {
                linkedCount++;
            }
        }

        System.assertEquals(
            200,
            linkedCount,
            'All 200 Deal Registrations should have a linked Opportunity.'
        );

        Integer oppCount = [
            SELECT COUNT()
            FROM Opportunity
            WHERE Deal_Registration__c IN :dealRegs
        ];

        System.assertEquals(
            200,
            oppCount,
            'Exactly 200 Opportunities should have been created.'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: After Update — mapped field change synchronizes to Opportunity
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that updating a mapped field on a Deal Registration (Status not
     * Approved) propagates the change to the linked Opportunity.
     */
    @isTest
    static void test_processAfterUpdate_mappedFieldChanged_updatesOpportunity() {
        Account acct = TestDataFactory.createAccount('Sync Test Account');
        Contact con = TestDataFactory.createContact(acct.Id, 'SyncContact');

        // Insert outside Test.startTest so the recursion guard resets before the update
        Deal_Registration__c dealReg = TestDataFactory.createDealRegistration(
            'Sync Deal', acct.Id, con.Id
        );

        // Re-query to get Linked_Opportunity__c populated by trigger
        Deal_Registration__c insertedDealReg = [
            SELECT Id, Linked_Opportunity__c
            FROM Deal_Registration__c
            WHERE Id = :dealReg.Id
        ];

        System.assertNotEquals(
            null,
            insertedDealReg.Linked_Opportunity__c,
            'Prerequisite: Deal Registration must have a linked Opportunity before update test.'
        );

        Test.startTest();
        insertedDealReg.Estimated_Deal_Value__c = 99999;
        update insertedDealReg;
        Test.stopTest();

        Opportunity updatedOpp = [
            SELECT Id, Amount
            FROM Opportunity
            WHERE Id = :insertedDealReg.Linked_Opportunity__c
        ];

        System.assertEquals(
            (Decimal) 99999,
            updatedOpp.Amount,
            'Opportunity Amount should be updated to match the new Estimated_Deal_Value__c.'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: After Update — Approved status stops synchronization
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that when a Deal Registration Status is changed to 'Approved',
     * mapped field changes are NOT propagated to the linked Opportunity.
     */
    @isTest
    static void test_processAfterUpdate_statusApproved_doesNotUpdateOpportunity() {
        Account acct = TestDataFactory.createAccount('Approved Test Account');
        Contact con = TestDataFactory.createContact(acct.Id, 'ApprovedContact');

        // Insert outside Test.startTest so the recursion guard resets before the update
        Deal_Registration__c dealReg = TestDataFactory.createDealRegistration(
            'Approved Deal', acct.Id, con.Id
        );

        Deal_Registration__c insertedDealReg = [
            SELECT Id, Linked_Opportunity__c, Estimated_Deal_Value__c
            FROM Deal_Registration__c
            WHERE Id = :dealReg.Id
        ];

        // Capture the Opportunity Amount before approval
        Opportunity oppBeforeApproval = [
            SELECT Id, Amount
            FROM Opportunity
            WHERE Id = :insertedDealReg.Linked_Opportunity__c
        ];
        Decimal amountBeforeApproval = oppBeforeApproval.Amount;

        Test.startTest();
        // Set status to Approved AND change a mapped field simultaneously
        insertedDealReg.Status__c = 'Approved';
        insertedDealReg.Estimated_Deal_Value__c = 999999;
        update insertedDealReg;
        Test.stopTest();

        Opportunity oppAfterApproval = [
            SELECT Id, Amount
            FROM Opportunity
            WHERE Id = :insertedDealReg.Linked_Opportunity__c
        ];

        System.assertEquals(
            amountBeforeApproval,
            oppAfterApproval.Amount,
            'Opportunity Amount should NOT change when Deal Registration Status is Approved.'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: After Update — no linked Opportunity skips update gracefully
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that updating a Deal Registration with no linked Opportunity
     * does not throw an exception and completes gracefully.
     */
    @isTest
    static void test_processAfterUpdate_noLinkedOpportunity_skipsUpdate() {
        Deal_Registration__c dealReg = TestDataFactory.createMinimalDealRegistration(
            'No Link Deal'
        );

        // Manually clear the linked opportunity (in case trigger set one)
        Deal_Registration__c insertedDealReg = [
            SELECT Id, Linked_Opportunity__c
            FROM Deal_Registration__c
            WHERE Id = :dealReg.Id
        ];
        insertedDealReg.Linked_Opportunity__c = null;
        update insertedDealReg;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            insertedDealReg.Deal_Description__c = 'Updated description';
            update insertedDealReg;
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(
            false,
            exceptionThrown,
            'Updating a Deal Registration with no linked Opportunity should not throw an exception.'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: After Update — bulk 200 records synchronize correctly
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that bulk updating 200 Deal Registrations correctly synchronizes
     * all linked Opportunities without governor limit violations.
     */
    @isTest
    static void test_processAfterUpdate_bulkRecords_updatesOpportunities() {
        Account acct = TestDataFactory.createAccount('Bulk Update Account');

        // Insert outside Test.startTest so the recursion guard resets before the update
        List<Deal_Registration__c> dealRegs = TestDataFactory.createDealRegistrations(
            200, acct.Id
        );

        // Re-query to get Linked_Opportunity__c values after trigger has fired
        List<Deal_Registration__c> insertedDealRegs = [
            SELECT Id, Linked_Opportunity__c, Estimated_Deal_Value__c
            FROM Deal_Registration__c
            WHERE Id IN :dealRegs
        ];

        // Collect linked Opportunity IDs before the update
        Set<Id> oppIds = new Set<Id>();
        for (Deal_Registration__c dr : insertedDealRegs) {
            if (dr.Linked_Opportunity__c != null) {
                oppIds.add(dr.Linked_Opportunity__c);
            }
        }

        System.assertEquals(
            200,
            oppIds.size(),
            'Prerequisite: all 200 Deal Registrations must have a linked Opportunity before bulk update test.'
        );

        // Update Estimated_Deal_Value__c on all records
        for (Deal_Registration__c dr : insertedDealRegs) {
            dr.Estimated_Deal_Value__c = 77777;
        }

        Test.startTest();
        update insertedDealRegs;
        Test.stopTest();

        List<Opportunity> updatedOpps = [
            SELECT Id, Amount
            FROM Opportunity
            WHERE Id IN :oppIds
        ];

        System.assertEquals(
            200,
            updatedOpps.size(),
            'All 200 linked Opportunities should be returned by the query.'
        );

        for (Opportunity opp : updatedOpps) {
            System.assertEquals(
                (Decimal) 77777,
                opp.Amount,
                'All Opportunity Amounts should be updated to 77777 after bulk update.'
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: After Insert — CloseDate mapped from Projected_Close_Date__c
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that the Opportunity CloseDate is mapped from the Deal
     * Registration Projected_Close_Date__c field.
     */
    @isTest
    static void test_processAfterInsert_closeDateMapped_fromProjectedCloseDate() {
        Account acct = TestDataFactory.createAccount('CloseDate Test Account');
        Date expectedCloseDate = Date.today().addDays(120);

        Deal_Registration__c dealReg = new Deal_Registration__c(
            Name = 'CloseDate Test Deal',
            Partner_Account__c = acct.Id,
            Projected_Close_Date__c = expectedCloseDate,
            Status__c = 'Submitted'
        );

        Test.startTest();
        insert dealReg;
        Test.stopTest();

        Deal_Registration__c updatedDealReg = [
            SELECT Id, Linked_Opportunity__c
            FROM Deal_Registration__c
            WHERE Id = :dealReg.Id
        ];

        System.assertNotEquals(
            null,
            updatedDealReg.Linked_Opportunity__c,
            'Prerequisite: Linked Opportunity must exist to verify CloseDate mapping.'
        );

        Opportunity linkedOpp = [
            SELECT Id, CloseDate
            FROM Opportunity
            WHERE Id = :updatedDealReg.Linked_Opportunity__c
        ];

        System.assertEquals(
            expectedCloseDate,
            linkedOpp.CloseDate,
            'Opportunity CloseDate should be mapped from Deal Registration Projected_Close_Date__c.'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: After Insert — Description mapped from Deal_Description__c
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that the Opportunity Description is mapped from the Deal
     * Registration Deal_Description__c field.
     */
    @isTest
    static void test_processAfterInsert_descriptionMapped_fromDealDescription() {
        Account acct = TestDataFactory.createAccount('Description Test Account');
        String expectedDescription = 'This is a test deal description for mapping verification.';

        Deal_Registration__c dealReg = new Deal_Registration__c(
            Name = 'Description Test Deal',
            Partner_Account__c = acct.Id,
            Deal_Description__c = expectedDescription,
            Status__c = 'Submitted'
        );

        Test.startTest();
        insert dealReg;
        Test.stopTest();

        Deal_Registration__c updatedDealReg = [
            SELECT Id, Linked_Opportunity__c
            FROM Deal_Registration__c
            WHERE Id = :dealReg.Id
        ];

        System.assertNotEquals(
            null,
            updatedDealReg.Linked_Opportunity__c,
            'Prerequisite: Linked Opportunity must exist to verify Description mapping.'
        );

        Opportunity linkedOpp = [
            SELECT Id, Description
            FROM Opportunity
            WHERE Id = :updatedDealReg.Linked_Opportunity__c
        ];

        System.assertEquals(
            expectedDescription,
            linkedOpp.Description,
            'Opportunity Description should be mapped from Deal Registration Deal_Description__c.'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test: After Update — status transition from Under Review to Approved
    //       stops sync on subsequent update
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Verifies the edge case where a Deal Registration transitions through
     * multiple statuses: Submitted → Under Review → Approved. After reaching
     * Approved, a subsequent update to a mapped field must NOT propagate.
     *
     * Each DML step is isolated so the static recursion guard resets between
     * trigger invocations within the same test context.
     */
    @isTest
    static void test_processAfterUpdate_statusTransitionToApproved_subsequentUpdateBlocked() {
        Account acct = TestDataFactory.createAccount('Transition Test Account');

        // Step 0: Insert — outside Test.startTest so guard resets cleanly
        Deal_Registration__c dealReg = TestDataFactory.createDealRegistration(
            'Transition Deal', acct.Id, null
        );

        Deal_Registration__c insertedDealReg = [
            SELECT Id, Linked_Opportunity__c
            FROM Deal_Registration__c
            WHERE Id = :dealReg.Id
        ];

        System.assertNotEquals(
            null,
            insertedDealReg.Linked_Opportunity__c,
            'Prerequisite: Linked Opportunity must exist before status transition test.'
        );

        Id linkedOppId = insertedDealReg.Linked_Opportunity__c;

        // Step 1: Transition to Under Review — sync should still work
        insertedDealReg.Status__c = 'Under Review';
        insertedDealReg.Estimated_Deal_Value__c = 11111;
        update insertedDealReg;

        // Re-query to confirm sync occurred
        Opportunity oppAfterUnderReview = [
            SELECT Id, Amount
            FROM Opportunity
            WHERE Id = :linkedOppId
        ];
        System.assertEquals(
            (Decimal) 11111,
            oppAfterUnderReview.Amount,
            'Opportunity Amount should sync when status is Under Review.'
        );

        // Step 2: Transition to Approved — re-query first to get fresh record
        Deal_Registration__c dealRegForApproval = [
            SELECT Id, Linked_Opportunity__c, Status__c, Estimated_Deal_Value__c
            FROM Deal_Registration__c
            WHERE Id = :dealReg.Id
        ];
        dealRegForApproval.Status__c = 'Approved';
        update dealRegForApproval;

        // Step 3: Attempt to update a mapped field after Approved
        Test.startTest();
        Deal_Registration__c dealRegAfterApproval = [
            SELECT Id, Linked_Opportunity__c, Status__c, Estimated_Deal_Value__c
            FROM Deal_Registration__c
            WHERE Id = :dealReg.Id
        ];
        dealRegAfterApproval.Estimated_Deal_Value__c = 99999;
        update dealRegAfterApproval;
        Test.stopTest();

        Opportunity oppAfterApproved = [
            SELECT Id, Amount
            FROM Opportunity
            WHERE Id = :linkedOppId
        ];
        System.assertEquals(
            (Decimal) 11111,
            oppAfterApproved.Amount,
            'Opportunity Amount should NOT change after Deal Registration is Approved.'
        );
    }
}
