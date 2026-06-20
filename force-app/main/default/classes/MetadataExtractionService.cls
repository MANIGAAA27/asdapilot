/**
 * @file              MetadataExtractionService.cls
 * @description       Extracts Flow dependency metadata from the Salesforce Tooling API.
 *                    Fetches active Flow definitions and parses their structures to
 *                    identify relationships with objects, Apex classes, and subflows.
 *                    Uses HTTP callouts to the Tooling API REST endpoint.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-20
 * @lastModified      2026-06-20
 * @group             FlowDependencyVisualizer
 *
 * @dependencies      (none in this changeset)
 * @calledBy          DataRefreshHandler
 * @testClass         MetadataExtractionServiceTest
 *
 * @see               LLD-FlowDependencyVisualizer (Project: Flow Dependency Visualizer)
 */
// MODIFIED 2026-06-20 — Project: Flow Dependency Visualizer | LLD-FlowDependencyVisualizer | ASDA
public with sharing class MetadataExtractionService {

    private static final String TOOLING_API_PATH = '/services/data/v60.0/tooling/';
    private static final Integer HTTP_TIMEOUT_MS  = 120000;
    private static final Integer MAX_FLOWS_PER_CALL = 50;

    // ─── Inner Types ─────────────────────────────────────────────────────────

    /**
     * Lightweight summary of a Flow version returned from the initial list query.
     */
    public class FlowSummary {
        public String flowId;
        public String apiName;
        public String label;
        public String status;
        public String processType;
    }

    /**
     * Represents a single dependency edge extracted from a Flow definition.
     */
    public class FlowDependency {
        public String flowApiName;
        public String flowLabel;
        public String sourceComponentName;
        public String sourceComponentType;
        public String sourceComponentId;
        public String targetComponentName;
        public String targetComponentType;
        public String relationshipType;
        public Boolean isDirect;
        public Integer dependencyDepth;

        /** Constructs a direct, depth-1 dependency. */
        public FlowDependency() {
            this.isDirect        = true;
            this.dependencyDepth = 1;
            this.sourceComponentType = 'Flow';
        }
    }

    /** Custom exception raised when Tooling API calls fail. */
    public class MetadataExtractionServiceException extends Exception {}

    // ─── Public API ──────────────────────────────────────────────────────────

    /**
     * Fetches the list of all active Flows from the Tooling API.
     * Each call consumes 1 of the transaction's 100 HTTP callout slots.
     *
     * @return List of FlowSummary descriptors (Id, ApiName, Label, ProcessType).
     * @throws MetadataExtractionServiceException on non-200 HTTP response.
     *
     * @calledBy    DataRefreshHandler.execute(QueueableContext)
     * @testMethods fetchActiveFlows_returnsFlowList, fetchActiveFlows_httpErrorThrows
     */
    public List<FlowSummary> fetchActiveFlows() {
        String soql = 'SELECT+Id,ApiName,Label,Status,ProcessType+FROM+Flow'
                    + '+WHERE+Status+=+\'Active\''
                    + '+LIMIT+' + MAX_FLOWS_PER_CALL;
        HttpResponse resp = sendToolingRequest('query?q=' + soql);
        return parseFlowListResponse(resp.getBody());
    }

    /**
     * Fetches the complete metadata for a single Flow via its Tooling API record ID.
     * Each call consumes 1 of the transaction's 100 HTTP callout slots.
     *
     * @param  flowId  18-character Tooling API Id of the Flow SObject record.
     * @return Deserialized JSON map containing the Metadata field and record attributes.
     * @throws MetadataExtractionServiceException on non-200 HTTP response.
     *
     * @calledBy    DataRefreshHandler.execute(QueueableContext)
     * @testMethods fetchFlowMetadata_returnsMetadataMap, fetchFlowMetadata_httpErrorThrows
     */
    public Map<String, Object> fetchFlowMetadata(String flowId) {
        if (String.isBlank(flowId)) {
            throw new MetadataExtractionServiceException('flowId must not be blank.');
        }
        HttpResponse resp = sendToolingRequest('sobjects/Flow/' + flowId + '?fields=Id,ApiName,Label,Status,ProcessType,Metadata');
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
        return result;
    }

    /**
     * Parses a Flow's raw Tooling API metadata map into structured FlowDependency records.
     * Extracts: trigger object, record creates/updates/reads/deletes, subflow refs, Apex calls.
     *
     * @param  summary   FlowSummary describing the parent Flow.
     * @param  flowData  Raw Tooling API response map (must include 'Metadata' key).
     * @return List of FlowDependency records representing each dependency edge.
     *
     * @calledBy    DataRefreshHandler.execute(QueueableContext)
     * @testMethods parseFlowDependencies_recordCreate, parseFlowDependencies_subflow,
     *              parseFlowDependencies_apexCall, parseFlowDependencies_triggerObject,
     *              parseFlowDependencies_emptyMetadata
     */
    public List<FlowDependency> parseFlowDependencies(FlowSummary summary, Map<String, Object> flowData) {
        List<FlowDependency> dependencies = new List<FlowDependency>();

        Object rawMetadata = flowData.get('Metadata');
        if (rawMetadata == null) {
            return dependencies;
        }
        Map<String, Object> metadata = (Map<String, Object>) rawMetadata;

        // Trigger object (record-triggered flows)
        extractTriggerObject(dependencies, summary, metadata);

        // Record operations
        extractRecordOperations(dependencies, summary, metadata, 'recordCreates', 'ObjectCreate');
        extractRecordOperations(dependencies, summary, metadata, 'recordUpdates', 'ObjectUpdate');
        extractRecordOperations(dependencies, summary, metadata, 'recordLookups', 'ObjectRead');
        extractRecordOperations(dependencies, summary, metadata, 'recordDeletes', 'ObjectDelete');

        // Subflow references
        extractSubflows(dependencies, summary, metadata);

        // Apex action calls
        extractApexCalls(dependencies, summary, metadata);

        return dependencies;
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────

    /** Sends a GET request to the Tooling API and returns the HttpResponse. */
    private HttpResponse sendToolingRequest(String relativePath) {
        String sessionId = UserInfo.getSessionId();
        String baseUrl   = URL.getOrgDomainUrl().toExternalForm();

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + TOOLING_API_PATH + relativePath);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(HTTP_TIMEOUT_MS);

        Http http = new Http();
        HttpResponse resp = http.send(req);

        if (resp.getStatusCode() != 200) {
            throw new MetadataExtractionServiceException(
                'Tooling API error [' + resp.getStatusCode() + ']: ' + resp.getBody()
            );
        }
        return resp;
    }

    /** Parses the Tooling API query response body into FlowSummary objects. */
    private List<FlowSummary> parseFlowListResponse(String responseBody) {
        List<FlowSummary> results = new List<FlowSummary>();
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> records = (List<Object>) body.get('records');

        if (records == null) {
            return results;
        }
        for (Object rec : records) {
            Map<String, Object> record = (Map<String, Object>) rec;
            FlowSummary s = new FlowSummary();
            s.flowId      = (String) record.get('Id');
            s.apiName     = (String) record.get('ApiName');
            s.label       = (String) record.get('Label');
            s.status      = (String) record.get('Status');
            s.processType = (String) record.get('ProcessType');
            results.add(s);
        }
        return results;
    }

    /**
     * Extracts the record-trigger object from the start element and adds a
     * TriggerObject dependency edge when present.
     */
    private void extractTriggerObject(
        List<FlowDependency> deps,
        FlowSummary summary,
        Map<String, Object> metadata
    ) {
        Object rawStart = metadata.get('start');
        if (rawStart == null) {
            return;
        }
        Map<String, Object> startNode = (Map<String, Object>) rawStart;
        String triggerObj = (String) startNode.get('object');
        if (String.isNotBlank(triggerObj)) {
            FlowDependency dep     = buildBaseDependency(summary);
            dep.targetComponentName = triggerObj;
            dep.targetComponentType = 'Object';
            dep.relationshipType    = 'TriggerObject';
            deps.add(dep);
        }
    }

    /**
     * Parses a list-typed metadata element (e.g. recordCreates) and extracts
     * the object name from each element, creating a dependency edge per element.
     */
    private void extractRecordOperations(
        List<FlowDependency> deps,
        FlowSummary summary,
        Map<String, Object> metadata,
        String metadataKey,
        String relType
    ) {
        Object rawList = metadata.get(metadataKey);
        if (rawList == null) {
            return;
        }

        // Tooling API may return a single object instead of a list for single-element arrays.
        List<Object> elements = normalizeToList(rawList);
        for (Object elem : elements) {
            Map<String, Object> element = (Map<String, Object>) elem;
            String objectName = (String) element.get('object');
            if (String.isNotBlank(objectName)) {
                FlowDependency dep     = buildBaseDependency(summary);
                dep.targetComponentName = objectName;
                dep.targetComponentType = 'Object';
                dep.relationshipType    = relType;
                deps.add(dep);
            }
        }
    }

    /** Parses subflow references and adds a SubflowReference dependency per subflow. */
    private void extractSubflows(
        List<FlowDependency> deps,
        FlowSummary summary,
        Map<String, Object> metadata
    ) {
        Object rawList = metadata.get('subflows');
        if (rawList == null) {
            return;
        }
        List<Object> elements = normalizeToList(rawList);
        for (Object elem : elements) {
            Map<String, Object> element = (Map<String, Object>) elem;
            String subflowName = (String) element.get('flowName');
            if (String.isNotBlank(subflowName)) {
                FlowDependency dep     = buildBaseDependency(summary);
                dep.targetComponentName = subflowName;
                dep.targetComponentType = 'Flow';
                dep.relationshipType    = 'SubflowReference';
                deps.add(dep);
            }
        }
    }

    /**
     * Parses actionCalls and adds an ApexCall dependency for any action whose
     * actionType is 'apex'.
     */
    private void extractApexCalls(
        List<FlowDependency> deps,
        FlowSummary summary,
        Map<String, Object> metadata
    ) {
        Object rawList = metadata.get('actionCalls');
        if (rawList == null) {
            return;
        }
        List<Object> elements = normalizeToList(rawList);
        for (Object elem : elements) {
            Map<String, Object> element    = (Map<String, Object>) elem;
            String actionType = (String) element.get('actionType');
            String actionName = (String) element.get('actionName');
            if ('apex'.equalsIgnoreCase(actionType) && String.isNotBlank(actionName)) {
                FlowDependency dep     = buildBaseDependency(summary);
                dep.targetComponentName = actionName;
                dep.targetComponentType = 'ApexClass';
                dep.relationshipType    = 'ApexCall';
                deps.add(dep);
            }
        }
    }

    /** Constructs a base FlowDependency pre-populated with source flow info. */
    private FlowDependency buildBaseDependency(FlowSummary summary) {
        FlowDependency dep       = new FlowDependency();
        dep.flowApiName          = summary.apiName;
        dep.flowLabel            = summary.label;
        dep.sourceComponentName  = summary.apiName;
        dep.sourceComponentType  = 'Flow';
        dep.sourceComponentId    = summary.flowId;
        return dep;
    }

    /**
     * Normalizes a value that might be a single Map or a List into a List<Object>.
     * The Tooling API sometimes collapses single-element arrays into a plain object.
     */
    private List<Object> normalizeToList(Object raw) {
        if (raw instanceof List<Object>) {
            return (List<Object>) raw;
        }
        return new List<Object>{ raw };
    }
}
