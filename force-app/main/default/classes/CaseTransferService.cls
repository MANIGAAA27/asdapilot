public with sharing class CaseTransferService {
    public class TransferValidationResult {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public List<String> messages;
        @AuraEnabled public Integer fileCount;
        public TransferValidationResult() {
            isValid = true;
            messages = new List<String>();
            fileCount = 0;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Id getEngineeringQueueId() {
        List<Group> groups = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND Name = :CaseTransferConstants.ENGINEERING_QUEUE_NAME
            LIMIT 1
        ];
        return groups.isEmpty() ? null : groups[0].Id;
    }

    @AuraEnabled(cacheable=true)
    public static TransferValidationResult validateCaseTransfer(Id caseId) {
        TransferValidationResult result = new TransferValidationResult();
        if (caseId == null) {
            result.isValid = false;
            result.messages.add(CaseTransferConstants.ERROR_GENERIC);
            return result;
        }

        Case caseRecord = [
            SELECT Id, OwnerId, Troubleshooting_Steps__c, Reproduction_Steps__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        Integer fileCount = [
            SELECT Count()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :caseId
        ];
        result.fileCount = fileCount;

        if (fileCount <= 0) {
            result.isValid = false;
            result.messages.add(CaseTransferConstants.ERROR_ATTACHMENTS);
        }
        if (String.isBlank(caseRecord.Reproduction_Steps__c)) {
            result.isValid = false;
            result.messages.add(CaseTransferConstants.ERROR_REPRO_STEPS);
        }
        if (String.isBlank(caseRecord.Troubleshooting_Steps__c) ||
            caseRecord.Troubleshooting_Steps__c.trim().length() < CaseTransferConstants.TROUBLESHOOTING_MIN_LENGTH) {
            result.isValid = false;
            result.messages.add(CaseTransferConstants.ERROR_TROUBLESHOOTING);
        }
        return result;
    }

    @AuraEnabled
    public static Id submitTransfer(Id caseId, String troubleshootingSteps, List<String> reproductionSteps) {
        if (caseId == null) {
            throw new AuraHandledException(CaseTransferConstants.ERROR_GENERIC);
        }
        if (String.isBlank(troubleshootingSteps) ||
            troubleshootingSteps.trim().length() < CaseTransferConstants.TROUBLESHOOTING_MIN_LENGTH) {
            throw new AuraHandledException(CaseTransferConstants.ERROR_TROUBLESHOOTING);
        }
        if (reproductionSteps == null || reproductionSteps.isEmpty()) {
            throw new AuraHandledException(CaseTransferConstants.ERROR_REPRO_STEPS);
        }

        Integer fileCount = [
            SELECT Count()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :caseId
        ];
        if (fileCount <= 0) {
            throw new AuraHandledException(CaseTransferConstants.ERROR_ATTACHMENTS);
        }

        Id engineeringQueueId = getEngineeringQueueId();
        if (engineeringQueueId == null) {
            throw new AuraHandledException('Engineering queue was not found.');
        }

        Case caseUpdate = new Case(
            Id = caseId,
            Troubleshooting_Steps__c = troubleshootingSteps.trim(),
            Reproduction_Steps__c = String.join(reproductionSteps, ';'),
            OwnerId = engineeringQueueId,
            Transfer_Submitted_To_Engineering__c = true,
            Transferred_To_Engineering_By__c = UserInfo.getUserId(),
            Transferred_To_Engineering_On__c = System.now()
        );
        update caseUpdate;
        return caseId;
    }
}
