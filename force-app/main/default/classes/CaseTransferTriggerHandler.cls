public with sharing class CaseTransferTriggerHandler {
    public static void beforeUpdate(List<Case> newList, Map<Id, Case> oldMap) {
        Id engineeringQueueId = CaseTransferService.getEngineeringQueueId();
        if (engineeringQueueId == null) {
            return;
        }

        for (Case caseRecord : newList) {
            Case oldRecord = oldMap.get(caseRecord.Id);
            if (oldRecord == null) {
                continue;
            }

            Boolean ownerChangedToEngineering = caseRecord.OwnerId == engineeringQueueId && oldRecord.OwnerId != engineeringQueueId;
            if (!ownerChangedToEngineering) {
                continue;
            }

            if (caseRecord.Transfer_Submitted_To_Engineering__c == true) {
                continue;
            }

            Integer fileCount = [
                SELECT Count()
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :caseRecord.Id
            ];

            List<String> errors = new List<String>();
            if (fileCount <= 0) {
                errors.add(CaseTransferConstants.ERROR_ATTACHMENTS);
            }
            if (String.isBlank(caseRecord.Reproduction_Steps__c)) {
                errors.add(CaseTransferConstants.ERROR_REPRO_STEPS);
            }
            if (String.isBlank(caseRecord.Troubleshooting_Steps__c) ||
                caseRecord.Troubleshooting_Steps__c.trim().length() < CaseTransferConstants.TROUBLESHOOTING_MIN_LENGTH) {
                errors.add(CaseTransferConstants.ERROR_TROUBLESHOOTING);
            }

            if (!errors.isEmpty()) {
                caseRecord.addError(String.join(errors, ' '));
            }
        }
    }
}
