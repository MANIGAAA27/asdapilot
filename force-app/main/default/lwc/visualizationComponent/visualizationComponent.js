/**
 * visualizationComponent.js
 *
 * Renders an interactive SVG dependency graph for the Flow Dependency Visualizer.
 * Displays nodes (Flows, Objects, Apex Classes) and directed edges (dependency relationships)
 * using a radial layout centered on the selected component.
 *
 * Features:
 *   - Graph view: radial SVG layout with drag/pan and scroll-to-zoom
 *   - List view: grouped table organized by component type
 *   - Side panel: detailed metadata on node click
 *   - Drill-down: clicking "View Dependencies" on a node re-centers the graph
 *   - Filter integration: listens for 'filterchange' events from filterComponent
 *   - Search integration: @api properties set by parent on 'componentselect' event
 *   - Manual refresh: calls DataRefreshHandler.triggerManualRefresh via imperative Apex
 *
 * Imports:
 *   - DependencyCalculationService.getDependencies (cacheable AuraEnabled)
 *   - DependencyCalculationService.getSyncStatus   (non-cacheable AuraEnabled)
 *   - DataRefreshHandler.triggerManualRefresh       (non-cacheable AuraEnabled)
 *
 * Project: Flow Dependency Visualizer | LLD-FlowDependencyVisualizer | ASDA
 */
// MODIFIED 2026-06-20 — Project: Flow Dependency Visualizer | LLD-FlowDependencyVisualizer | ASDA
import { LightningElement, api, track } from 'lwc';
import getDependencies    from '@salesforce/apex/DependencyCalculationService.getDependencies';
import getSyncStatus      from '@salesforce/apex/DependencyCalculationService.getSyncStatus';
import triggerManualRefresh from '@salesforce/apex/DataRefreshHandler.triggerManualRefresh';

// Layout constants
const CENTER_X           = 400;
const CENTER_Y           = 300;
const RING_RADII         = [0, 140, 260, 360, 440];
const ROOT_RADIUS        = 30;
const NODE_RADIUS        = 22;
const SVG_WIDTH          = 800;
const SVG_HEIGHT         = 600;
const MAX_LABEL_LENGTH   = 18;

const TYPE_ICON_MAP = {
    Flow:      { icon: 'utility:flow',     circleClass: 'node-circle node-flow'   },
    ApexClass: { icon: 'utility:apex',     circleClass: 'node-circle node-apex'   },
    Object:    { icon: 'utility:database', circleClass: 'node-circle node-object' }
};

const REL_TYPE_DASH = {
    SubflowReference: '8,4',
    ApexCall:         '8,4',
    ObjectRead:       '4,2',
    ObjectDelete:     '4,2'
};

const GROUP_ICONS = {
    Flow:      'utility:flow',
    ApexClass: 'utility:apex',
    Object:    'utility:database'
};

export default class VisualizationComponent extends LightningElement {

    // ─── Public API ───────────────────────────────────────────────────────────

    @api
    get selectedComponentName() { return this._selectedComponentName; }
    set selectedComponentName(value) {
        this._selectedComponentName = value;
        if (value) { this.loadDependencies(); }
    }

    @api
    get selectedComponentType() { return this._selectedComponentType; }
    set selectedComponentType(value) { this._selectedComponentType = value; }

    // ─── Tracked State ────────────────────────────────────────────────────────

    @track _selectedComponentName  = null;
    @track _selectedComponentType  = 'Flow';
    @track isLoading               = false;
    @track isRefreshing            = false;
    @track errorMessage            = '';
    @track viewMode                = 'graph';   // 'graph' | 'list'
    @track syncStatusLabel         = 'Unknown';
    @track selectedNode            = null;

    // Graph state
    @track svgNodes                = [];
    @track svgEdges                = [];
    @track rawDependencies         = [];

    // Zoom / pan state (not tracked — mutated directly on SVG viewport element)
    _scale    = 1;
    _offsetX  = 0;
    _offsetY  = 0;
    _dragging = false;
    _dragStartX = 0;
    _dragStartY = 0;

