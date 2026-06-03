/**
 * @file        OpportunityHealthServiceTest.cls
 * @description Tests OpportunityHealthService — covers stagnant detection,
 *              missing contacts, no scheduled meetings, stage-specific
 *              recommendations, and health score calculation.
 * @testFor     OpportunityHealthService
 * @coverage    Target ≥ 90%. Last measured N/A (initial implementation).
 */
@isTest
private class OpportunityHealthServiceTest {
    
    /**
     * Test setup creates shared test data for all test methods.
     */
    @testSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        List<Opportunity> opportunities = new List<Opportunity>();
        
        // Healthy opportunity: recent activity, contacts, upcoming meeting
        Opportunity healthyOpp = new Opportunity(
            Name = 'Healthy Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 50000
        );
        opportunities.add(healthyOpp);
        
        // Stagnant opportunity: no activity for 20 days
        Opportunity stagnantOpp = new Opportunity(
            Name = 'Stagnant Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(45),
            Amount = 75000
        );
        opportunities.add(stagnantOpp);
        
        // Opportunity with missing contacts
        Opportunity noContactsOpp = new Opportunity(
            Name = 'No Contacts Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Needs Analysis',
            CloseDate = Date.today().addDays(60),
            Amount = 100000
        );
        opportunities.add(noContactsOpp);
        
        insert opportunities;
        
        // Add contact role to healthy opportunity only
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        OpportunityContactRole contactRole = new OpportunityContactRole(
            OpportunityId = healthyOpp.Id,
            ContactId = testContact.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );
        insert contactRole;
        
        // Add upcoming meeting to healthy opportunity only
        Event upcomingMeeting = new Event(
            Subject = 'Discovery Call',
            WhatId = healthyOpp.Id,
            StartDateTime = Datetime.now().addDays(2),
            EndDateTime = Datetime.now().addDays(2).addHours(1),
            DurationInMinutes = 60
        );
        insert upcomingMeeting;
        
