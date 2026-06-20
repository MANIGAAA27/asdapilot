/**
 * @file              DependencyCalculationService.cls
 * @description       Computes, stores, and retrieves Flow dependency relationships.
 *                    Persists pre-computed edges in Flow_Dependency__c for fast UI queries.
 *                    Provides @AuraEnabled methods consumed by LWC components, as well as
 *                    helper methods used by DataRefreshHandler during sync operations.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-20
 * @lastModified      2026-06-20
 * @group             FlowDependencyVisualizer
 *
 * @dependencies      MetadataExtractionService
 * @calledBy          DataRefreshHandler, searchComponent, visualizationComponent
 * @testClass         DependencyCalculationServiceTest
 *
 * @see               LLD-FlowDependencyVisualizer (Project: Flow Dependency Visualizer)
 */
// MODIFIED 2026-06-20 — Project: Flow Dependency Visualizer | LLD-FlowDependencyVisualizer | ASDA
public with sharing class DependencyCalculationService {

    private static final Integer MAX_SEARCH_RESULTS = 20;
    private static final Integer MAX_DEPENDENCY_DEPTH = 5;
    private static final Integer MAX_QUERY_ROWS = 1000;

    // ─── Inner Types ─────────────────────────────────────────────────────────

    /**
     * Lightweight component descriptor returned by searchComponents().
     */
    public class ComponentResult {
        @AuraEnabled public String componentName;
        @AuraEnabled public String componentType;
        @AuraEnabled public Integer dependencyCount;

        /** Default no-arg constructor required for AuraEnabled serialization. */
        public ComponentResult() {}

        public ComponentResult(String name, String cType, Integer count) {
            this.componentName   = name;
            this.componentType   = cType;
            this.dependencyCount = count;
        }
    }

    /**
     * Represents a single node in the dependency graph, returned by getDependencies().
     */
    public class DependencyNode {
        @AuraEnabled public String sourceComponentName;
        @AuraEnabled public String sourceComponentType;
        @AuraEnabled public String targetComponentName;
        @AuraEnabled public String targetComponentType;
        @AuraEnabled public String relationshipType;
        @AuraEnabled public Boolean isDirect;
        @AuraEnabled public Integer dependencyDepth;
        @AuraEnabled public String flowApiName;
        @AuraEnabled public String recordId;

        public DependencyNode() {}
    }

    /**
     * Sync status descriptor returned by getSyncStatus().
     */
    public class SyncStatusResult {
        @AuraEnabled public String syncStatus;
        @AuraEnabled public DateTime lastSyncTime;
        @AuraEnabled public Integer recordsProcessed;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Boolean syncInProgress;

        public SyncStatusResult() {
            this.syncStatus      = 'Never';
            this.syncInProgress  = false;
            this.recordsProcessed = 0;
        }
    }

    // ─── AuraEnabled Query Methods (LWC-facing) ───────────────────────────────

    /**
     * Searches stored dependency records for components whose name contains
     * the provided search term. Searches both source and target component names.
     * Returns a deduplicated list of up to 20 matching ComponentResult objects.
     *
     * @param  searchTerm      Case-insensitive search string (minimum 2 characters).
     * @param  componentType   Filter by type: 'Flow', 'ApexClass', 'Object', or null/blank for all.
     * @return Deduplicated list of ComponentResult, sorted alphabetically by name.
     *
     * @calledBy    searchComponent.js
     * @testMethods searchComponents_findsFlow, searchComponents_filtersByType,
     *              searchComponents_blankTermReturnsEmpty, searchComponents_deduplicates
     */
    @AuraEnabled(cacheable=true)
    public static List<ComponentResult> searchComponents(String searchTerm, String componentType) {
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return new List<ComponentResult>();
        }

        String searchPattern = '%' + searchTerm.trim() + '%';
        Boolean filterByType = String.isNotBlank(componentType) && componentType != 'All';

        List<Flow_Dependency__c> sourceMatches;
        List<Flow_Dependency__c> targetMatches;

        if (filterByType) {
            sourceMatches = [
                SELECT Source_Component_Name__c, Source_Component_Type__c
                FROM Flow_Dependency__c
                WHERE Source_Component_Name__c LIKE :searchPattern
                AND Source_Component_Type__c = :componentType
                WITH SECURITY_ENFORCED
                LIMIT :MAX_SEARCH_RESULTS
            ];
            targetMatches = [
                SELECT Target_Component_Name__c, Target_Component_Type__c
                FROM Flow_Dependency__c
                WHERE Target_Component_Name__c LIKE :searchPattern
                AND Target_Component_Type__c = :componentType
                WITH SECURITY_ENFORCED
                LIMIT :MAX_SEARCH_RESULTS
            ];
        } else {
            sourceMatches = [
                SELECT Source_Component_Name__c, Source_Component_Type__c
                FROM Flow_Dependency__c
                WHERE Source_Component_Name__c LIKE :searchPattern
                WITH SECURITY_ENFORCED
                LIMIT :MAX_SEARCH_RESULTS
            ];
            targetMatches = [
                SELECT Target_Component_Name__c, Target_Component_Type__c
                FROM Flow_Dependency__c
                WHERE Target_Component_Name__c LIKE :searchPattern
                WITH SECURITY_ENFORCED
                LIMIT :MAX_SEARCH_RESULTS
            ];
        }

        // Deduplicate into a map keyed by "name|type"
        Map<String, ComponentResult> resultMap = new Map<String, ComponentResult>();
        for (Flow_Dependency__c dep : sourceMatches) {
            String key = dep.Source_Component_Name__c + '|' + dep.Source_Component_Type__c;
            if (!resultMap.containsKey(key)) {
                resultMap.put(key, new ComponentResult(dep.Source_Component_Name__c, dep.Source_Component_Type__c, 0));
            }
        }
        for (Flow_Dependency__c dep : targetMatches) {
            String key = dep.Target_Component_Name__c + '|' + dep.Target_Component_Type__c;
            if (!resultMap.containsKey(key)) {
                resultMap.put(key, new ComponentResult(dep.Target_Component_Name__c, dep.Target_Component_Type__c, 0));
            }
        }

        List<ComponentResult> results = resultMap.values();
        if (results.size() > MAX_SEARCH_RESULTS) {
            List<ComponentResult> trimmed = new List<ComponentResult>();
            for (Integer i = 0; i < MAX_SEARCH_RESULTS; i++) {
                trimmed.add(results.get(i));
            }
            results = trimmed;
        }
        return results;
    }

    /**
     * Returns dependency nodes for a given component, filtered by direction and depth.
     * Upstream (direction='upstream'): all components this component depends on.
     * Downstream (direction='downstream'): all components that depend on this component.
     *
     * @param  componentName   API name of the component to center the graph on.
     * @param  componentType   Type: 'Flow', 'ApexClass', or 'Object'.
     * @param  direction       'upstream' or 'downstream'.
     * @param  maxDepth        Maximum depth to retrieve (1–5); defaults to 3 when null.
     * @return List of DependencyNode objects representing each edge in the graph.
     *
     * @calledBy    visualizationComponent.js
     * @testMethods getDependencies_upstream_returnsEdges, getDependencies_downstream_returnsEdges,
     *              getDependencies_invalidDirection_returnsEmpty, getDependencies_depthFiltered
     */
    @AuraEnabled(cacheable=true)
    public static List<DependencyNode> getDependencies(
        String componentName,
        String componentType,
        String direction,
        Integer maxDepth
    ) {
        if (String.isBlank(componentName)) {
            return new List<DependencyNode>();
        }
        if (maxDepth == null || maxDepth < 1) {
            maxDepth = 3;
        }
        if (maxDepth > MAX_DEPENDENCY_DEPTH) {
            maxDepth = MAX_DEPENDENCY_DEPTH;
        }

        List<Flow_Dependency__c> rawDeps;
        if ('downstream'.equalsIgnoreCase(direction)) {
            // Downstream: who depends on this component (this is a target)
            rawDeps = [
                SELECT Id, Source_Component_Name__c, Source_Component_Type__c,
                       Target_Component_Name__c, Target_Component_Type__c,
                       Relationship_Type__c, Is_Direct__c, Dependency_Depth__c, Flow_Api_Name__c
                FROM Flow_Dependency__c
                WHERE Target_Component_Name__c = :componentName
                AND Dependency_Depth__c <= :maxDepth
                WITH SECURITY_ENFORCED
                ORDER BY Dependency_Depth__c ASC, Source_Component_Name__c ASC
                LIMIT :MAX_QUERY_ROWS
            ];
        } else {
            // Upstream (default): what this component depends on (this is a source)
            rawDeps = [
                SELECT Id, Source_Component_Name__c, Source_Component_Type__c,
                       Target_Component_Name__c, Target_Component_Type__c,
                       Relationship_Type__c, Is_Direct__c, Dependency_Depth__c, Flow_Api_Name__c
                FROM Flow_Dependency__c
                WHERE Source_Component_Name__c = :componentName
                AND Dependency_Depth__c <= :maxDepth
                WITH SECURITY_ENFORCED
                ORDER BY Dependency_Depth__c ASC, Target_Component_Name__c ASC
                LIMIT :MAX_QUERY_ROWS
            ];
        }

        return mapToNodes(rawDeps);
    }

    /**
     * Returns the most recent Metadata_Sync_Log__c record to indicate sync health.
     * Returns a default SyncStatusResult with syncStatus='Never' when no records exist.
     *
     * @return SyncStatusResult describing the most recent sync attempt.
     *
     * @calledBy    visualizationComponent.js, searchComponent.js
     * @testMethods getSyncStatus_returnsLatestLog, getSyncStatus_noRecordsReturnsDefault
     */
    @AuraEnabled(cacheable=false)
    public static SyncStatusResult getSyncStatus() {
        List<Metadata_Sync_Log__c> logs = [
            SELECT Id, Sync_Status__c, Last_Sync_Time__c, Records_Processed__c, Error_Message__c
            FROM Metadata_Sync_Log__c
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        SyncStatusResult result = new SyncStatusResult();
        if (!logs.isEmpty()) {
            Metadata_Sync_Log__c log = logs[0];
            result.syncStatus       = log.Sync_Status__c;
            result.lastSyncTime     = log.Last_Sync_Time__c;
            result.recordsProcessed = log.Records_Processed__c != null ? (Integer) log.Records_Processed__c : 0;
            result.errorMessage     = log.Error_Message__c;
            result.syncInProgress   = (log.Sync_Status__c == 'InProgress');
        }
        return result;
    }

    // ─── Non-AuraEnabled Storage/Calculation Methods (called by DataRefreshHandler) ──

    /**
     * Persists a list of FlowDependency records extracted by MetadataExtractionService
     * into Flow_Dependency__c. Uses Database.insert with allOrNone=false so partial
     * failures are logged rather than rolling back the entire sync.
     *
     * @param  deps  List of MetadataExtractionService.FlowDependency objects to persist.
     *
     * @calledBy    DataRefreshHandler.execute(QueueableContext)
     * @testMethods storeDependencies_insertsRecords, storeDependencies_emptyList_noOp
     */
    public static void storeDependencies(List<MetadataExtractionService.FlowDependency> deps) {
        if (deps == null || deps.isEmpty()) {
            return;
        }

        List<Flow_Dependency__c> records = new List<Flow_Dependency__c>();
        for (MetadataExtractionService.FlowDependency dep : deps) {
            Flow_Dependency__c rec = new Flow_Dependency__c(
                Source_Component_Name__c = dep.sourceComponentName,
                Source_Component_Type__c = dep.sourceComponentType,
                Source_Component_Id__c   = dep.sourceComponentId,
                Target_Component_Name__c = dep.targetComponentName,
                Target_Component_Type__c = dep.targetComponentType,
                Relationship_Type__c     = dep.relationshipType,
                Is_Direct__c             = dep.isDirect,
                Dependency_Depth__c      = dep.dependencyDepth,
                Flow_Api_Name__c         = dep.flowApiName
            );
            records.add(rec);
        }

        Database.insert(records, false);
    }

    /**
     * Deletes all existing Flow_Dependency__c records in chunks to stay within
     * DML row limits. Called at the start of each sync to ensure fresh data.
     *
     * @calledBy    DataRefreshHandler.execute(QueueableContext)
     * @testMethods clearExistingDependencies_deletesAllRecords
     */
    public static void clearExistingDependencies() {
        List<Flow_Dependency__c> existing = [
            SELECT Id
            FROM Flow_Dependency__c
            WITH SECURITY_ENFORCED
            LIMIT 10000
        ];
        if (!existing.isEmpty()) {
            Database.delete(existing, false);
        }
    }

    /**
     * Computes transitive dependency depth by expanding direct edges already stored.
     * For each direct edge (depth=1), searches the store for additional hops from
     * the target component and creates transitive edges up to maxDepth.
     * Called after initial direct dependencies are stored.
     *
     * @param  maxDepth  Maximum transitive depth to compute (2–5).
     *
     * @calledBy    DataRefreshHandler.execute(QueueableContext)
     * @testMethods computeTransitiveDeps_createsDepthTwoEdges
     */
    public static void computeTransitiveDependencies(Integer maxDepth) {
        if (maxDepth == null || maxDepth < 2) {
            return;
        }
        if (maxDepth > MAX_DEPENDENCY_DEPTH) {
            maxDepth = MAX_DEPENDENCY_DEPTH;
        }

        // Iterate depth levels, expanding one hop at a time
        for (Integer currentDepth = 1; currentDepth < maxDepth; currentDepth++) {
            List<Flow_Dependency__c> currentLevel = [
                SELECT Id, Source_Component_Name__c, Source_Component_Type__c,
                       Target_Component_Name__c, Target_Component_Type__c, Flow_Api_Name__c
                FROM Flow_Dependency__c
                WHERE Dependency_Depth__c = :currentDepth
                WITH SECURITY_ENFORCED
                LIMIT 5000
            ];

            if (currentLevel.isEmpty()) {
                break;
            }

            // Collect unique target names to find their downstream edges
            Set<String> targetNames = new Set<String>();
            for (Flow_Dependency__c edge : currentLevel) {
                targetNames.add(edge.Target_Component_Name__c);
            }

            // Find edges where the source is one of those targets (one more hop)
            List<Flow_Dependency__c> nextHops = [
                SELECT Source_Component_Name__c, Source_Component_Type__c,
                       Target_Component_Name__c, Target_Component_Type__c,
                       Relationship_Type__c, Flow_Api_Name__c
                FROM Flow_Dependency__c
                WHERE Source_Component_Name__c IN :targetNames
                AND Dependency_Depth__c = 1
                WITH SECURITY_ENFORCED
                LIMIT 5000
            ];

            if (nextHops.isEmpty()) {
                break;
            }

            // Build a map from target-of-current to source-of-current for edge expansion
            Map<String, Flow_Dependency__c> parentByTarget = new Map<String, Flow_Dependency__c>();
            for (Flow_Dependency__c edge : currentLevel) {
                parentByTarget.put(edge.Target_Component_Name__c, edge);
            }

            List<Flow_Dependency__c> transitive = new List<Flow_Dependency__c>();
            Integer nextDepth = currentDepth + 1;
            for (Flow_Dependency__c hop : nextHops) {
                Flow_Dependency__c parent = parentByTarget.get(hop.Source_Component_Name__c);
                if (parent == null) {
                    continue;
                }
                transitive.add(new Flow_Dependency__c(
                    Source_Component_Name__c = parent.Source_Component_Name__c,
                    Source_Component_Type__c = parent.Source_Component_Type__c,
                    Target_Component_Name__c = hop.Target_Component_Name__c,
                    Target_Component_Type__c = hop.Target_Component_Type__c,
                    Relationship_Type__c     = hop.Relationship_Type__c,
                    Is_Direct__c             = false,
                    Dependency_Depth__c      = nextDepth,
                    Flow_Api_Name__c         = parent.Flow_Api_Name__c
                ));
            }

            if (!transitive.isEmpty()) {
                Database.insert(transitive, false);
            }
        }
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────

    /** Maps a list of Flow_Dependency__c SObjects to DependencyNode wrappers. */
    private static List<DependencyNode> mapToNodes(List<Flow_Dependency__c> rawDeps) {
        List<DependencyNode> nodes = new List<DependencyNode>();
        for (Flow_Dependency__c dep : rawDeps) {
            DependencyNode node        = new DependencyNode();
            node.sourceComponentName   = dep.Source_Component_Name__c;
            node.sourceComponentType   = dep.Source_Component_Type__c;
            node.targetComponentName   = dep.Target_Component_Name__c;
            node.targetComponentType   = dep.Target_Component_Type__c;
            node.relationshipType      = dep.Relationship_Type__c;
            node.isDirect              = dep.Is_Direct__c;
            node.dependencyDepth       = dep.Dependency_Depth__c != null ? (Integer) dep.Dependency_Depth__c : 1;
            node.flowApiName           = dep.Flow_Api_Name__c;
            node.recordId              = dep.Id;
            nodes.add(node);
        }
        return nodes;
    }
}
