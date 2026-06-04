/**
 * @file              ManualInactivationController.cls
 * @description       Lightning Web Component controller for manual account inactivation
 * @author            ASDA Dev Agent
 * @created           2026-06-04
 * @group             InactivationLifecycle
 */
// MODIFIED 2026-06-04 — Project: Account Deactivation | Implementation - Automated Lifecycle Policy Engine Using Scheduled Flows and Asynchronous Apex (draft) | ASDA
public with sharing class ManualInactivationController {
    
    /**
     * Marks specified accounts as inactive
     * @param accountIds List of Account IDs to inactivate
     * @param reason Inactivation reason
     * @return Number of successfully inactivated accounts
     */
    @AuraEnabled
    public static Integer inactivateAccounts(List<Id> accountIds, String reason) {
        try {
            if (accountIds == null || accountIds.isEmpty()) {
                throw new AppException('Account IDs list cannot be empty');
            }
            
            if (!SecurityService.hasObjectAccess('Account', 'update')) {
                throw new AppException('Insufficient permissions to update accounts');
            }
            
            List<Account> accountsToUpdate = [
                SELECT Id, Is_Inactive__c 
                FROM Account 
                WHERE Id IN :accountIds 
                AND Is_Inactive__c = false
            ];
            
            if (accountsToUpdate.isEmpty()) {
                return 0;
            }
            
            for (Account acc : accountsToUpdate) {
                acc.Is_Inactive__c = true;
            }
            
            Database.SaveResult[] results = Database.update(accountsToUpdate, false);
            Integer successCount = 0;
            List<Governance_Log__c> logs = new List<Governance_Log__c>();
            
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    successCount++;
                    logs.add(new Governance_Log__c(
                        Parent_Object_Type__c = 'Account',
                        Parent_Record_Id__c = accountsToUpdate[i].Id,
                        Change_Type__c = 'Inactivated',
                        Change_Date__c = System.now(),
                        Reason__c = reason
                    ));
                } else {
                    for (Database.Error err : results[i].getErrors()) {
                        ErrorLogger.log('Account update failed: ' + err.getMessage(), 
                                      'ManualInactivationController.inactivateAccounts',
                                      'ERROR');
                    }
                }
            }
            
            if (!logs.isEmpty()) {
                Database.insert(logs, false);
            }
            
            return successCount;
            
        } catch (Exception e) {
            ErrorLogger.logException(e, 'ManualInactivationController.inactivateAccounts');
            throw new AppException('Failed to inactivate accounts: ' + e.getMessage(), e);
        }
    }
}
