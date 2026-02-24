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
    }
    
    get filteredOptions() {
        if (!this.currentWord || this.currentWord.length < 2) {
            return [];
        }
        
        const searchTerm = this.currentWord.toLowerCase();
        return this.attributeDefinitions
            .filter(attr => attr.toLowerCase().includes(searchTerm))
            .map((attr, index) => ({
                value: attr,
                isSelected: index === this.selectedIndex,
                className: index === this.selectedIndex ? 'autocomplete-option selected' : 'autocomplete-option'
            }));
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
        
        // Get the word at cursor position
        const beforeCursor = text.substring(0, cursorPos);
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
        
        const selectedOption = this.filteredOptions[this.selectedIndex].value;
        const textarea = this.template.querySelector('textarea');
        const text = textarea.value;
        const cursorPos = textarea.selectionStart;
        
        // Find the start of the current word
        const beforeCursor = text.substring(0, cursorPos);
        const wordMatch = beforeCursor.match(/[\w]+$/);
        const wordStart = wordMatch ? cursorPos - wordMatch[0].length : cursorPos;
        
        // Replace the current word with the selected option
        const newText = text.substring(0, wordStart) + selectedOption + text.substring(cursorPos);
        this.value = newText;
        
        // Dispatch change event
        this.dispatchEvent(new CustomEvent('change', {
            detail: { value: this.value }
        }));
        
        this.hideAutocomplete();
        
        // Set cursor position after the inserted text
        setTimeout(() => {
            textarea.selectionStart = textarea.selectionEnd = wordStart + selectedOption.length;
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
    
    hideAutocomplete() {
        this.showAutocomplete = false;
        this.currentWord = '';
        this.selectedIndex = 0;
    }
    
    handleBlur() {
        // Delay hiding to allow click on autocomplete options
        setTimeout(() => {
            this.hideAutocomplete();
        }, 300);
    }
}
