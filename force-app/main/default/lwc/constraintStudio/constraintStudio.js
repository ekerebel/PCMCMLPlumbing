import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCMLSnippets from '@salesforce/apex/ConstraintStudioController.getCMLSnippets';
import deleteCMLSnippet from '@salesforce/apex/ConstraintStudioController.deleteCMLSnippet';

export default class ConstraintStudio extends LightningElement {
    @api recordId;
    @api objectApiName;
    
    @track searchTerm = '';
    @track snippets = [];
    @track groupedSnippets = {
        constraints: { label: 'Constraints', items: [], expanded: true },
        require: { label: 'Require', items: [], expanded: true },
        message: { label: 'Message', items: [], expanded: true },
        setdefault: { label: 'SetDefault', items: [], expanded: true },
        rule: { label: 'Rule', items: [], expanded: true }
    };
    
    wiredSnippetsResult;
    
    @wire(getCMLSnippets, { 
        recordId: '$recordId', 
        objectApiName: '$objectApiName',
        searchTerm: '$searchTerm'
    })
    wiredSnippets(result) {
        this.wiredSnippetsResult = result;
        if (result.data) {
            this.snippets = result.data;
            this.groupSnippets();
        } else if (result.error) {
            this.showToast('Error', 'Error loading CML Snippets: ' + result.error.body.message, 'error');
        }
    }
    
    groupSnippets() {
        // Reset groups
        Object.keys(this.groupedSnippets).forEach(key => {
            this.groupedSnippets[key].items = [];
        });
        
        // Group snippets by keyword found in CML__c
        this.snippets.forEach(snippet => {
            const cml = snippet.CML__c ? snippet.CML__c.toLowerCase() : '';
            let grouped = false;
            
            // Check for each keyword
            if (cml.includes('constraint')) {
                this.groupedSnippets.constraints.items.push(snippet);
                grouped = true;
            }
            if (cml.includes('require')) {
                this.groupedSnippets.require.items.push(snippet);
                grouped = true;
            }
            if (cml.includes('message')) {
                this.groupedSnippets.message.items.push(snippet);
                grouped = true;
            }
            if (cml.includes('setdefault')) {
                this.groupedSnippets.setdefault.items.push(snippet);
                grouped = true;
            }
            if (cml.includes('rule')) {
                this.groupedSnippets.rule.items.push(snippet);
                grouped = true;
            }
            
            // If no keyword found, add to constraints by default
            if (!grouped) {
                this.groupedSnippets.constraints.items.push(snippet);
            }
        });
    }
    
    get sections() {
        return Object.keys(this.groupedSnippets).map(key => ({
            key: key,
            label: this.groupedSnippets[key].label,
            items: this.groupedSnippets[key].items,
            expanded: this.groupedSnippets[key].expanded,
            hasItems: this.groupedSnippets[key].items.length > 0
        }));
    }
    
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }
    
    handleToggleSection(event) {
        const sectionKey = event.currentTarget.dataset.key;
        this.groupedSnippets[sectionKey].expanded = !this.groupedSnippets[sectionKey].expanded;
        // Force re-render
        this.groupedSnippets = { ...this.groupedSnippets };
    }
    
    handleAddSnippet(event) {
        const sectionKey = event.currentTarget.dataset.key;
        // TODO: Implement create snippet functionality
        this.showToast('Info', `Add snippet to ${this.groupedSnippets[sectionKey].label} - Coming soon`, 'info');
    }
    
    async handleDeleteSnippet(event) {
        const snippetId = event.currentTarget.dataset.id;
        const snippetLabel = event.currentTarget.dataset.label;
        const snippetName = event.currentTarget.dataset.name;
        const displayName = snippetLabel || snippetName;
        
        if (confirm(`Are you sure you want to delete "${displayName}"?`)) {
            try {
                await deleteCMLSnippet({ snippetId: snippetId });
                this.showToast('Success', 'CML Snippet deleted successfully', 'success');
                // Refresh the data
                await refreshApex(this.wiredSnippetsResult);
            } catch (error) {
                this.showToast('Error', 'Error deleting CML Snippet: ' + error.body.message, 'error');
            }
        }
    }
    
    handleSnippetClick(event) {
        const snippetId = event.currentTarget.dataset.id;
        // TODO: Implement snippet selection for right pane
        console.log('Selected snippet:', snippetId);
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}
