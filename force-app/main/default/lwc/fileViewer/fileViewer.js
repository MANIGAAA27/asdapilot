import { LightningElement, api, track, wire } from 'lwc';
import getRelatedFiles from '@salesforce/apex/FileService.getRelatedFiles';

/** Number of rows shown per page (FR14). */
const PAGE_SIZE = 50;

/**
 * Datatable column definitions.
 *
 * File Name  — url type, opens in new tab (FR9).
 * Related Record — url type, navigates to source record (FR10).
 * Created Date  — date type, rendered in the user's locale format (FR11).
 * File Size     — plain text, pre-formatted KB/MB in Apex (FR12).
 */
const COLUMNS = [
    {
        label: 'File Name',
        fieldName: 'fileUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'title' },
            target: '_blank',
            tooltip: { fieldName: 'title' }
        },
        sortable: true,
        cellAttributes: { alignment: 'left' }
    },
    {
        label: 'File Type',
        fieldName: 'fileType',
        sortable: false
    },
    {
        label: 'File Size',
        fieldName: 'fileSizeFormatted',
        sortable: false,
        cellAttributes: { alignment: 'right' }
    },
    {
        label: 'Related Record',
        fieldName: 'relatedRecordUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'relatedRecordName' },
            target: '_self'
        },
        sortable: false
    },
    {
        label: 'Created By',
        fieldName: 'createdByName',
        sortable: false
    },
    {
        label: 'Created Date',
        fieldName: 'createdDate',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        },
        sortable: true
    }
];

export default class FileViewer extends LightningElement {
    /** Injected automatically from the Lightning Record Page context. */
    @api recordId;

    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';
    @track allFiles = [];
    @track sortedBy = 'createdDate';
    @track sortedDirection = 'desc';
    @track currentPage = 1;

    columns = COLUMNS;

    // -----------------------------------------------------------------------
    // Wire — fetches files whenever recordId changes
    // -----------------------------------------------------------------------

    @wire(getRelatedFiles, { recordId: '$recordId' })
    wiredFiles({ data, error }) {
        this.isLoading = false;
        if (data) {
            // Add the navigable record URL computed from the relatedRecordId
            this.allFiles = data.map(file => ({
                ...file,
                relatedRecordUrl: '/' + file.relatedRecordId
            }));
            // Apply default descending sort
            this._sortData(this.sortedBy, this.sortedDirection);
        } else if (error) {
            this.hasError = true;
            this.errorMessage =
                (error.body && error.body.message)
                    ? error.body.message
                    : 'An error occurred while loading files. Please refresh the page.';
        }
    }

    // -----------------------------------------------------------------------
    // Computed properties
    // -----------------------------------------------------------------------

    get isEmptyState() {
        return !this.isLoading && !this.hasError && (!this.allFiles || this.allFiles.length === 0);
    }

    get totalFilesLabel() {
        const count = this.allFiles ? this.allFiles.length : 0;
        return count + ' file' + (count !== 1 ? 's' : '') + ' found';
    }

    get totalPages() {
        if (!this.allFiles || this.allFiles.length === 0) {
            return 1;
        }
        return Math.ceil(this.allFiles.length / PAGE_SIZE);
    }

    get displayedFiles() {
        if (!this.allFiles || this.allFiles.length === 0) {
            return [];
        }
        const start = (this.currentPage - 1) * PAGE_SIZE;
        return this.allFiles.slice(start, start + PAGE_SIZE);
    }

    get showPagination() {
        return this.allFiles && this.allFiles.length > PAGE_SIZE;
    }

    get isPreviousDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    // -----------------------------------------------------------------------
    // Event handlers
    // -----------------------------------------------------------------------

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this._sortData(fieldName, sortDirection);
        this.currentPage = 1;
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage += 1;
        }
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    _sortData(fieldName, direction) {
        const multiplier = direction === 'asc' ? 1 : -1;
        const sorted = [...this.allFiles].sort((a, b) => {
            const aVal = a[fieldName] !== null && a[fieldName] !== undefined ? a[fieldName] : '';
            const bVal = b[fieldName] !== null && b[fieldName] !== undefined ? b[fieldName] : '';
            if (aVal < bVal) return -1 * multiplier;
            if (aVal > bVal) return 1 * multiplier;
            return 0;
        });
        this.allFiles = sorted;
    }
}