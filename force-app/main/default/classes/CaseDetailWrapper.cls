/**
 * @file              CaseDetailWrapper.cls
 * @description       Data transfer object returned by
 *                    AgentConsoleWorkspaceService.getCaseDetails(). Carries the
 *                    Case SObject together with its related Account and Contact
 *                    display fields so the LWC can render the Case Overview and
 *                    Customer Profile panels without additional wire calls.
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
public with sharing class CaseDetailWrapper {

    /** The core Case SObject, including all fields queried by the service. */
    @AuraEnabled public Case   caseRecord   { get; set; }

    /** Account.Name resolved from Case.AccountId at query time. */
    @AuraEnabled public String accountName  { get; set; }

    /** Contact.Name resolved from Case.ContactId at query time. */
    @AuraEnabled public String contactName  { get; set; }

    /** Contact.Email resolved from Case.ContactId at query time. */
    @AuraEnabled public String contactEmail { get; set; }

    /** Contact.Phone resolved from Case.ContactId at query time. */
    @AuraEnabled public String contactPhone { get; set; }
}
