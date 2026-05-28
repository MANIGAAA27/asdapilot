/**
 * @file        recordSearchComponent.js
 * @description Sub-component for searching and selecting existing Account, Contact,
 *              or Opportunity records. Fires a 'recordselected' custom event with
 *              { recordId, recordName } when the user picks a result.
 * @author      ASDA Dev Agent
 * @created     2026-05-28
 */
import { LightningElement, api, track } from 'lwc';
import searchAccounts from '@salesforce/apex/LeadConversionController.searchAccounts';
import searchContacts from '@salesforce/apex/LeadConversionController.searchContacts';

const SEARCH_DELAY_MS = 300;
const MIN_SEARCH_LENGTH = 2;

export default class RecordSearchComponent extends LightningElement {
    @api objectType = 'Account'; // 'Account' | 'Contact' | 'Opportunity'
    @api searchLabel = 'Search Records';

    @track searchTerm = '';
    @track searchResults = [];
    @track isSearching = false;
    @track searchError = '';
    @track noResultsFound = false;

    _searchTimer = null;

    // ─────────────────────────────────────────────────────────────────────────
    // Getters
    // ─────────────────────────────────────────────────────────────────────────

    get hasResults() {
        return this.searchResults.length > 0;
    }

    get showNoResults() {
        return this.noResultsFound && !this.isSearching && this.searchResults.length === 0;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Event handlers
    // ─────────────────────────────────────────────────────────────────────────

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        this.searchError = '';
        this.noResultsFound = false;

        if (this._searchTimer) {
            clearTimeout(this._searchTimer);
        }

        if (this.searchTerm.length < MIN_SEARCH_LENGTH) {
            this.searchResults = [];
            return;
        }

        // Debounce
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimer = setTimeout(() => {
            this.performSearch();
        }, SEARCH_DELAY_MS);
    }

    handleKeyDown(event) {
        if (event.key === 'Escape') {
            this.searchResults = [];
            this.searchTerm = '';
        }
    }

    handleResultClick(event) {
        const recordId = event.currentTarget.dataset.recordId;
        const recordName = event.currentTarget.dataset.recordName;
        this.selectRecord(recordId, recordName);
    }

    handleResultKeyPress(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            const recordId = event.currentTarget.dataset.recordId;
            const recordName = event.currentTarget.dataset.recordName;
            this.selectRecord(recordId, recordName);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Search logic
    // ─────────────────────────────────────────────────────────────────────────

    async performSearch() {
        this.isSearching = true;
        this.searchError = '';
        this.searchResults = [];

        try {
            let results = [];

            if (this.objectType === 'Account') {
                const req = { companyName: this.searchTerm };
                results = await searchAccounts({ searchRequest: JSON.stringify(req) });
            } else if (this.objectType === 'Contact') {
                const req = { lastName: this.searchTerm };
                results = await searchContacts({ searchRequest: JSON.stringify(req) });
            }

            // Enrich results with icon names
            this.searchResults = (results || []).map(r => ({
                ...r,
                iconName: this.getIconName(r.objectType)
            }));

            this.noResultsFound = this.searchResults.length === 0;

        } catch (err) {
            this.searchError = this.extractErrorMessage(err);
        } finally {
            this.isSearching = false;
        }
    }

    selectRecord(recordId, recordName) {
        this.searchResults = [];
        this.searchTerm = recordName;
        this.noResultsFound = false;

        this.dispatchEvent(new CustomEvent('recordselected', {
            detail: { recordId, recordName }
        }));
    }

    getIconName(objectType) {
        const iconMap = {
            Account: 'standard:account',
            Contact: 'standard:contact',
            Opportunity: 'standard:opportunity'
        };
        return iconMap[objectType] || 'standard:record';
    }

    extractErrorMessage(err) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        if (err && err.message) {
            return err.message;
        }
        return 'Search failed. Please try again.';
    }
}