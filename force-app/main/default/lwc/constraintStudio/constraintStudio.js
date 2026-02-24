import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCMLSnippets from '@salesforce/apex/ConstraintStudioController.getCMLSnippets';
import deleteCMLSnippet from '@salesforce/apex/ConstraintStudioController.deleteCMLSnippet';
import saveCMLSnippet from '@salesforce/apex/ConstraintStudioController.saveCMLSnippet';
import createCMLSnippet from '@salesforce/apex/ConstraintStudioController.createCMLSnippet';
import getAttributeDefinitions from '@salesforce/apex/ConstraintStudioController.getAttributeDefinitions';

export default class ConstraintStudio extends LightningElement {
    @api recordId;
    @api objectApiName;
    
    @track searchTerm = '';
    @track snippets = [];
    @track groupedSnippets = {
        constraints: { label: 'Constraints', items: [], expanded: true, keyword: 'constraint' },
        require: { label: 'Require', items: [], expanded: true, keyword: 'require' },
        message: { label: 'Message', items: [], expanded: true, keyword: 'message' },
        setdefault: { label: 'SetDefault', items: [], expanded: true, keyword: 'setdefault' },
        rule: { label: 'Rule', items: [], expanded: true, keyword: 'rule' }
    };
    
    @track selectedSnippet = null;
    @track editLabel = '';
    @track editCML = '';
    @track showCMLEditor = false;
    @track isSaving = false;
    @track attributeDefinitions = [];
    
    wiredSnippetsResult;
    
    @wire(getAttributeDefinitions, {
        recordId: '$recordId',
        objectApiName: '$objectApiName'
    })
    wiredAttributeDefinitions(result) {
        if (result.data) {
            this.attributeDefinitions = result.data;
        } else if (result.error) {
            console.error('Error loading attribute definitions:', result.error);
        }
    }
    
    connectedCallback() {
        this.loadSnippets();
    }
    
