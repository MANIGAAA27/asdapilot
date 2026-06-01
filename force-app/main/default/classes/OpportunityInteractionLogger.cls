public with sharing class OpportunityInteractionLogger {
    public class InteractionRequest {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String interactionType;
        @AuraEnabled public Date interactionDate;
        @AuraEnabled public String comments;
    }

    public class InteractionResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id interactionLogId;
    }

    @AuraEnabled
    public static InteractionResponse logInteraction(InteractionRequest request) {
        InteractionResponse response = new InteractionResponse();
        if (request == null) {
            response.success = false;
            response.message = 'Request is required.';
            return response;
        }
        if (request.opportunityId == null) {
            response.success = false;
            response.message = 'Opportunity Id is required.';
            return response;
        }
        if (String.isBlank(request.interactionType)) {
            response.success = false;
            response.message = 'Interaction Type is required.';
            return response;
        }
        if (request.interactionDate == null) {
            response.success = false;
            response.message = 'Interaction Date is required.';
            return response;
        }

        OpportunityInteractionLog__c logRecord = new OpportunityInteractionLog__c();
        logRecord.Opportunity__c = request.opportunityId;
        logRecord.Recommendation__c = request.interactionType;
        logRecord.Interaction_Date__c = System.now();

        if (Schema.sObjectType.OpportunityInteractionLog__c.fields.getMap().containsKey('Comments__c')) {
            logRecord.put('Comments__c', request.comments);
        }
        if (Schema.sObjectType.OpportunityInteractionLog__c.fields.getMap().containsKey('InteractionDate__c')) {
            logRecord.put('InteractionDate__c', request.interactionDate);
        }
        if (Schema.sObjectType.OpportunityInteractionLog__c.fields.getMap().containsKey('InteractionType__c')) {
            logRecord.put('InteractionType__c', request.interactionType);
        }

        insert logRecord;

        response.success = true;
        response.message = 'Interaction logged successfully.';
        response.interactionLogId = logRecord.Id;
        return response;
    }
}
