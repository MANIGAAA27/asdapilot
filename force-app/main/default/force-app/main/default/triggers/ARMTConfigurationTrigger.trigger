/**
 * @file        ARMTConfigurationTrigger.trigger
 * @description After-insert and before-insert trigger on ARMT_Catalogue__c to prevent
 *              duplicate configuration records. Routes all DML events to
 *              ARMTConfigurationTriggerHandler. All logic lives in the handler
 *              (Sr Dev rule: no trigger body logic). Bulkified — handler operates
 *              on Trigger.new / Trigger.old lists.
 * @author      ASDA Dev Agent
 * @testClass   ARMT_ConfigurationScannerTest
 */
trigger ARMTConfigurationTrigger on ARMT_Catalogue__c (
    before insert,
    before update
) {
    ARMTConfigurationTriggerHandler handler = new ARMTConfigurationTriggerHandler();
    if (Trigger.isBefore && Trigger.isInsert) {
        handler.handleBeforeInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        handler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
