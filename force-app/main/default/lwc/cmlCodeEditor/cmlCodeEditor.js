import { LightningElement, api, track } from 'lwc';

export default class CmlCodeEditor extends LightningElement {
    @api attributeDefinitions = [];
    
    @track showAutocomplete = false;
    @track autocompleteOptions = [];
    @track autocompletePosition = { top: 0, left: 0 };
    @track selectedIndex = 0;
    @track internalValue = '';
    
    currentWord = '';
    cursorPosition = 0;
    
    @api
    get value() {
        return this.internalValue;
    }
    
    set value(val) {
        this.internalValue = val;
    }
    
    renderedCallback() {
        // Update textarea value after render
        const textarea = this.template.querySelector('textarea');
        if (textarea && textarea.value !== this.internalValue) {
            textarea.value = this.internalValue;
        }
        
        // Update syntax highlighting
        this.updateSyntaxHighlighting();
    }
    
    updateSyntaxHighlighting() {
        const highlightLayer = this.template.querySelector('.syntax-highlight-layer');
        if (!highlightLayer) return;
        
        const highlighted = this.applySyntaxHighlighting(this.internalValue || '');
        highlightLayer.innerHTML = highlighted;
    }
    
    applySyntaxHighlighting(code) {
        if (!code) return '';
        
        // Escape HTML
        let highlighted = code
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
        
        // Highlight CML keywords
        const keywords = ['constraint', 'require', 'message', 'setdefault', 'rule', 'when', 'then', 'and', 'or', 'not'];
        keywords.forEach(keyword => {
            const regex = new RegExp(`\\b(${keyword})\\b`, 'gi');
            highlighted = highlighted.replace(regex, '<span class="syntax-keyword">$1</span>');
        });
        
        // Highlight strings (single and double quotes)
        highlighted = highlighted.replace(/(["'])(?:(?=(\\?))\2.)*?\1/g, '<span class="syntax-string">$&</span>');
        
        // Highlight numbers
        highlighted = highlighted.replace(/\b(\d+\.?\d*)\b/g, '<span class="syntax-number">$1</span>');
        
        // Highlight functions (word followed by parenthesis)
        highlighted = highlighted.replace(/\b([a-zA-Z_][\w]*)\s*\(/g, '<span class="syntax-function">$1</span>(');
        
        // Highlight operators
        highlighted = highlighted.replace(/([+\-*/%=<>!&|]+)/g, '<span class="syntax-operator">$1</span>');
        
        // Highlight product references (REL_ProductComponentGroup_ or REL_ProductRelatedComponent_)
        highlighted = highlighted.replace(/\b(REL_Product(?:ComponentGroup|RelatedComponent)_[\w]+)\b/g, '<span class="syntax-product">$1</span>');
        
        // Highlight attribute names (known attributes from suggestions)
        if (this.attributeDefinitions && this.attributeDefinitions.length > 0) {
            this.attributeDefinitions.forEach(attr => {
                if (attr.type === 'Attribute' && attr.value) {
                    const escapedValue = attr.value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                    const regex = new RegExp(`\\b(${escapedValue})\\b`, 'g');
                    highlighted = highlighted.replace(regex, '<span class="syntax-attribute">$1</span>');
                }
            });
        }
        
        return highlighted;
    }
    
    escapeRegex(str) {
        return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }
    
    get filteredOptions() {
        // If in contextual mode, use contextual suggestions
        if (this.contextualMode && this.contextualSuggestions) {
            return this.getContextualFilteredOptions();
        }
        
        if (!this.currentWord || this.currentWord.length < 2) {
            return [];
        }
        
        const searchTerm = this.currentWord.toLowerCase();
        return this.attributeDefinitions
            .filter(attr => {
                // Filter by value or displayName
                const value = attr.value || attr;
                const displayName = attr.displayName || attr;
                return value.toLowerCase().includes(searchTerm) || 
                       displayName.toLowerCase().includes(searchTerm);
            })
            .map((attr, index) => {
                const isSelected = index === this.selectedIndex;
                const value = attr.value || attr;
                const displayName = attr.displayName || attr;
                const actualName = attr.actualName || value;
                const color = attr.color || 'black';
                const type = attr.type || 'Attribute';
                
                return {
                    value: value,
                    displayName: displayName,
                    actualName: actualName,
                    color: color,
                    type: type,
                    isSelected: isSelected,
                    className: isSelected ? 'autocomplete-option selected' : 'autocomplete-option',
                    style: `color: ${color};`
                };
            });
    }
    
    get autocompleteStyle() {
        return `top: ${this.autocompletePosition.top}; left: ${this.autocompletePosition.left};`;
    }
    
    handleInput(event) {
        this.value = event.target.value;
        this.cursorPosition = event.target.selectionStart;
        
        // Dispatch change event to parent
        this.dispatchEvent(new CustomEvent('change', {
            detail: { value: this.value }
        }));
        
        // Check for autocomplete
        this.checkAutocomplete(event.target);
    }
    
    handleKeyDown(event) {
        if (this.showAutocomplete && this.filteredOptions.length > 0) {
            if (event.key === 'ArrowDown') {
                event.preventDefault();
                this.selectedIndex = (this.selectedIndex + 1) % this.filteredOptions.length;
            } else if (event.key === 'ArrowUp') {
                event.preventDefault();
                this.selectedIndex = this.selectedIndex === 0 ? this.filteredOptions.length - 1 : this.selectedIndex - 1;
            } else if (event.key === 'Enter' || event.key === 'Tab') {
                event.preventDefault();
                this.insertAutocomplete();
            } else if (event.key === 'Escape') {
                this.hideAutocomplete();
            }
        }
    }
    
    checkAutocomplete(textarea) {
        const text = textarea.value;
        const cursorPos = textarea.selectionStart;
        
        // Get the text before cursor
        const beforeCursor = text.substring(0, cursorPos);
        
        // Check if we're after a "[" character (context-aware)
        const bracketMatch = beforeCursor.match(/\[([^\]]*?)$/);
        
        if (bracketMatch) {
            // We're inside brackets - check what's before the "["
            const beforeBracket = beforeCursor.substring(0, beforeCursor.lastIndexOf('['));
            
            // Try to match REL_ format (ID format)
            let contextMatch = beforeBracket.match(/(REL_ProductComponentGroup_[\w]+|REL_ProductRelatedComponent_[\w]+)\s*$/);
            
            if (contextMatch) {
                // Found a context in ID format
                const contextValue = contextMatch[1];
                this.currentWord = bracketMatch[1]; // What's being typed after "["
                
                console.log('Context detected (ID format):', contextValue, 'searchTerm:', this.currentWord);
                
                // Dispatch event to parent to get contextual suggestions
                this.dispatchEvent(new CustomEvent('requestcontext', {
                    detail: { contextValue: contextValue, searchTerm: this.currentWord }
                }));
                return; // IMPORTANT: Don't continue to normal autocomplete
            }
            
            // Try to match display name format (human-readable)
            const displayNameMatch = beforeBracket.match(/([\w]+)\s*$/);
            if (displayNameMatch) {
                const displayName = displayNameMatch[1];
                
                // Look up the display name in attributeDefinitions to find the actual ID
                const suggestion = this.attributeDefinitions.find(attr => 
                    attr.actualName === displayName && 
                    (attr.type === 'ProductComponentGroup' || attr.type === 'Product')
                );
                
                if (suggestion) {
                    this.currentWord = bracketMatch[1]; // What's being typed after "["
                    
                    console.log('Context detected (display name):', displayName, '-> ID:', suggestion.value, 'searchTerm:', this.currentWord);
                    
                    // Dispatch event to parent to get contextual suggestions
                    this.dispatchEvent(new CustomEvent('requestcontext', {
                        detail: { contextValue: suggestion.value, searchTerm: this.currentWord }
                    }));
                    return;
                }
            }
            
            // Inside brackets but no context found - hide autocomplete
            console.log('Inside brackets but no context found');
            this.hideAutocomplete();
            return;
        }
        
        // Reset contextual mode if not in brackets
        if (this.contextualMode) {
            this.contextualMode = false;
            this.contextualSuggestions = null;
        }
        
        // Normal autocomplete (not in brackets)
        const wordMatch = beforeCursor.match(/[\w]+$/);
        
        if (wordMatch && wordMatch[0].length >= 2) {
            this.currentWord = wordMatch[0];
            const options = this.filteredOptions;
            
            if (options.length > 0) {
                this.selectedIndex = 0;
                this.calculateAutocompletePosition(textarea);
                this.showAutocomplete = true;
            } else {
                this.hideAutocomplete();
            }
        } else {
            this.hideAutocomplete();
        }
    }
    
    calculateAutocompletePosition(textarea) {
        // Get cursor coordinates
        const textBeforeCursor = textarea.value.substring(0, textarea.selectionStart);
        const lines = textBeforeCursor.split('\n');
        const currentLine = lines.length;
        const currentColumn = lines[lines.length - 1].length;
        
        // Approximate position (this is a simplified calculation)
        const lineHeight = 24; // Approximate line height
        const charWidth = 8; // Approximate character width
        
        this.autocompletePosition = {
            top: (currentLine * lineHeight) + 'px',
            left: (currentColumn * charWidth) + 'px'
        };
    }
    
    insertAutocomplete() {
        if (this.filteredOptions.length === 0) return;
        
        const selectedOption = this.filteredOptions[this.selectedIndex];
        const textarea = this.template.querySelector('textarea');
        const text = textarea.value;
        const cursorPos = textarea.selectionStart;
        
        // Find the start of the current word
        const beforeCursor = text.substring(0, cursorPos);
        const wordMatch = beforeCursor.match(/[\w]+$/);
        const wordStart = wordMatch ? cursorPos - wordMatch[0].length : cursorPos;
        
        // Determine what to insert based on type
        let insertValue;
        if (selectedOption.type === 'ProductComponentGroup' || selectedOption.type === 'Product') {
            // For products, insert the actualName (human-readable)
            insertValue = selectedOption.actualName || selectedOption.value;
        } else {
            // For attributes, insert the value
            insertValue = selectedOption.value;
        }
        
        // Replace the current word with the selected option
        const newText = text.substring(0, wordStart) + insertValue + text.substring(cursorPos);
        this.value = newText;
        
        // Store the mapping for later translation (if needed)
        if (selectedOption.type === 'ProductComponentGroup' || selectedOption.type === 'Product') {
            this.dispatchEvent(new CustomEvent('idmapping', {
                detail: {
                    displayName: insertValue,
                    actualValue: selectedOption.value,
                    type: selectedOption.type
                }
            }));
        }
        
        // Dispatch change event
        this.dispatchEvent(new CustomEvent('change', {
            detail: { value: this.value }
        }));
        
        this.hideAutocomplete();
        
        // Set cursor position after the inserted text
        setTimeout(() => {
            textarea.selectionStart = textarea.selectionEnd = wordStart + insertValue.length;
            textarea.focus();
        }, 0);
    }
    
    handleOptionClick(event) {
        event.preventDefault();
        event.stopPropagation();
        this.selectedIndex = parseInt(event.currentTarget.dataset.index);
        this.insertAutocomplete();
    }
    
    handleOptionMouseDown(event) {
        // Prevent blur when clicking on options
        event.preventDefault();
    }
    
    @api
    showContextualSuggestions(suggestions) {
        console.log('showContextualSuggestions called with:', suggestions);
        
        // Store original definitions
        this.contextualMode = true;
        this.contextualSuggestions = suggestions;
        
        // Force re-render of filtered options
        const options = this.getContextualFilteredOptions();
        
        console.log('Filtered contextual options:', options);
        
        if (options.length > 0) {
            this.selectedIndex = 0;
            const textarea = this.template.querySelector('textarea');
            if (textarea) {
                this.calculateAutocompletePosition(textarea);
            }
            this.showAutocomplete = true;
            console.log('Showing autocomplete with', options.length, 'options');
        } else {
            console.log('No options to show');
        }
    }
    
    getContextualFilteredOptions() {
        if (!this.contextualSuggestions || this.contextualSuggestions.length === 0) {
            return [];
        }
        
        const searchTerm = this.currentWord ? this.currentWord.toLowerCase() : '';
        
        const filtered = this.contextualSuggestions
            .filter(attr => {
                if (!searchTerm) return true;
                const value = attr.value || attr;
                const displayName = attr.displayName || attr;
                const actualName = attr.actualName || value;
                return value.toLowerCase().includes(searchTerm) || 
                       displayName.toLowerCase().includes(searchTerm) ||
                       actualName.toLowerCase().includes(searchTerm);
            });
        
        return filtered
            .map((attr, index) => {
                const isSelected = index === this.selectedIndex;
                const value = attr.value || attr;
                const displayName = attr.displayName || attr;
                const actualName = attr.actualName || value;
                const color = attr.color || 'black';
                const type = attr.type || 'Product';
                
                return {
                    value: value,
                    displayName: displayName,
                    actualName: actualName,
                    color: color,
                    type: type,
                    isSelected: isSelected,
                    className: isSelected ? 'autocomplete-option selected' : 'autocomplete-option',
                    style: `color: ${color};`
                };
            });
    }
    
    hideAutocomplete() {
        this.showAutocomplete = false;
        this.currentWord = '';
        this.selectedIndex = 0;
        this.contextualMode = false;
        this.contextualSuggestions = null;
    }
    
    handleBlur() {
        // Delay hiding to allow click on autocomplete options
        setTimeout(() => {
            this.hideAutocomplete();
        }, 300);
    }
}
