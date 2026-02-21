import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateCML from '@salesforce/apex/CMLGeneratorController.generateCML';
import checkPCMAllExists from '@salesforce/apex/CMLGeneratorController.checkPCMAllExists';
import getSnippetCount from '@salesforce/apex/CMLGeneratorController.getSnippetCount';

export default class CmlGeneratorButton extends LightningElement {
    isGenerating = false;
    pcmAllExists = false;
    snippetCount = 0;

    /**
     * Wire to check if PCM_All exists
     */
    @wire(checkPCMAllExists)
    wiredPCMAllCheck({ error, data }) {
        if (data !== undefined) {
            this.pcmAllExists = data;
        } else if (error) {
            console.error('Error checking PCM_All:', error);
            this.pcmAllExists = false;
        }
    }

    /**
     * Wire to get snippet count
     */
    @wire(getSnippetCount)
    wiredSnippetCount({ error, data }) {
        if (data !== undefined) {
            this.snippetCount = data;
        } else if (error) {
            console.error('Error getting snippet count:', error);
            this.snippetCount = 0;
        }
    }

    /**
     * Handle Generate CML button click
     */
    handleGenerateCML() {
        if (!this.pcmAllExists) {
            this.showToast('Error', 'PCM_All ExpressionSet not found', 'error');
            return;
        }

        this.isGenerating = true;

        generateCML()
            .then(result => {
                this.showToast('Success', result, 'success');
                console.log('CML Generation Result:', result);
            })
            .catch(error => {
                const errorMessage = error.body?.message || error.message || 'Unknown error occurred';
                this.showToast('Error', errorMessage, 'error');
                console.error('CML Generation Error:', error);
            })
            .finally(() => {
                this.isGenerating = false;
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
