/**
 * filterComponent.js
 *
 * Provides filter controls for the Flow Dependency Visualizer:
 *   - Analysis direction (upstream / downstream)
 *   - Component type (Flow, ApexClass, Object, All)
 *   - Relationship type checkboxes
 *   - Maximum dependency depth slider (1-5)
 *   - Show/hide indirect (transitive) dependencies toggle
 *
 * Fires a 'filterchange' custom event with the current filter state whenever
 * the user clicks "Apply Filters". Parent components (visualizationComponent)
 * listen for this event to re-query and re-render the dependency graph.
 *
 * Project: Flow Dependency Visualizer | LLD-FlowDependencyVisualizer | ASDA
 */
// MODIFIED 2026-06-20 — Project: Flow Dependency Visualizer | LLD-FlowDependencyVisualizer | ASDA
import { LightningElement, track } from 'lwc';

const DEFAULT_DEPTH         = 3;
const DEFAULT_DIRECTION     = 'upstream';
const DEFAULT_COMPONENT_TYPE = 'All';
const ALL_RELATIONSHIP_TYPES = [
    { value: 'TriggerObject',    label: 'Trigger Object',    checked: true },
    { value: 'ObjectCreate',     label: 'Object Create',     checked: true },
    { value: 'ObjectUpdate',     label: 'Object Update',     checked: true },
    { value: 'ObjectRead',       label: 'Object Read',       checked: true },
    { value: 'ObjectDelete',     label: 'Object Delete',     checked: true },
    { value: 'SubflowReference', label: 'Subflow Reference', checked: true },
    { value: 'ApexCall',         label: 'Apex Call',         checked: true }
];

export default class FilterComponent extends LightningElement {

    @track selectedDirection    = DEFAULT_DIRECTION;
    @track selectedComponentType = DEFAULT_COMPONENT_TYPE;
    @track selectedDepth        = DEFAULT_DEPTH;
    @track showIndirect         = true;
    @track relationshipTypeOptions = JSON.parse(JSON.stringify(ALL_RELATIONSHIP_TYPES));

    // ─── Computed Getters ─────────────────────────────────────────────────────

    get componentTypeOptions() {
        return [
            { label: 'All Types',  value: 'All'       },
            { label: 'Flow',       value: 'Flow'       },
            { label: 'Apex Class', value: 'ApexClass'  },
            { label: 'Object',     value: 'Object'     }
        ];
    }

    get upstreamVariant() {
        return this.selectedDirection === 'upstream' ? 'brand' : 'neutral';
    }

    get downstreamVariant() {
        return this.selectedDirection === 'downstream' ? 'brand' : 'neutral';
    }

    // ─── Event Handlers ───────────────────────────────────────────────────────

    handleDirectionUpstream() {
        this.selectedDirection = 'upstream';
    }

    handleDirectionDownstream() {
        this.selectedDirection = 'downstream';
    }

    handleComponentTypeChange(event) {
        this.selectedComponentType = event.detail.value;
    }

    handleDepthChange(event) {
        this.selectedDepth = parseInt(event.detail.value, 10);
    }

    handleShowIndirectChange(event) {
        this.showIndirect = event.target.checked;
    }

    handleRelationshipTypeChange(event) {
        const changedValue = event.target.dataset.value;
        const checked      = event.target.checked;
        this.relationshipTypeOptions = this.relationshipTypeOptions.map(opt =>
            opt.value === changedValue ? { ...opt, checked } : opt
        );
    }

    handleApplyFilters() {
        const selectedRelationshipTypes = this.relationshipTypeOptions
            .filter(opt => opt.checked)
            .map(opt => opt.value);

        this.dispatchEvent(new CustomEvent('filterchange', {
            detail: {
                direction:         this.selectedDirection,
                componentType:     this.selectedComponentType,
                maxDepth:          this.selectedDepth,
                showIndirect:      this.showIndirect,
                relationshipTypes: selectedRelationshipTypes
            },
            bubbles: true,
            composed: true
        }));
    }

    handleResetFilters() {
        this.selectedDirection     = DEFAULT_DIRECTION;
        this.selectedComponentType = DEFAULT_COMPONENT_TYPE;
        this.selectedDepth         = DEFAULT_DEPTH;
        this.showIndirect          = true;
        this.relationshipTypeOptions = JSON.parse(JSON.stringify(ALL_RELATIONSHIP_TYPES));
        this.handleApplyFilters();
    }
}