        // Simulate old last activity date for stagnant opportunity
        Test.setCreatedDate(stagnantOpp.Id, Datetime.now().addDays(-20));
    }
    
    /**
     * Tests analyzeOpportunities with valid input and default stagnant threshold.
     * Verifies that healthy opportunities have high scores and appropriate flags.
     */
    @isTest
    static void test_analyzeOpportunities_validInput_succeeds() {
        List<Opportunity> opps = [SELECT Id, Name, StageName, LastActivityDate, LastModifiedDate 
                                   FROM Opportunity 
                                   WHERE Name = 'Healthy Opportunity'];
        
        Test.startTest();
        List<OpportunityHealthService.OpportunityHealthResult> results = 
            OpportunityHealthService.analyzeOpportunities(opps, null);
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return one result');
        OpportunityHealthService.OpportunityHealthResult result = results[0];
        
        System.assertEquals(opps[0].Id, result.opportunityId, 'Opportunity ID should match');
        System.assertEquals('Healthy Opportunity', result.opportunityName, 'Opportunity name should match');
        System.assertEquals(false, result.isStagnant, 'Healthy opportunity should not be stagnant');
        System.assertEquals(false, result.hasMissingContacts, 'Should have contact roles');
        System.assertEquals(false, result.hasNoScheduledMeeting, 'Should have scheduled meeting');
        System.assert(result.overallHealthScore > 80, 'Healthy opportunity should have high score');
    }
    
    /**
     * Tests stagnant opportunity detection based on last activity threshold.
     * Verifies stagnant flag is set and appropriate recommendations generated.
     */
    @isTest
    static void test_analyzeOpportunities_stagnantDetected() {
        List<Opportunity> opps = [SELECT Id, Name, StageName, LastActivityDate, LastModifiedDate 
                                   FROM Opportunity 
                                   WHERE Name = 'Stagnant Opportunity'];
        
        Test.startTest();
        List<OpportunityHealthService.OpportunityHealthResult> results = 
            OpportunityHealthService.analyzeOpportunities(opps, 14);
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return one result');
        OpportunityHealthService.OpportunityHealthResult result = results[0];
        
        System.assertEquals(true, result.isStagnant, 'Opportunity should be flagged as stagnant');
        System.assert(result.riskFlags.size() > 0, 'Should have risk flags');
        System.assert(result.recommendations.size() > 0, 'Should have recommendations');
        System.assert(result.overallHealthScore < 100, 'Stagnant opportunity should have reduced score');
    }
    
    /**
     * Tests missing contacts detection.
     * Verifies hasMissingContacts flag and contact-related recommendations.
     */
    @isTest
    static void test_analyzeOpportunities_missingContactsDetected() {
        List<Opportunity> opps = [SELECT Id, Name, StageName, LastActivityDate, LastModifiedDate 
                                   FROM Opportunity 
                                   WHERE Name = 'No Contacts Opportunity'];
        
        Test.startTest();
        List<OpportunityHealthService.OpportunityHealthResult> results = 
            OpportunityHealthService.analyzeOpportunities(opps, 14);
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return one result');
        OpportunityHealthService.OpportunityHealthResult result = results[0];
        
        System.assertEquals(true, result.hasMissingContacts, 'Should flag missing contacts');
        Boolean hasContactRecommendation = false;
        for (String rec : result.recommendations) {
            if (rec.containsIgnoreCase('contact')) {
                hasContactRecommendation = true;
                break;
            }
        }
        System.assert(hasContactRecommendation, 'Should recommend adding contacts');
    }
    
    /**
     * Tests null and empty list handling.
     * Verifies method returns empty list without errors.
     */
    @isTest
    static void test_analyzeOpportunities_nullInput_returnsEmpty() {
        Test.startTest();
        List<OpportunityHealthService.OpportunityHealthResult> nullResults = 
            OpportunityHealthService.analyzeOpportunities(null, 14);
        List<OpportunityHealthService.OpportunityHealthResult> emptyResults = 
            OpportunityHealthService.analyzeOpportunities(new List<Opportunity>(), 14);
        Test.stopTest();
        
        System.assertEquals(0, nullResults.size(), 'Null input should return empty list');
        System.assertEquals(0, emptyResults.size(), 'Empty input should return empty list');
    }
    
    /**
     * Tests invalid stagnantDays parameter throws exception.
     */
    @isTest
    static void test_analyzeOpportunities_invalidThreshold_throws() {
        List<Opportunity> opps = [SELECT Id, Name, StageName, LastActivityDate, LastModifiedDate 
                                   FROM Opportunity 
                                   LIMIT 1];
        
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            OpportunityHealthService.analyzeOpportunities(opps, 0);
        } catch (OpportunityHealthService.OpportunityHealthServiceException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('stagnantDays'), 'Exception message should mention stagnantDays');
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw exception for invalid threshold');
    }
    
    /**
     * Tests bulk processing of 200 opportunities.
     * Verifies governor limits are not exceeded.
     */
    @isTest
    static void test_analyzeOpportunities_bulkProcessing_succeeds() {
        Account bulkAccount = new Account(Name = 'Bulk Test Account');
        insert bulkAccount;
        
        List<Opportunity> bulkOpps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            bulkOpps.add(new Opportunity(
                Name = 'Bulk Opp ' + i,
                AccountId = bulkAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Amount = 10000
            ));
        }
        insert bulkOpps;
        
        Test.startTest();
        List<OpportunityHealthService.OpportunityHealthResult> results = 
            OpportunityHealthService.analyzeOpportunities(bulkOpps, 14);
        Test.stopTest();
        
        System.assertEquals(200, results.size(), 'Should process all 200 opportunities');
        System.assert(Limits.getQueries() < Limits.getLimitQueries(), 'Should not exceed SOQL query limits');
    }
}
