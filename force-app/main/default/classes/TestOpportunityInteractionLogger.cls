@IsTest
private class TestOpportunityInteractionLogger {
    @IsTest
    static void testHappyPath() {
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        OpportunityInteractionLogger.InteractionRequest req = new OpportunityInteractionLogger.InteractionRequest();
        req.opportunityId = opp.Id;
        req.interactionType = 'Viewed';
        req.interactionDate = Date.today();
        req.comments = 'Reviewed by AE';

        Test.startTest();
        OpportunityInteractionLogger.InteractionResponse res = OpportunityInteractionLogger.logInteraction(req);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertNotEquals(null, res.interactionLogId);
    }

    @IsTest
    static void testNegativeInput() {
        Test.startTest();
        OpportunityInteractionLogger.InteractionResponse res = OpportunityInteractionLogger.logInteraction(null);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals('Request is required.', res.message);
    }

    @IsTest
    static void testBulkProcessing() {
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 5; i++) {
            opps.add(new Opportunity(
                Name = 'Bulk Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        insert opps;

        List<OpportunityInteractionLog__c> logs = new List<OpportunityInteractionLog__c>();
        for (Opportunity opp : opps) {
            OpportunityInteractionLogger.InteractionRequest req = new OpportunityInteractionLogger.InteractionRequest();
            req.opportunityId = opp.Id;
            req.interactionType = 'Ignored';
            req.interactionDate = Date.today();
            req.comments = 'Bulk test';
            OpportunityInteractionLogger.InteractionResponse res = OpportunityInteractionLogger.logInteraction(req);
            System.assertEquals(true, res.success);
            logs.add([SELECT Id, Opportunity__c FROM OpportunityInteractionLog__c WHERE Id = :res.interactionLogId LIMIT 1]);
        }
        System.assertEquals(5, logs.size());
    }

    @IsTest
    static void testDifferentUserContextScenario() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'tuser',
            Email = 'tuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'tuser' + System.currentTimeMillis() + '@example.com'
        );
        insert u;

        System.runAs(u) {
            Opportunity opp = new Opportunity(
                Name = 'RunAs Opp',
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
            insert opp;

            OpportunityInteractionLogger.InteractionRequest req = new OpportunityInteractionLogger.InteractionRequest();
            req.opportunityId = opp.Id;
            req.interactionType = 'Updated';
            req.interactionDate = Date.today();
            req.comments = 'RunAs test';

            Test.startTest();
            OpportunityInteractionLogger.InteractionResponse res = OpportunityInteractionLogger.logInteraction(req);
            Test.stopTest();

            System.assertEquals(true, res.success);
        }
    }
}
