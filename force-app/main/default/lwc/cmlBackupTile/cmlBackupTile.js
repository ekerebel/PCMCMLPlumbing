import { LightningElement, wire } from 'lwc';
import getBackupCount from '@salesforce/apex/CMLBackupController.getBackupCount';

export default class CmlBackupTile extends LightningElement {
    backupCount = 0;
    showManager = false;

    /**
     * Wire to get backup count
     */
    @wire(getBackupCount)
    wiredBackupCount({ error, data }) {
        if (data !== undefined) {
            this.backupCount = data;
        } else if (error) {
            console.error('Error getting backup count:', error);
            this.backupCount = 0;
        }
    }

    /**
     * Open the backup manager
     */
    handleOpenManager() {
        this.showManager = true;
    }

    /**
     * Close the backup manager and return to tile view
     */
    handleCloseManager() {
        this.showManager = false;
    }
}
