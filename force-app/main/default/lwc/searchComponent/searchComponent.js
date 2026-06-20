/**
 * searchComponent.js
 *
 * Provides a search-first entry point for the Flow Dependency Visualizer.
 * Allows users to locate Flows, Objects, and Apex Classes by name.
 * On selection, fires a 'componentselect' event with the chosen component's
 * name and type so the parent visualizationComponent can render its graph.
 *
 * Imports:
 *   - DependencyCalculationService.searchComponents (cacheable AuraEnabled)
 *   - DependencyCalculationService.getSyncStatus (non-cacheable AuraEnabled)
 *
 * Project: Flow Dependency Visualizer | LLD-FlowDependencyVisualizer | ASDA
 */
// MODIFIED 2026-06-20 — Project: Flow Dependency Visualizer | LLD-FlowDependencyVisualizer | ASDA
import { LightningElement, track } from 'lwc';
import searchComponents from '@salesforce/apex/DependencyCalculationService.searchComponents';
import getSyncStatus    from '@salesforce/apex/DependencyCalculationService.getSyncStatus';

const COMPONENT_TYPE_ICONS = {
    Flow:      { icon: 'utility:flow',        label: 'Flow',       iconClass: 'icon-flow'  },
    ApexClass: { icon: 'utility:apex',        label: 'Apex Class', iconClass: 'icon-apex'  },
    Object:    { icon: 'utility:database',    label: 'Object',     iconClass: 'icon-object'},
    All:       { icon: 'utility:component',   label: 'All',        iconClass: ''           }
};

export default class SearchComponent extends LightningElement {

    @track searchTerm       = '';
    @track activeTypeFilter = 'All';
    @track searchResults    = [];
    @track isLoading        = false;
    @track errorMessage     = '';
    @track hasSearched      = false;
    @track syncStatusLabel  = 'Unknown';

    connectedCallback() {
        this.loadSyncStatus();
    }

    // ─── Computed Getters ─────────────────────────────────────────────────────

    get typeFilters() {
        return ['All', 'Flow', 'ApexClass', 'Object'].map(type => ({
            value:   type,
            label:   type === 'ApexClass' ? 'Apex Class' : type,
            variant: this.activeTypeFilter === type ? 'brand' : 'neutral'
        }));
    }

    get isSearchDisabled() {
        return this.isLoading || this.searchTerm.trim().length < 2;
    }

    get hasResults() {
        return this.hasSearched && this.searchResults.length > 0;
    }

    get showEmptyState() {
        return this.hasSearched && !this.isLoading && this.searchResults.length === 0 && !this.errorMessage;
    }

    get resultCountLabel() {
        const n = this.searchResults.length;
        return n === 1 ? '1 result found' : n + ' results found';
    }

    // ─── Event Handlers ───────────────────────────────────────────────────────

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    handleTypeFilterClick(event) {
        this.activeTypeFilter = event.target.dataset.type;
    }

    handleSearch() {
        if (this.isSearchDisabled) {
            return;
        }
        this.isLoading    = true;
        this.errorMessage = '';
        this.hasSearched  = false;

        const typeParam = this.activeTypeFilter === 'All' ? null : this.activeTypeFilter;

        searchComponents({ searchTerm: this.searchTerm, componentType: typeParam })
            .then(results => {
                this.searchResults = results.map(r => ({
                    key:               r.componentName + '|' + r.componentType,
                    componentName:     r.componentName,
                    componentType:     r.componentType,
                    componentTypeLabel: (COMPONENT_TYPE_ICONS[r.componentType] || COMPONENT_TYPE_ICONS.All).label,
                    iconName:          (COMPONENT_TYPE_ICONS[r.componentType] || COMPONENT_TYPE_ICONS.All).icon,
                    iconClass:         (COMPONENT_TYPE_ICONS[r.componentType] || COMPONENT_TYPE_ICONS.All).iconClass
                }));
                this.hasSearched = true;
            })
            .catch(error => {
                this.errorMessage = 'Search failed: ' + (error.body ? error.body.message : error.message);
                this.searchResults = [];
                this.hasSearched = true;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleResultSelect(event) {
        const componentName = event.currentTarget.dataset.name;
        const componentType = event.currentTarget.dataset.type;

        this.dispatchEvent(new CustomEvent('componentselect', {
            detail: { componentName, componentType },
            bubbles: true,
            composed: true
        }));
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    loadSyncStatus() {
        getSyncStatus()
            .then(status => {
                if (status.syncStatus === 'Never') {
                    this.syncStatusLabel = 'Never synced — click Refresh Data to begin.';
                } else if (status.syncInProgress) {
                    this.syncStatusLabel = 'Sync in progress...';
                } else if (status.lastSyncTime) {
                    const dt = new Date(status.lastSyncTime);
                    this.syncStatusLabel = dt.toLocaleString() + ' (' + status.recordsProcessed + ' edges)';
                } else {
                    this.syncStatusLabel = status.syncStatus;
                }
            })
            .catch(() => {
                this.syncStatusLabel = 'Unable to retrieve sync status';
            });
    }
}