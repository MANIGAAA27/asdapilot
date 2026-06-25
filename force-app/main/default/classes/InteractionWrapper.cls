/**
 * @file              InteractionWrapper.cls
 * @description       Data transfer object returned as a list element by
 *                    AgentConsoleWorkspaceService.getPreviousInteractions(). Provides
 *                    a normalised, type-agnostic shape for EmailMessage, Task, and
 *                    prior-Case records so the LWC Previous Interactions panel can
 *                    render them from a single list without type-branching in JS.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-25
 * @lastModified      2026-06-25
 * @group             AgentConsoleWorkspace
 *
 * @dependencies      (none)
 * @calledBy          AgentConsoleWorkspaceService
 * @testClass         AgentConsoleWorkspaceServiceTest
 *
 * @project           Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
 * @lld               LLD-AgentConsoleWorkspace
 */
// MODIFIED 2026-06-25 — Project: Agent Console Workspace | CodeImplementation-AgentConsoleWorkspace | ASDA
public with sharing class InteractionWrapper {

    /** Discriminator: 'Email' | 'Task' | 'Prior Case'. */
    @AuraEnabled public String   recordType   { get; set; }

    /** Subject line of the email or task; Subject of the prior Case. */
    @AuraEnabled public String   subject      { get; set; }

    /** Task status or Case status. Null for email rows. */
    @AuraEnabled public String   status       { get; set; }

    /** CreatedDate (email/task) or ClosedDate (prior case). */
    @AuraEnabled public DateTime activityDate { get; set; }

    /** Truncated body text (email TextBody / task Description). */
    @AuraEnabled public String   description  { get; set; }

    /** Sender address — populated for email rows only. */
    @AuraEnabled public String   fromAddress  { get; set; }

    /** CaseNumber — populated for prior-Case rows only. */
    @AuraEnabled public String   caseNumber   { get; set; }
}
