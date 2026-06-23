/**
 * @file        ARM_MigrationTrigger.trigger
 * @description Routes ARM_MigrationAudit__c DML events to MigrationProcessHandler.
 *              All logic lives in the handler (Sr Dev rule §6: no trigger body logic).
 *              After insert: enqueues async migration jobs for records with Status = 'New'.
 *              Bulkified — handler operates on Trigger.new list.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-23
 * @testClass   MigrationProcessHandlerTest
 */
// MODIFIED 2026-06-23 — Project: Salesforce CPQ to Salesforce Salesforce Agentforce Revenue Management (ARM) | LLD-SalesforceCPQtoSalesforceSalesforceAgentforceRevenueManagementARM-1 (BR1-BR2) | ASDA
trigger ARM_MigrationTrigger on ARM_MigrationAudit__c (after insert) {
    MigrationProcessHandler.handleAfterInsert(Trigger.new);
}
