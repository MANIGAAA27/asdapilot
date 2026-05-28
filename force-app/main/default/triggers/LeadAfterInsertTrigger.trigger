/**
 * @file        LeadAfterInsertTrigger.trigger
 * @description Routes Lead after-insert events to LeadContactHandler.
 *              All logic lives in the handler class (Sr Dev rule: no trigger
 *              body logic). Bulkified — handler operates on Trigger.new list.
 *              Creates one Contact record per newly inserted Lead.
 * @author      ASDA Dev Agent (Claude Code)
 * @created     2026-05-28
 * @lastModified 2026-05-28
 * @group       LeadAutomation
 * @testClass   LeadContactHandlerTest
 */
trigger LeadAfterInsertTrigger on Lead (after insert) {
    new LeadContactHandler().processLeads(Trigger.new);
}