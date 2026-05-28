/**
 * @file        fieldMappingComponent.js
 * @description Sub-component that renders a grid of editable fields pre-populated
 *              with mapped Lead values. Fires a 'valuechange' custom event with
 *              a { [fieldKey]: newValue } patch object on every field change.
 * @author      ASDA Dev Agent
 * @created     2026-05-28
 */
import { LightningElement, api, track } from 'lwc';

export default class FieldMappingComponent extends LightningElement {
    @api sectionTitle = '';

    /**
     * Array of field definition objects:
     * { key: string, label: string, type: string, required: boolean }
     */
    @api
    get fields() {
        return this._fields;
    }
    set fields(value) {
        this._fields = value;
        this.mergeValues();
    }

    /**
     * Object of current values keyed by field.key.
     * { name: 'Acme', industry: 'Technology', ... }
     */
    @api
    get values() {
        return this._values;
    }
    set values(value) {
        this._values = value || {};
        this.mergeValues();
    }

    @track _fields = [];
    @track _values = {};
    @track _mergedFields = [];

    get fields() {
        return this._mergedFields;
    }

    mergeValues() {
        if (!this._fields) return;
        this._mergedFields = this._fields.map(f => ({
            ...f,
            currentValue: this._values[f.key] !== undefined ? this._values[f.key] : ''
        }));
    }

    handleFieldChange(event) {
        const fieldKey = event.target.dataset.fieldKey;
        const newValue = event.target.type === 'checkbox'
            ? event.target.checked
            : event.target.value;

        // Update internal state
        this._values = Object.assign({}, this._values, { [fieldKey]: newValue });
        this.mergeValues();

        // Notify parent
        this.dispatchEvent(new CustomEvent('valuechange', {
            detail: { [fieldKey]: newValue }
        }));
    }
}