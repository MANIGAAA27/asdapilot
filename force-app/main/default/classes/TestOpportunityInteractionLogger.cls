```apex
/**
  @file        TestOpportunityInteractionLogger.cls
  @description Tests OpportunityInteractionLogger — covers happy path, invalid
               parameters, bulk 200+ records, and different user contexts.
  @testFor     OpportunityInteractionLogger
  @coverage    Target >= 90%.
 */
@isTest
private class TestOpportunityInteractionLogger {

    // -------------------------------------------------------------------------
    // Test data setup
    // -------------------------------------------------------------------------

    @testSetup
    static void setupTestData() {
        // Insert a single Opportunity to use across test methods.
        Account acct = new Account(Name = 'Test Account');
        insert acct;

        Opportunity opp = new Opportunity(
            Name        = 'Test Opportunity',
            AccountId   = acct.Id,
            StageName   = 'Prospecting',
            CloseDate   = Date.today().addDays(30)
        );
        insert opp;
    }

    /** Returns the Id of the test Opportunity. */
    private static Id getTestOppId() {
        return [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1].Id;
    }

    // -------------------------------------------------------------------------
    // Happy path
    // -------------------------------------------------------------------------

    @isTest
    static void testLogInteraction_HappyPath() {
        Id oppId = getTestOppId();

        Test.startTest();
        OpportunityInteractionLogger.logInteraction(oppId, 'REC-001');
        Test