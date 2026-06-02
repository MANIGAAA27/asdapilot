public with sharing class OpportunityInteractionLogger {
    public class InteractionRequest {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String recommendation;
        @AuraEnabled public String interactionType;
        @AuraEnabled public Date interactionDate;
        @AuraEnabled public String comments;
    }

    public class InteractionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id interactionLogId;
    }

    @AuraEnabled
    public static InteractionResult logInteraction(InteractionRequest request) {
        InteractionResult result = new InteractionResult();
        if (request == null) {
            throw new AuraHandledException('Interaction request is required.');
        }
        if (request.opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }
        if (String.isBlank(request.recommendation)) {
            throw new AuraHandledException('Recommendation is required.');
        }
        if (String.isBlank(request.interactionType)) {
            throw new AuraHandledException('Interaction type is required.');
        }

        OpportunityInteractionLog__c logRecord = new OpportunityInteractionLog__c();
        logRecord.Opportunity__c = request.opportunityId;
        logRecord.Recommendation__c = request.recommendation.trim();
        logRecord.Interaction_Date__c = System.now();

        if (request.interactionDate != null) {
            logRecord.Interaction_Date__c = DateTime.newInstance(request.interactionDate, Time.newInstance(0, 0, 0, 0));
        }

        List<OpportunityInteractionLog__c> logsToInsert = new List<OpportunityInteractionLog__c>();
        logsToInsert.add(logRecord);

        insert logsToInsert;

        result.success = true;
        result.message = 'Interaction logged successfully.';
        result.interactionLogId = logRecord.Id;
        return result;
    }

    @AuraEnabled
    public static List<InteractionResult> logInteractions(List<InteractionRequest> requests) {
        List<InteractionResult> results = new List<InteractionResult>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        List<OpportunityInteractionLog__c> logsToInsert = new List<OpportunityInteractionLog__c>();
        Integer validRequestCount = 0;

        for (InteractionRequest request : requests) {
            InteractionResult rowResult = new InteractionResult();
            if (request == null || request.opportunityId == null || String.isBlank(request.recommendation) || String.isBlank(request.interactionType)) {
                rowResult.success = false;
                rowResult.message = 'Invalid interaction request.';
                results.add(rowResult);
                continue;
            }

            OpportunityInteractionLog__c logRecord = new OpportunityInteractionLog__c();
            logRecord.Opportunity__c = request.opportunityId;
            logRecord.Recommendation__c = request.recommendation.trim();
            logRecord.Interaction_Date__c = request.interactionDate != null
                ? DateTime.newInstance(request.interactionDate, Time.newInstance(0, 0, 0, 0))
                : System.now();
            logsToInsert.add(logRecord);
            results.add(rowResult);
            validRequestCount++;
        }

        if (!logsToInsert.isEmpty()) {
            insert logsToInsert;
            Integer logIndex = 0;
            for (Integer i = 0; i < requests.size(); i++) {
                InteractionRequest request = requests[i];
                if (request != null && request.opportunityId != null && !String.isBlank(request.recommendation) && !String.isBlank(request.interactionType)) {
                    results[i].success = true;
                    results[i].message = 'Interaction logged successfully.';
                    results[i].interactionLogId = logsToInsert[logIndex].Id;
                    logIndex++;
                }
            }
        }

        return results;
    }
}