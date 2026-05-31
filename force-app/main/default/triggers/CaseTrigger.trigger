/**
  @file              CaseTrigger.trigger
  @description       Trigger to initiate handling when a Case is updated.
  @author            ASDA Dev Agent
  @lastModified      2026-05-30
  @dependencies      CaseTriggerHandler
  @calledBy          (none in this changeset)
  @testClass         CaseTriggerTest
 /
trigger CaseTrigger on Case (after update) {
    CaseTriggerHandler.handleAfterUpdate(Trigger.new);
}