    async loadSnippets() {
        try {
            const data = await getCMLSnippets({
                recordId: this.recordId,
                objectApiName: this.objectApiName,
                searchTerm: this.searchTerm,
                cacheBuster: String(Date.now())
            });
            console.log('Loaded snippets:', data);
            this.snippets = data;
            this.groupSnippets();
        } catch (error) {
            this.showToast('Error', 'Error loading CML Snippets: ' + error.body.message, 'error');
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
            
            // Add isSelected property
            const enhancedSnippet = {
                ...snippet,
                isSelected: this.selectedSnippet && snippet.Id === this.selectedSnippet.Id ? 'snippet-item selected' : 'snippet-item'
            };
            
            // Check for each keyword
            if (cml.includes('constraint')) {
                this.groupedSnippets.constraints.items.push(enhancedSnippet);
                grouped = true;
            }
            if (cml.includes('require')) {
                this.groupedSnippets.require.items.push(enhancedSnippet);
                grouped = true;
            }
            if (cml.includes('message')) {
                this.groupedSnippets.message.items.push(enhancedSnippet);
                grouped = true;
            }
            if (cml.includes('setdefault')) {
                this.groupedSnippets.setdefault.items.push(enhancedSnippet);
                grouped = true;
            }
            if (cml.includes('rule')) {
                this.groupedSnippets.rule.items.push(enhancedSnippet);
                grouped = true;
            }
            
            // If no keyword found, add to constraints by default
            if (!grouped) {
                this.groupedSnippets.constraints.items.push(enhancedSnippet);
            }
        });
    }
    
    get sections() {
        return Object.keys(this.groupedSnippets).map(key => ({
            key: key,
            label: this.groupedSnippets[key].label,
            items: this.groupedSnippets[key].items,
            expanded: this.groupedSnippets[key].expanded,
            hasItems: this.groupedSnippets[key].items.length > 0,
            keyword: this.groupedSnippets[key].keyword
        }));
    }
    
    get hasSelectedSnippet() {
        return this.selectedSnippet !== null;
    }
    
    get displayLabel() {
        return this.editLabel || this.selectedSnippet?.Name || 'New Snippet';
    }
    
    get highlightedCML() {
        if (!this.editCML) return '';
        
        let highlighted = this.editCML;
        const keywords = ['constraint', 'require', 'message', 'setdefault', 'rule'];
        
        keywords.forEach(keyword => {
            const regex = new RegExp(`\\b${keyword}\\b`, 'gi');
            highlighted = highlighted.replace(regex, `<span class="keyword">${keyword}</span>`);
        });
        
        return highlighted;
    }
    
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        // Reload snippets when search changes
        this.loadSnippets();
    }
    
    handleToggleSection(event) {
        const sectionKey = event.currentTarget.dataset.key;
        this.groupedSnippets[sectionKey].expanded = !this.groupedSnippets[sectionKey].expanded;
        // Force re-render
        this.groupedSnippets = { ...this.groupedSnippets };
    }
    
    async handleAddSnippet(event) {
        const sectionKey = event.currentTarget.dataset.key;
        const keyword = this.groupedSnippets[sectionKey].keyword;
        
        try {
            const newSnippet = await createCMLSnippet({
                recordId: this.recordId,
                objectApiName: this.objectApiName,
                keyword: keyword,
                label: ''
            });
            
            this.showToast('Success', 'CML Snippet created successfully', 'success');
            
            // Reload snippets
            await this.loadSnippets();
            
            // Select the new snippet with CML editor showing
            const refreshedSnippet = this.snippets.find(s => s.Id === newSnippet.Id);
            this.selectSnippet(refreshedSnippet || newSnippet, true);
        } catch (error) {
            this.showToast('Error', 'Error creating CML Snippet: ' + error.body.message, 'error');
        }
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
                
                // Clear selection if deleted snippet was selected
                if (this.selectedSnippet && this.selectedSnippet.Id === snippetId) {
                    this.selectedSnippet = null;
                }
                
                // Reload snippets
                await this.loadSnippets();
            } catch (error) {
                this.showToast('Error', 'Error deleting CML Snippet: ' + error.body.message, 'error');
            }
        }
    }
    
    handleSnippetClick(event) {
        const snippetId = event.currentTarget.dataset.id;
        const snippet = this.snippets.find(s => s.Id === snippetId);
        if (snippet) {
            this.selectSnippet(snippet);
        }
    }
    
    selectSnippet(snippet, isNewSnippet = false) {
        console.log('selectSnippet called', snippet, 'isNewSnippet:', isNewSnippet);
        console.log('snippet.CML__c:', snippet.CML__c);
        this.selectedSnippet = snippet;
        this.editLabel = snippet.Label__c || '';
        this.editCML = snippet.CML__c || '';
        console.log('editCML set to:', this.editCML);
        // Show CML editor by default for new snippets
        this.showCMLEditor = isNewSnippet;
        // Force re-render to update selection highlighting
        this.groupSnippets();
    }
    
    handleLabelChange(event) {
        this.editLabel = event.target.value;
    }
    
    handleCMLChange(event) {
        this.editCML = event.detail.value;
    }
    
    handleToggleCML(event) {
        this.showCMLEditor = event.target.checked;
    }
    
    async handleSave() {
        if (!this.selectedSnippet) return;
        
        this.isSaving = true;
        try {
            await saveCMLSnippet({
                snippetId: this.selectedSnippet.Id,
                label: this.editLabel,
                cml: this.editCML
            });
            
            this.showToast('Success', 'CML Snippet saved successfully', 'success');
            
            // Reload snippets
            await this.loadSnippets();
            
            // Update selected snippet
            const updatedSnippet = this.snippets.find(s => s.Id === this.selectedSnippet.Id);
            if (updatedSnippet) {
                this.selectSnippet(updatedSnippet);
            }
        } catch (error) {
            this.showToast('Error', 'Error saving CML Snippet: ' + error.body.message, 'error');
        } finally {
            this.isSaving = false;
        }
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}
