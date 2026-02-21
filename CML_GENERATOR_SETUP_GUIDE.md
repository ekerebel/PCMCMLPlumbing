# CML Generator - Setup and Usage Guide

## Overview
The CML Generator automatically creates CML (Constraint Modeling Language) from CMLSnippet records and updates the PCM_All ExpressionSet BLOB.

**SAFETY**: The system ONLY works with the 'PCM_All' ExpressionSet to prevent accidental modification of other constraint models.

## What's Been Deployed

### ✅ Apex Classes (Deployed Successfully)
1. **CMLGenerator.cls** - Core logic for CML generation
2. **CMLGeneratorController.cls** - Controller for LWC

### ✅ Lightning Web Component (Ready to Deploy)
1. **cmlGeneratorButton** - UI component with button

## Next Steps

### Step 1: Configure Remote Site Setting

Before the HTTP callouts will work, you need to add a Remote Site Setting:

1. Go to **Setup** → **Remote Site Settings**
2. Click **New Remote Site**
3. Configure:
   - **Remote Site Name**: `SalesforceOrg`
   - **Remote Site URL**: Your org's instance URL (e.g., `https://your-instance.salesforce.com`)
   - **Description**: `Allow HTTP callouts to Salesforce org for BLOB access`
   - **Active**: ✅ Checked
4. Click **Save**

### Step 2: Deploy the LWC Component

```bash
cd /Users/ekerebel/Documents/SFDC\ Dev/PCMCMLPlumbing
sf project deploy start --source-dir force-app/main/default/lwc/cmlGeneratorButton --target-org stg4sgartner
```

### Step 3: Add Component to Product Catalog Management App

#### Option A: Via App Builder (Recommended)
1. Go to **Setup** → **App Manager**
2. Find **Product Catalog Management** app
3. Click dropdown → **Edit**
4. Click **Utility Items** (or **App Page**)
5. Add the **CML Generator Button** component
6. Save and activate

#### Option B: Via Lightning App Builder
1. Navigate to the Product Catalog Management app
2. Click **⚙️** (Setup gear) → **Edit Page**
3. Drag **cmlGeneratorButton** component onto the page
4. Save and activate

### Step 4: Test the Functionality

1. **Create Test CML Snippets**:
   - Go to CML Snippets tab
   - Create a snippet with:
     - Type: `annotation`
     - Object: `ProductClassificationAttr`
     - Parent Product Classification Attr: (select one)
     - CML: Your annotation code

2. **Run the Generator**:
   - Open Product Catalog Management app
   - Click the "Generate CML" button
   - Check for success toast message

3. **Verify in Debug Logs**:
   - Setup → Debug Logs
   - Create a trace flag for your user
   - Run the generator again
   - Check logs for detailed execution info

## How It Works

### Current Implementation (Step 1)

The generator currently:
1. Finds the PCM_All ExpressionSet
2. Reads the current BLOB content
3. Processes CML Snippets where:
   - `Object__c = 'ProductClassificationAttr'`
   - `Type__c = 'annotation'`
4. Groups snippets by ProductClassification
5. Generates CML with format:
   ```
   <annotation>
   type ProductClassification_<Id> {
   }
   ```
6. Updates the PCM_All BLOB

### Future Enhancements (Per PCM_CML_Translation.md)

The system is designed to be extended to:
- Process other object types (Product2, ProductComponentGroup, etc.)
- Add constraint snippets
- Add relation snippets
- Build complete CML with relations and cardinality

## Safety Features

1. **Hard-coded ExpressionSet Name**: Only works with 'PCM_All'
2. **Multiple Validation Checks**: Validates before read and write operations
3. **Detailed Logging**: All operations logged to debug logs
4. **Error Handling**: User-friendly error messages via toast notifications

## Troubleshooting

### Error: "PCM_All ExpressionSet not found"
- Ensure the ExpressionSet exists in your org
- Check the DeveloperName is exactly 'PCM_All'

### Error: "Unauthorized endpoint"
- Configure the Remote Site Setting (see Step 1)
- Ensure the URL matches your org's instance

### Error: "No such column 'ProductClassificationId'"
- This field is standard on ProductClassificationAttr
- Verify you have Revenue Cloud enabled

### No snippets processed
- Check that you have CML Snippets with:
  - Object__c = 'ProductClassificationAttr'
  - Type__c = 'annotation'
  - ParentProductClassificationAttr__c is populated

## Files Created

```
force-app/main/default/
├── classes/
│   ├── CMLGenerator.cls
│   ├── CMLGenerator.cls-meta.xml
│   ├── CMLGeneratorController.cls
│   └── CMLGeneratorController.cls-meta.xml
└── lwc/
    └── cmlGeneratorButton/
        ├── cmlGeneratorButton.html
        ├── cmlGeneratorButton.js
        └── cmlGeneratorButton.js-meta.xml
```

## API Reference

### CMLGenerator.execute()
Main entry point for CML generation.

**Returns**: `String` - Success message
**Throws**: `CMLGeneratorException` - On any error

### CMLGeneratorController.generateCML()
@AuraEnabled method for LWC.

**Returns**: `String` - Success message
**Throws**: `AuraHandledException` - On any error

### CMLGeneratorController.checkPCMAllExists()
Checks if PCM_All exists.

**Returns**: `Boolean` - True if exists
**Cacheable**: Yes

### CMLGeneratorController.getSnippetCount()
Gets count of processable snippets.

**Returns**: `Integer` - Count of snippets
**Cacheable**: Yes

## Next Development Steps

To continue building out the CML generation per PCM_CML_Translation.md:

1. Add processing for other snippet types (constraints, variables)
2. Add processing for other object types (Product2, etc.)
3. Implement relation building
4. Add cardinality support
5. Create test classes
6. Add bulk processing capabilities

## Support

For issues or questions:
- Check debug logs for detailed error information
- Review PCM_CML_Translation.md for requirements
- Review CML_Blob_Update.md for BLOB access patterns
