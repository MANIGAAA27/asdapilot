@IsTest
private class TestOpportunityInteractionLogger {
    @IsTest
    static void testHappyPathSingleInteraction() {
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        OpportunityInteractionLogger.InteractionRequest req = new OpportunityInteractionLogger.InteractionRequest();
        req.opportunityId = opp.Id;
        req.recommendation = 'Follow up on stagnant opportunity';
        req.interactionType = 'Viewed';
        req.interactionDate = Date.today();
        req.comments = 'Reviewed by AE';

        Test.startTest();
        OpportunityInteractionLogger.InteractionResult res = OpportunityInteractionLogger.logInteraction(req);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertNotEquals(null, res.interactionLogId);

        OpportunityInteractionLog__c logRec = [
            SELECT Id, Opportunity__c, Recommendation__c, Interaction_Date__c
            FROM OpportunityInteractionLog__c
            WHERE Id = :res.interactionLogId
            LIMIT 1
        ];
        System.assertEquals(opp.Id, logRec.Opportunity__c);
        System.assertEquals('Follow up on stagnant opportunity', logRec.Recommendation__c);
    }

    @IsTest
    static void testNegativeInputMissingOpportunity() {
        OpportunityInteractionLogger.InteractionRequest req = new OpportunityInteractionLogger.InteractionRequest();
        req.recommendation = 'Missing opp';
        req.interactionType = 'Viewed';

        Test.startTest();
        Boolean threw = false;
        try {
            OpportunityInteractionLogger.logInteraction(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @IsTest
    static void testBulkProcessing() {
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 3; i++) {
            opps.add(new Opportunity(
                Name = 'Bulk Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        insert opps;

        List<OpportunityInteractionLogger.InteractionRequest> requests = new List<OpportunityInteractionLogger.InteractionRequest>();
        for (Opportunity opp : opps) {
            OpportunityInteractionLogger.InteractionRequest req = new OpportunityInteractionLogger.InteractionRequest();
            req.opportunityId = opp.Id;
            req.recommendation = 'Bulk recommendation';
            req.interactionType = 'Ignored';
            req.interactionDate = Date.today();
            requests.add(req);
        }

        Test.startTest();
        List<OpportunityInteractionLogger.InteractionResult> results = OpportunityInteractionLogger.logInteractions(requests);
        Test.stopTest();

        System.assertEquals(3, results.size());
        Integer successCount = 0;
        for (OpportunityInteractionLogger.InteractionResult res : results) {
            if (res.success) {
                successCount++;
            }
        }
        System.assertEquals(3, successCount);
    }

    @IsTest
    static void testDifferentUserContextScenario() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'tuser',
            Email = 'tuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'tuser.' + System.currentTimeMillis() + '@example.com'
        );
        insert u;

        Opportunity opp = new Opportunity(
            Name = 'User Context Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        System.runAs(u) {
            OpportunityInteractionLogger.InteractionRequest req = new OpportunityInteractionLogger.InteractionRequest();
            req.opportunityId = opp.Id;
            req.recommendation = 'Context check';
            req.interactionType = 'Updated';
            req.interactionDate = Date.today();

            Test.startTest();
            OpportunityInteractionLogger.InteractionResult res = OpportunityInteractionLogger.logInteraction(req);
            Test.stopTest();

            System.assertEquals(true, res.success);
        }
    }
}