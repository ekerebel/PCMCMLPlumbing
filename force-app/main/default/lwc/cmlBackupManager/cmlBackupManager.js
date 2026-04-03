import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getBackups from '@salesforce/apex/CMLBackupController.getBackups';
import createBackup from '@salesforce/apex/CMLBackupController.createBackup';
import restoreBackup from '@salesforce/apex/CMLBackupController.restoreBackup';
import deleteBackup from '@salesforce/apex/CMLBackupController.deleteBackup';

const COLUMNS = [
    { 
        label: 'Backup Name', 
        fieldName: 'BackupName__c', 
        type: 'text',
        sortable: true
    },
    { 
        label: 'Backup Number', 
        fieldName: 'Name', 
        type: 'text',
        sortable: true
    },
    { 
        label: 'Created Date', 
        fieldName: 'CreatedDate', 
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        },
        sortable: true
    },
    { 
        label: 'Created By', 
        fieldName: 'CreatedByName', 
        type: 'text'
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Restore', name: 'restore' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

export default class CmlBackupManager extends LightningElement {
    columns = COLUMNS;
    backups = [];
    wiredBackupsResult;
    
    showCreateModal = false;
    showRestoreModal = false;
    showDeleteModal = false;
    isCreating = false;
    isRestoring = false;
    isDeleting = false;
    isLoading = true;
    
    backupName = '';
    selectedBackupId = '';
    selectedBackupName = '';

    /**
     * Wire to get all backups
     */
    @wire(getBackups)
    wiredBackups(result) {
        this.wiredBackupsResult = result;
        this.isLoading = true;
        
        if (result.data) {
            // Transform data to include CreatedBy name
            this.backups = result.data.map(backup => ({
                ...backup,
                CreatedByName: backup.CreatedBy ? backup.CreatedBy.Name : ''
            }));
            this.isLoading = false;
        } else if (result.error) {
            console.error('Error loading backups:', result.error);
            this.showToast('Error', 'Failed to load backups', 'error');
            this.backups = [];
            this.isLoading = false;
        }
    }

    /**
     * Check if there are any backups
     */
    get hasBackups() {
        return this.backups && this.backups.length > 0;
    }

    /**
     * Generate default backup name with current date/time
     */
    getDefaultBackupName() {
        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const day = String(now.getDate()).padStart(2, '0');
        const hours = String(now.getHours()).padStart(2, '0');
        const minutes = String(now.getMinutes()).padStart(2, '0');
        
        return `Backup ${year}-${month}-${day} ${hours}:${minutes}`;
    }

    /**
     * Open create backup modal
     */
    handleOpenCreateModal() {
        this.backupName = this.getDefaultBackupName();
        this.showCreateModal = true;
    }

    /**
     * Close create backup modal
     */
    handleCloseCreateModal() {
        this.showCreateModal = false;
        this.backupName = '';
    }

    /**
     * Handle backup name input change
     */
    handleBackupNameChange(event) {
        this.backupName = event.target.value;
    }

    /**
     * Create a new backup
     */
    handleCreateBackup() {
        if (!this.backupName || this.backupName.trim() === '') {
            this.showToast('Error', 'Please enter a backup name', 'error');
            return;
        }

        this.isCreating = true;

        createBackup({ backupName: this.backupName })
            .then(() => {
                this.showToast('Success', 'Backup created successfully', 'success');
                this.handleCloseCreateModal();
                // Refresh the backup list
                return refreshApex(this.wiredBackupsResult);
            })
            .catch(error => {
                const errorMessage = error.body?.message || error.message || 'Unknown error occurred';
                this.showToast('Error', errorMessage, 'error');
                console.error('Create backup error:', error);
            })
            .finally(() => {
                this.isCreating = false;
            });
    }

    /**
     * Handle row action (Restore or Delete button click)
     */
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'restore') {
            this.selectedBackupId = row.Id;
            this.selectedBackupName = row.BackupName__c;
            this.showRestoreModal = true;
        } else if (actionName === 'delete') {
            this.selectedBackupId = row.Id;
            this.selectedBackupName = row.BackupName__c;
            this.showDeleteModal = true;
        }
    }

    /**
     * Close restore confirmation modal
     */
    handleCloseRestoreModal() {
        this.showRestoreModal = false;
        this.selectedBackupId = '';
        this.selectedBackupName = '';
    }

    /**
     * Confirm and execute restore
     */
    handleConfirmRestore() {
        this.isRestoring = true;

        restoreBackup({ backupId: this.selectedBackupId })
            .then(recordCount => {
                this.showToast(
                    'Success', 
                    `Backup restored successfully. ${recordCount} CML Snippet records restored.`, 
                    'success'
                );
                this.handleCloseRestoreModal();
                // Refresh the backup list
                return refreshApex(this.wiredBackupsResult);
            })
            .catch(error => {
                const errorMessage = error.body?.message || error.message || 'Unknown error occurred';
                this.showToast('Error', errorMessage, 'error');
                console.error('Restore backup error:', error);
            })
            .finally(() => {
                this.isRestoring = false;
            });
    }

    /**
     * Close delete confirmation modal
     */
    handleCloseDeleteModal() {
        this.showDeleteModal = false;
        this.selectedBackupId = '';
        this.selectedBackupName = '';
    }

    /**
     * Confirm and execute delete
     */
    handleConfirmDelete() {
        this.isDeleting = true;

        deleteBackup({ backupId: this.selectedBackupId })
            .then(() => {
                this.showToast('Success', 'Backup deleted successfully', 'success');
                this.handleCloseDeleteModal();
                // Refresh the backup list
                return refreshApex(this.wiredBackupsResult);
            })
            .catch(error => {
                const errorMessage = error.body?.message || error.message || 'Unknown error occurred';
                this.showToast('Error', errorMessage, 'error');
                console.error('Delete backup error:', error);
            })
            .finally(() => {
                this.isDeleting = false;
            });
    }

    /**
     * Show toast notification
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        });
        this.dispatchEvent(event);
    }
}
