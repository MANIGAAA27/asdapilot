/**
 * SecurityService
 *
 * Helper class that checks user permissions and enforces security compliance
 * for the File Viewer component. Uses Schema describe calls — no SOQL.
 */
// MODIFIED 2026-06-08 — Project: Gift Basket | CodeImplementation-GiftBasket | ASDA
public with sharing class SecurityService {

    /**
     * Returns true when the running user can read both ContentDocument
     * and ContentDocumentLink. Called from LWC before rendering the table.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasContentDocumentAccess() {
        return Schema.SObjectType.ContentDocument.isAccessible()
            && Schema.SObjectType.ContentDocumentLink.isAccessible();
    }

    /**
     * Throws AuraHandledException when the running user cannot read
     * ContentDocument or ContentDocumentLink. Called by FileService before
     * executing any queries.
     */
    public static void enforceContentDocumentAccess() {
        if (!Schema.SObjectType.ContentDocument.isAccessible()) {
            throw new AuraHandledException(
                'Insufficient access to ContentDocument. Please contact your administrator.'
            );
        }
        if (!Schema.SObjectType.ContentDocumentLink.isAccessible()) {
            throw new AuraHandledException(
                'Insufficient access to ContentDocumentLink. Please contact your administrator.'
            );
        }
    }

    /**
     * Returns true when the running user has read access to the given
     * object API name. Used by FileService when iterating child relationships.
     */
    public static Boolean isObjectAccessible(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return false;
        }
        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectApiName);
        return sType != null && sType.getDescribe().isAccessible();
    }
}
