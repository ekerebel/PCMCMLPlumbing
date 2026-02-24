# Constraint Studio Component Guide

## Overview
The **Constraint Studio** is a Lightning Web Component (LWC) designed to administer CMLSnippet__c records associated with Product2 and ProductClassification records. It provides an intuitive interface for managing constraint-type CML snippets.

## Features

### Left Pane - Explorer
- **Search Bar**: Filter CML Snippets by label or CML content
- **Grouped Sections**: Snippets are automatically organized into sections based on keywords found in the CML__c field:
  - **Constraints**: Contains snippets with "constraint" keyword
  - **Require**: Contains snippets with "require" keyword
  - **Message**: Contains snippets with "message" keyword
  - **SetDefault**: Contains snippets with "setdefault" keyword
  - **Rule**: Contains snippets with "rule" keyword
- **Collapsible Sections**: Click on section headers to expand/collapse
- **Add Button**: Each section has a "+" button to create new snippets (functionality to be implemented)
- **Delete Button**: Each snippet has a trash icon for deletion (appears on hover)

### Right Pane
- Currently displays a white placeholder for future functionality

## Components Created

### 1. Custom Field
- **Label__c** (Text, 255 characters) - Added to CMLSnippet__c object
  - Used to display a user-friendly name for each snippet in the explorer

### 2. Apex Controller
- **ConstraintStudioController.cls**
  - `getCMLSnippets()`: Retrieves CML Snippets filtered by:
    - Record ID (Product2 or ProductClassification)
    - Type = 'constraint'
    - Optional search term
  - `deleteCMLSnippet()`: Deletes a CML Snippet by ID

### 3. Lightning Web Component
- **constraintStudio**
  - JavaScript: Handles data fetching, grouping, search, and user interactions
  - HTML: Renders the two-pane layout with explorer and placeholder
  - CSS: Provides styling matching the Salesforce Lightning Design System
  - Metadata: Configured for Product2 and ProductClassification record pages

## Deployment Steps

### Quick Deploy (Recommended)
Use the provided deployment script:
```bash
./deploy-constraint-studio.sh
```

This script will deploy all components in the correct order:
1. Label__c field
2. Updated permission set
3. Apex controller
4. LWC component
5. Updated layout

### Manual Deployment
If you prefer to deploy manually:

1. **Deploy the Custom Field**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/objects/CMLSnippet__c/fields/Label__c.field-meta.xml
   ```

2. **Deploy the Permission Set**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/permissionsets/CMLSnippet_Access.permissionset-meta.xml
   ```

3. **Deploy the Apex Controller**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/classes/ConstraintStudioController.cls,force-app/main/default/classes/ConstraintStudioController.cls-meta.xml
   ```

4. **Deploy the LWC Component**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/lwc/constraintStudio
   ```

5. **Deploy the Updated Layout**
   ```bash
   sfdx force:source:deploy -p "force-app/main/default/layouts/CMLSnippet__c-CML Snippet Layout.layout-meta.xml"
   ```

### Post-Deployment
After deployment, assign the **CML Snippet Access** permission set to your user:
```bash
sfdx force:user:permset:assign -n CMLSnippet_Access
```

## Adding to Record Pages

1. Navigate to a Product2 or ProductClassification record
2. Click the gear icon and select **Edit Page**
3. In the Lightning App Builder, find **Constraint Studio** in the component list
4. Drag and drop it onto the page layout
5. Save and activate the page

## Usage

### Viewing Snippets
- The component automatically loads all constraint-type CML Snippets associated with the current record
- Snippets are grouped by keyword and displayed in collapsible sections
- Each section shows the count of snippets it contains

### Searching
- Type in the search bar to filter snippets by Label or CML content
- The search is case-insensitive and updates in real-time

### Deleting Snippets
- Hover over a snippet to reveal the delete (trash) icon
- Click the trash icon and confirm the deletion
- The list refreshes automatically after deletion

### Creating Snippets
- Click the "+" button in any section header
- Currently shows an informational message (functionality to be implemented in future iterations)

## Data Model

### CMLSnippet__c Fields Used
- **Id**: Unique identifier
- **Name**: Auto-number field
- **Label__c**: User-friendly display name (NEW)
- **CML__c**: The CML code content
- **Type__c**: Must be 'constraint' to appear in this component
- **ParentProduct2__c**: Lookup to Product2
- **ParentProductClassification__c**: Lookup to ProductClassification

## Grouping Logic

Snippets are grouped based on keywords found in the CML__c field:
- A snippet can appear in multiple sections if its CML contains multiple keywords
- Keywords are case-insensitive
- If no keyword is found, the snippet defaults to the "Constraints" section

## Future Enhancements

1. **Right Pane**: Display detailed snippet editor when a snippet is selected
2. **Create Functionality**: Implement the "+" button to create new snippets
3. **Edit Functionality**: Allow inline editing of snippet labels
4. **Drag and Drop**: Reorder snippets within sections
5. **Bulk Operations**: Select multiple snippets for bulk actions
6. **Validation**: Add CML syntax validation
7. **Preview**: Show CML execution preview

## Troubleshooting

### Component Not Appearing
- Verify the component is deployed successfully
- Check that you're on a Product2 or ProductClassification record page
- Ensure you have the necessary permissions to view CMLSnippet__c records

### No Snippets Showing
- Verify that CMLSnippet__c records exist for the current record
- Check that the Type__c field is set to 'constraint'
- Verify the parent lookup field (ParentProduct2__c or ParentProductClassification__c) is populated

### Delete Not Working
- Ensure you have delete permissions on CMLSnippet__c
- Check the browser console for error messages

## Technical Notes

- The component uses `@wire` for reactive data fetching
- Search is debounced through the wire service
- Delete operations refresh the data using `refreshApex()`
- The component is responsive and follows SLDS design patterns
