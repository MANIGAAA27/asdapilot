/**
 * @file        AccountTriggerHandler.trigger
 * @description Routes Account DML events to AccountTriggerHandler.
 *              All business logic lives in the handler class (Sr Dev rule:
 *              no trigger body logic). Bulkified — handler operates on
 *              Trigger.new / Trigger.old lists.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-06-22
 * @testClass   AccountTriggerHandlerTest
 *
 * @see         HLD-CMP-005 AccountTriggerHandler
 */
// MODIFIED 2026-06-22 — Project: Account 360 | LLD-Account360-1 (BR1-BR2) | ASDA
trigger AccountTriggerHandler on Account (after update) {
    new AccountTriggerHandler().run();
}
