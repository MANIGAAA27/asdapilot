/**
 * @file              SecurityService.cls
 * @description       Centralized security service for FLS and object-level permission checks
 * @author            ASDA Dev Agent
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             CaseTransfer
 * @testClass         SecurityServiceTest
 */
public with sharing class SecurityService {
    
    /**
     * Checks if current user has read access to specified fields on an object.
     * @param objectName API name of the SObject
     * @param fieldNames List of field API names to check
     * @return true if user has read access to all fields
     */
    public static Boolean hasFieldReadAccess(String objectName, List<String> fieldNames) {
        try {
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
            
            for (String fieldName : fieldNames) {
                if (!fieldMap.containsKey(fieldName)) {
                    return false;
                }
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                if (!fieldDescribe.isAccessible()) {
                    return false;
                }
            }
            return true;
        } catch (Exception ex) {
            ErrorLogger.logException(ex, 'SecurityService.hasFieldReadAccess');
            return false;
        }
    }

    /**
     * Checks if current user has update access to specified fields on an object.
     * @param objectName API name of the SObject
     * @param fieldNames List of field API names to check
     * @return true if user has update access to all fields
     */
    public static Boolean hasFieldUpdateAccess(String objectName, List<String> fieldNames) {
        try {
            Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
            
            for (String fieldName : fieldNames) {
                if (!fieldMap.containsKey(fieldName)) {
                    return false;
                }
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                if (!fieldDescribe.isUpdateable()) {
                    return false;
                }
            }
            return true;
        } catch (Exception ex) {
            ErrorLogger.logException(ex, 'SecurityService.hasFieldUpdateAccess');
            return false;
        }
    }
}
