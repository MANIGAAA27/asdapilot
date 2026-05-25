/**
 * Canonical Apex class template.
 *
 * Conventions:
 *  - `public with sharing` is the default. Use `without sharing` only when you
 *    need to bypass row-level security AND have written a comment explaining why.
 *  - `@AuraEnabled(cacheable=true)` for read-only LWC controller methods,
 *    plain `@AuraEnabled` for writes.
 *  - Catch parameter MUST NOT be named `exception` — that identifier is reserved.
 *    Use `Exception ex` or `Exception e`.
 *  - No SOQL or DML inside loops (Code Quality Standards).
 *  - WITH SECURITY_ENFORCED on every SOQL query that returns user-visible data.
 *  - Every Apex class needs a paired .cls-meta.xml with <apiVersion>62.0</apiVersion>.
 */
public with sharing class MyController {

    /**
     * Read-only LWC controller method. Returns a small projection.
     * Bulkified by accepting / returning a List<>.
     */
    @AuraEnabled(cacheable=true)
    public static List<My_Object__c> getRecentRecords(Integer recordLimit) {
        if (recordLimit == null || recordLimit <= 0) {
            recordLimit = 25;
        }
        return [
            SELECT Id, Name, My_Field__c
            FROM My_Object__c
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT :recordLimit
        ];
    }

    /**
     * Write method. Plain @AuraEnabled (not cacheable).
     */
    @AuraEnabled
    public static Id createRecord(String fieldValue) {
        if (String.isBlank(fieldValue)) {
            throw new AuraHandledException('My Field is required.');
        }
        My_Object__c record = new My_Object__c(My_Field__c = fieldValue);
        try {
            insert record;
        } catch (DmlException ex) {
            // Note: the catch parameter is named `ex`, NOT `exception` (reserved identifier).
            throw new AuraHandledException('Failed to save record: ' + ex.getMessage());
        }
        return record.Id;
    }
}
