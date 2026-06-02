trigger CaseTransferTrigger on Case (before update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        CaseTransferTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