    // Active filter state (updated via filterchange events)
    _activeFilters = {
        direction:         'upstream',
        componentType:     'All',
        maxDepth:          3,
        showIndirect:      true,
        relationshipTypes: ['TriggerObject','ObjectCreate','ObjectUpdate','ObjectRead','ObjectDelete','SubflowReference','ApexCall']
    };

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this.loadSyncStatus();
        this.template.addEventListener('filterchange', this.handleFilterChange.bind(this));
    }

    // ─── Computed Getters ─────────────────────────────────────────────────────

    get isGraphView()  { return this.viewMode === 'graph'; }
    get isListView()   { return this.viewMode === 'list';  }
    get graphViewVariant() { return this.isGraphView ? 'brand' : 'neutral'; }
    get listViewVariant()  { return this.isListView  ? 'brand' : 'neutral'; }
    get showPromptState()  { return !this._selectedComponentName && !this.isLoading; }
    get selectedComponentTypeLower() { return (this._selectedComponentType || '').toLowerCase(); }

    get totalNodes() {
        const names = new Set(this.rawDependencies.map(d => d.targetComponentName));
        return names.size + (this._selectedComponentName ? 1 : 0);
    }
    get totalEdges()     { return this.rawDependencies.length; }
    get maxDepthReached() {
        return this.rawDependencies.reduce((max, d) => Math.max(max, d.dependencyDepth || 1), 0);
    }

    get groupedNodes() {
        const filtered = this.getFilteredDependencies();
        const groups = {};
        for (const dep of filtered) {
            const type = dep.targetComponentType || 'Unknown';
            if (!groups[type]) {
                groups[type] = { type, iconName: GROUP_ICONS[type] || 'utility:component', items: [], count: 0 };
            }
            groups[type].items.push(this.depToListItem(dep));
            groups[type].count++;
        }
        return Object.values(groups).sort((a, b) => a.type.localeCompare(b.type));
    }

    get hasGroupedNodes() { return this.groupedNodes.length > 0; }

    // ─── Event Handlers ───────────────────────────────────────────────────────

    handleGraphViewToggle() { this.viewMode = 'graph'; }
    handleListViewToggle()  { this.viewMode = 'list';  }

    handleFilterChange(event) {
        this._activeFilters = Object.assign({}, event.detail);
        if (this._selectedComponentName) {
            this.loadDependencies();
        }
    }

    handleNodeClick(event) {
        const name = event.currentTarget.dataset.name;
        const type = event.currentTarget.dataset.type;
        const dep  = this.rawDependencies.find(
            d => d.targetComponentName === name && d.targetComponentType === type
        );
        if (dep) {
            this.selectedNode = this.depToListItem(dep);
        } else if (name === this._selectedComponentName) {
            this.selectedNode = {
                componentName:   this._selectedComponentName,
                componentType:   this._selectedComponentType,
                relationshipType: 'Root',
                dependencyDepth: 0,
                kindLabel:       'Direct',
                flowApiName:     this._selectedComponentName
            };
        }
    }

    handleCloseSidePanel() { this.selectedNode = null; }

    handleDrillDown() {
        if (!this.selectedNode) { return; }
        const name = this.selectedNode.componentName;
        const type = this.selectedNode.componentType;
        this.selectedNode = null;
        this._selectedComponentName = name;
        this._selectedComponentType = type;
        this.loadDependencies();
    }

    // ─── Zoom / Pan ───────────────────────────────────────────────────────────

    handleZoomIn()    { this._scale = Math.min(3, this._scale + 0.2); this.applyTransform(); }
    handleZoomOut()   { this._scale = Math.max(0.3, this._scale - 0.2); this.applyTransform(); }
    handleZoomReset() { this._scale = 1; this._offsetX = 0; this._offsetY = 0; this.applyTransform(); }

    handleCanvasWheel(event) {
        event.preventDefault();
        const delta = event.deltaY > 0 ? -0.1 : 0.1;
        this._scale = Math.min(3, Math.max(0.3, this._scale + delta));
        this.applyTransform();
    }

    handleCanvasDragStart(event) {
        this._dragging  = true;
        this._dragStartX = event.clientX - this._offsetX;
        this._dragStartY = event.clientY - this._offsetY;
    }

    handleCanvasDragMove(event) {
        if (!this._dragging) { return; }
        this._offsetX = event.clientX - this._dragStartX;
        this._offsetY = event.clientY - this._dragStartY;
        this.applyTransform();
    }

    handleCanvasDragEnd() { this._dragging = false; }

    applyTransform() {
        const viewport = this.template.querySelector('.graph-viewport');
        if (viewport) {
            viewport.setAttribute('transform',
                `translate(${this._offsetX},${this._offsetY}) scale(${this._scale})`
            );
        }
    }

    // ─── Manual Refresh ───────────────────────────────────────────────────────

    handleRefreshData() {
        this.isRefreshing = true;
        this.errorMessage = '';
        triggerManualRefresh()
            .then(result => {
                if (result === 'in_progress') {
                    this.errorMessage = 'A sync is already in progress. Please wait and refresh again in a moment.';
                } else {
                    this.syncStatusLabel = 'Sync queued — data will update shortly.';
                    if (this._selectedComponentName) {
                        // Reload after a short delay to pick up fresh data
                        // eslint-disable-next-line @lwc/lwc/no-async-operation
                        setTimeout(() => this.loadDependencies(), 5000);
                    }
                }
            })
            .catch(error => {
                this.errorMessage = 'Refresh failed: ' + (error.body ? error.body.message : error.message);
            })
            .finally(() => { this.isRefreshing = false; });
    }

    // ─── Data Loading ─────────────────────────────────────────────────────────

    loadDependencies() {
        if (!this._selectedComponentName) { return; }
        this.isLoading    = true;
        this.errorMessage = '';
        this.selectedNode = null;

        getDependencies({
            componentName:  this._selectedComponentName,
            componentType:  this._selectedComponentType,
            direction:      this._activeFilters.direction,
            maxDepth:       this._activeFilters.maxDepth
        })
            .then(deps => {
                this.rawDependencies = deps || [];
                this.buildGraph();
            })
            .catch(error => {
                this.errorMessage = 'Failed to load dependencies: ' + (error.body ? error.body.message : error.message);
                this.rawDependencies = [];
                this.svgNodes = [];
                this.svgEdges = [];
            })
            .finally(() => { this.isLoading = false; });
    }

    loadSyncStatus() {
        getSyncStatus()
            .then(status => {
                if (status.syncStatus === 'Never') {
                    this.syncStatusLabel = 'Never synced';
                } else if (status.syncInProgress) {
                    this.syncStatusLabel = 'Sync in progress...';
                } else if (status.lastSyncTime) {
                    this.syncStatusLabel = new Date(status.lastSyncTime).toLocaleString();
                } else {
                    this.syncStatusLabel = status.syncStatus;
                }
            })
            .catch(() => { this.syncStatusLabel = 'Unknown'; });
    }

    // ─── Graph Building ───────────────────────────────────────────────────────

    buildGraph() {
        const filtered = this.getFilteredDependencies();

        // Build unique node map: key → { name, type, depth }
        const nodeMap = new Map();
        const rootKey = this._selectedComponentName + '|' + this._selectedComponentType;
        nodeMap.set(rootKey, {
            componentName: this._selectedComponentName,
            componentType: this._selectedComponentType,
            depth: 0,
            isRoot: true
        });

        for (const dep of filtered) {
            const key = dep.targetComponentName + '|' + dep.targetComponentType;
            if (!nodeMap.has(key)) {
                nodeMap.set(key, {
                    componentName: dep.targetComponentName,
                    componentType: dep.targetComponentType,
                    depth: dep.dependencyDepth || 1,
                    isRoot: false
                });
            }
        }

        // Assign positions using radial layout
        const nodesByDepth = new Map();
        for (const [, node] of nodeMap) {
            const d = node.depth;
            if (!nodesByDepth.has(d)) { nodesByDepth.set(d, []); }
            nodesByDepth.get(d).push(node);
        }

        const positionedNodes = new Map();
        for (const [depth, nodes] of nodesByDepth) {
            const radius = RING_RADII[Math.min(depth, RING_RADII.length - 1)];
            nodes.forEach((node, i) => {
                const angle = nodes.length === 1
                    ? -Math.PI / 2
                    : (-Math.PI / 2) + (2 * Math.PI * i) / nodes.length;
                const cx = CENTER_X + radius * Math.cos(angle);
                const cy = CENTER_Y + radius * Math.sin(angle);
                const key = node.componentName + '|' + node.componentType;
                positionedNodes.set(key, { ...node, cx, cy });
            });
        }

        // Build SVG node descriptors
        const svgNodes = [];
        for (const [key, node] of positionedNodes) {
            const r = node.isRoot ? ROOT_RADIUS : NODE_RADIUS;
            const typeInfo = TYPE_ICON_MAP[node.componentType] || { circleClass: 'node-circle node-unknown' };
            svgNodes.push({
                key,
                componentName:  node.componentName,
                componentType:  node.componentType,
                cx:             Math.round(node.cx),
                cy:             Math.round(node.cy),
                radius:         r,
                labelY:         Math.round(node.cy + r + 14),
                typeY:          Math.round(node.cy + r + 26),
                circleClass:    node.isRoot ? typeInfo.circleClass + ' node-root' : typeInfo.circleClass,
                groupClass:     'node-group',
                shortLabel:     this.truncateLabel(node.componentName)
            });
        }

        // Build SVG edge descriptors
        const svgEdges = [];
        for (const dep of filtered) {
            const srcKey = dep.sourceComponentName + '|' + dep.sourceComponentType;
            const tgtKey = dep.targetComponentName + '|' + dep.targetComponentType;
            const src = positionedNodes.get(srcKey);
            const tgt = positionedNodes.get(tgtKey);
            if (!src || !tgt) { continue; }

            const dashArr = REL_TYPE_DASH[dep.relationshipType] || (dep.isDirect ? '' : '5,3');
            svgEdges.push({
                key:       srcKey + '->' + tgtKey,
                x1:        Math.round(src.cx),
                y1:        Math.round(src.cy),
                x2:        Math.round(tgt.cx),
                y2:        Math.round(tgt.cy),
                lineClass: 'graph-edge edge-' + (dep.isDirect ? 'direct' : 'indirect'),
                dashArray: dashArr
            });
        }

        this.svgNodes = svgNodes;
        this.svgEdges = svgEdges;
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    getFilteredDependencies() {
        return this.rawDependencies.filter(dep => {
            if (!this._activeFilters.showIndirect && !dep.isDirect) { return false; }
            if (this._activeFilters.relationshipTypes &&
                !this._activeFilters.relationshipTypes.includes(dep.relationshipType)) {
                return false;
            }
            return true;
        });
    }

    depToListItem(dep) {
        const isDirect = dep.isDirect !== false;
        return {
            key:             dep.recordId || (dep.targetComponentName + '|' + dep.targetComponentType),
            componentName:   dep.targetComponentName,
            componentType:   dep.targetComponentType,
            relationshipType: dep.relationshipType,
            dependencyDepth: dep.dependencyDepth || 1,
            kindLabel:       isDirect ? 'Direct' : 'Transitive',
            kindClass:       isDirect ? 'slds-badge slds-badge_success' : 'slds-badge',
            relTypeClass:    (dep.relationshipType || '').toLowerCase().replace(/[^a-z]/g, ''),
            flowApiName:     dep.flowApiName || dep.sourceComponentName
        };
    }

    truncateLabel(name) {
        if (!name) { return ''; }
        return name.length > MAX_LABEL_LENGTH ? name.substring(0, MAX_LABEL_LENGTH - 1) + '…' : name;
    }
}