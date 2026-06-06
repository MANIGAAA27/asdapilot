/**
 * @file        armtMappingUI.js
 * @description Lightning Web Component providing the user interface for mapping
 *              source CPQ fields to ARM target fields. Supports inline editing,
 *              confidence-based filtering, search, and save operations.
 * @author      ASDA Dev Agent
 * @created     2026-06-06
 */
import { LightningElement, api, track } from 'lwc';

/** Confidence filter options for the combobox. */
const CONFIDENCE_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'High (≥ 0.8)', value: 'high' },
    { label: 'Medium (0.5–0.79)', value: 'medium' },
    { label: 'Low (< 0.5)', value: 'low' }
];

export default class ArmtMappingUI extends LightningElement {

    /** Public property: array of mapping objects to display. */
    @api
    get mappings() {
        return this._mappings;
    }
    set mappings(value) {
        this._mappings = value ? value.map(m => this._enrichMapping(m)) : [];
        this._applyFilters();
    }

    /** Public property: controls loading spinner visibility. */
    @api isLoading = false;

    /** Internal mapping store. */
    _mappings = [];

    /** Current search term for field name filtering. */
    @track searchTerm = '';

    /** Currently selected confidence filter. */
    @track selectedConfidence = '';

    /** Filtered subset of mappings based on active filters. */
    @track filteredMappings = [];

    /** Tracks whether a save operation is in progress. */
    @track isSaving = false;

    /** Tracks whether the last save was successful. */
    @track hasSaveSuccess = false;

    /** Error message to display in the error banner. */
    @track errorMessage = '';

    // ─────────────────────────────────────────────────────────────────────────
    // Getters
    // ─────────────────────────────────────────────────────────────────────────

    /** Returns confidence filter options for the combobox. */
    get confidenceOptions() {
        return CONFIDENCE_OPTIONS;
    }

    /** Returns true when there are filtered mappings to display. */
    get hasMappings() {
        return this.filteredMappings && this.filteredMappings.length > 0;
    }

    /** Returns true when an error message is present. */
    get hasError() {
        return this.errorMessage && this.errorMessage.length > 0;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Event handlers
    // ─────────────────────────────────────────────────────────────────────────

    /** Handles search input changes. */
    handleSearchChange(event) {
        this.searchTerm = event.detail.value;
        this._applyFilters();
    }

    /** Handles confidence filter combobox changes. */
    handleConfidenceFilterChange(event) {
        this.selectedConfidence = event.detail.value;
        this._applyFilters();
    }

    /** Handles inline target field edits in the mapping table. */
    handleTargetFieldChange(event) {
        const mappingId = event.target.dataset.id;
        const newValue = event.detail.value;

        this._mappings = this._mappings.map(m => {
            if (m.id === mappingId) {
                return Object.assign({}, m, { targetFieldApi: newValue });
            }
            return m;
        });
        this._applyFilters();
        this.hasSaveSuccess = false;
    }

    /** Handles remove mapping button clicks. */
    handleRemoveMapping(event) {
        const mappingId = event.currentTarget.dataset.id;
        this._mappings = this._mappings.filter(m => m.id !== mappingId);
        this._applyFilters();
        this.hasSaveSuccess = false;
    }

    /** Handles the save mappings button click. Fires a custom event with updated mappings. */
    handleSaveMappings() {
        this.isSaving = true;
        this.hasSaveSuccess = false;
        this.errorMessage = '';

        try {
            const saveEvent = new CustomEvent('savemappings', {
                detail: { mappings: [...this._mappings] },
                bubbles: true,
                composed: true
            });
            this.dispatchEvent(saveEvent);
            this.hasSaveSuccess = true;
        } catch (err) {
            this.errorMessage = err && err.message
                ? err.message
                : 'An error occurred while saving mappings.';
        } finally {
            this.isSaving = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Applies active search and confidence filters to the internal mapping list. */
    _applyFilters() {
        let result = [...this._mappings];

        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            result = result.filter(m =>
                (m.sourceFieldApi && m.sourceFieldApi.toLowerCase().includes(term)) ||
                (m.targetFieldApi && m.targetFieldApi.toLowerCase().includes(term))
            );
        }

        if (this.selectedConfidence) {
            result = result.filter(m => {
                const score = m.confidenceScore || 0;
                if (this.selectedConfidence === 'high') return score >= 0.8;
                if (this.selectedConfidence === 'medium') return score >= 0.5 && score < 0.8;
                if (this.selectedConfidence === 'low') return score < 0.5;
                return true;
            });
        }

        this.filteredMappings = result;
    }

    /** Enriches a raw mapping object with computed display properties. */
    _enrichMapping(mapping) {
        const score = mapping.confidenceScore || 0;
        let confidenceLabel;
        let confidenceClass;

        if (score >= 0.8) {
            confidenceLabel = 'High';
            confidenceClass = 'slds-theme_success';
        } else if (score >= 0.5) {
            confidenceLabel = 'Medium';
            confidenceClass = 'slds-theme_warning';
        } else {
            confidenceLabel = 'Low';
            confidenceClass = 'slds-theme_error';
        }

        return Object.assign({}, mapping, {
            id: mapping.id || mapping.sourceFieldApi || String(Math.random()),
            confidenceLabel,
            confidenceClass
        });
    }
}
