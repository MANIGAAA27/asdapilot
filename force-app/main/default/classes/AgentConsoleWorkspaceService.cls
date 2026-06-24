// MODIFIED 2026-06-24 — Project: Agent Console Workspace | LLD-AgentConsoleWorkspace | ASDA
SELECT Id, CaseNumber, Subject, Status, Priority, Origin,
                   Description, IsClosed, ClosedDate, CreatedDate, IsEscalated,
                   ContactId, AccountId, OwnerId,
                   Workspace_Used__c, Workspace_Opened_At__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1