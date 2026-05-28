/**
 * FileService
 *
 * Apex controller for the File Viewer LWC. Aggregates files from a parent
 * record plus its child and related lookup records by querying
 * ContentDocumentLink, then enriching with ContentDocument metadata.
 *
 * Governor-limit strategy:
 *  - collectChildRecordIds caps at MAX_CHILD_RELATIONSHIPS dynamic queries.
 *  - A single ContentDocumentLink query covers ALL collected IDs at once.
 *  - A single ContentDocument query retrieves file metadata.
 *  - Total SOQL calls: ≤ MAX_CHILD_RELATIONSHIPS + 2 per transaction.
 */
public with sharing class FileService {

    /** Maximum child relationships to traverse when collecting related records. */
    private static final Integer MAX_CHILD_RELATIONSHIPS = 50;

    /** Maximum child records returned per relationship query. */
    private static final Integer MAX_CHILD_RECORDS_PER_REL = 50;

    /** Hard ceiling on files returned to the LWC. */
    private static final Integer MAX_FILES = 200;

    // -----------------------------------------------------------------------
    // Public inner class — wire-serialisable file metadata wrapper
    // -----------------------------------------------------------------------

    /** Serialisable wrapper returned to the LWC datatable. */
    public class FileWrapper {
        @AuraEnabled public String contentDocumentId { get; set; }
        @AuraEnabled public String title            { get; set; }
        @AuraEnabled public String fileType         { get; set; }
        @AuraEnabled public Long   contentSize      { get; set; }
        @AuraEnabled public String fileSizeFormatted{ get; set; }
        @AuraEnabled public String relatedRecordId  { get; set; }
        @AuraEnabled public String relatedRecordName{ get; set; }
        @AuraEnabled public String createdByName    { get; set; }
        @AuraEnabled public DateTime createdDate    { get; set; }
        @AuraEnabled public String fileUrl          { get; set; }
    }

    // -----------------------------------------------------------------------
    // AuraEnabled methods
    // -----------------------------------------------------------------------

    /**
     * Returns file metadata for the given record and all its child / related
     * lookup records. Deduplicates files linked to more than one record.
     *
     * @param recordId  Salesforce record Id (String to match LWC wire param).
     * @return          List of FileWrapper, sorted by CreatedDate descending.
     */
    @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getRelatedFiles(String recordId) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Record ID is required.');
        }

        SecurityService.enforceContentDocumentAccess();

        Id parentId = (Id) recordId;
        String objectApiName = parentId.getSObjectType().getDescribe().getName();

        // Collect parent + child record IDs
        Set<Id> allRecordIds = new Set<Id>{ parentId };
        try {
            collectChildRecordIds(parentId, objectApiName, allRecordIds);
        } catch (Exception ex) {
            // Proceed with just the parent if child collection fails
        }

        // Single bulk query for all ContentDocumentLinks
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId, LinkedEntity.Name
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :allRecordIds
        ];

        if (links.isEmpty()) {
            return new List<FileWrapper>();
        }

        // Deduplicate: first link encountered per ContentDocumentId wins
        Map<Id, Id>     docToLinkedEntityId   = new Map<Id, Id>();
        Map<Id, String> docToLinkedEntityName = new Map<Id, String>();

        for (ContentDocumentLink link : links) {
            if (!docToLinkedEntityId.containsKey(link.ContentDocumentId)) {
                docToLinkedEntityId.put(link.ContentDocumentId, link.LinkedEntityId);
                SObject linkedEntity = link.getSObject('LinkedEntity');
                String entityName = linkedEntity != null
                    ? (String) linkedEntity.get('Name')
                    : '';
                docToLinkedEntityName.put(link.ContentDocumentId, entityName);
            }
        }

        Set<Id> docIds = docToLinkedEntityId.keySet();

        // Bulk query for file metadata — WITH SECURITY_ENFORCED enforces FLS
        List<ContentDocument> docs = [
            SELECT Id, Title, FileType, ContentSize, CreatedBy.Name, CreatedDate
            FROM ContentDocument
            WHERE Id IN :docIds
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT :MAX_FILES
        ];

        List<FileWrapper> result = new List<FileWrapper>();
        for (ContentDocument doc : docs) {
            FileWrapper fw = new FileWrapper();
            fw.contentDocumentId  = doc.Id;
            fw.title              = doc.Title;
            fw.fileType           = doc.FileType;
            fw.contentSize        = doc.ContentSize;
            fw.fileSizeFormatted  = formatFileSize(doc.ContentSize);
            fw.relatedRecordId    = String.valueOf(docToLinkedEntityId.get(doc.Id));
            fw.relatedRecordName  = docToLinkedEntityName.get(doc.Id);
            fw.createdByName      = doc.CreatedBy != null ? doc.CreatedBy.Name : '';
            fw.createdDate        = doc.CreatedDate;
            fw.fileUrl            = '/sfc/servlet.shepherd/document/download/' + doc.Id;
            result.add(fw);
        }

        return result;
    }

    /**
     * Returns the Salesforce object API name for the given record Id.
     * Used by the LWC for context detection (FR2).
     *
     * @param recordId  Salesforce record Id (String).
     * @return          e.g. 'Account', 'Contact', 'My_Custom_Object__c'
     */
    @AuraEnabled(cacheable=true)
    public static String getObjectApiName(String recordId) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Record ID is required.');
        }
        Id id = (Id) recordId;
        return id.getSObjectType().getDescribe().getName();
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /**
     * Populates allRecordIds with the Ids of child records related to
     * parentId via child relationships. Caps queries at MAX_CHILD_RELATIONSHIPS
     * and skips system / audit objects.
     */
    private static void collectChildRecordIds(
        Id parentId,
        String objectApiName,
        Set<Id> allRecordIds
    ) {
        Schema.DescribeSObjectResult parentDescribe =
            Schema.getGlobalDescribe().get(objectApiName).getDescribe();
        List<Schema.ChildRelationship> childRelationships =
            parentDescribe.getChildRelationships();

        Integer queryCount = 0;
        for (Schema.ChildRelationship rel : childRelationships) {
            if (queryCount >= MAX_CHILD_RELATIONSHIPS) {
                break;
            }

            Schema.DescribeSObjectResult childDescribe =
                rel.getChildSObject().getDescribe();

            if (!childDescribe.isAccessible() || !childDescribe.isQueryable()) {
                continue;
            }

            String childObjName = childDescribe.getName();
            if (isSystemObject(childObjName)) {
                continue;
            }

            String fieldName = rel.getField().getDescribe().getName();

            try {
                // Dynamic SOQL — childObjName and fieldName come from trusted
                // Schema describe (not user input); parentId is a bind variable.
                String query =
                    'SELECT Id FROM ' + childObjName +
                    ' WHERE ' + fieldName +
                    ' = :parentId LIMIT ' + MAX_CHILD_RECORDS_PER_REL;
                List<SObject> children = Database.query(query);
                for (SObject child : children) {
                    allRecordIds.add(child.Id);
                }
                queryCount++;
            } catch (Exception ex) {
                // Skip relationships that cannot be queried in this context
            }
        }
    }

    /**
     * Returns true for object types that should be excluded from child
     * traversal — audit trails, share objects, feeds, and file-related objects
     * that would create circular references.
     */
    private static Boolean isSystemObject(String objName) {
        return objName.endsWith('__History')
            || objName.endsWith('__Share')
            || objName.endsWith('__Feed')
            || objName.endsWith('__ChangeEvent')
            || objName == 'ContentDocumentLink'
            || objName == 'ContentDocument'
            || objName == 'ContentVersion'
            || objName == 'Note'
            || objName == 'Attachment'
            || objName == 'EntitySubscription'
            || objName == 'FlowRecordRelation'
            || objName == 'ProcessInstance'
            || objName == 'ProcessInstanceWorkitem';
    }

    /**
     * Formats a file size in bytes to a human-readable KB or MB string.
     *
     * @param bytes  File size in bytes (may be null).
     * @return       e.g. '1 KB', '2.50 MB'
     */
    private static String formatFileSize(Long bytes) {
        if (bytes == null || bytes == 0) {
            return '0 KB';
        }
        if (bytes >= 1048576L) {
            Decimal mb = (Decimal.valueOf(bytes) / 1048576).setScale(2);
            return mb + ' MB';
        }
        Long kb = bytes < 1024L ? 1L : bytes / 1024L;
        return kb + ' KB';
    }
}