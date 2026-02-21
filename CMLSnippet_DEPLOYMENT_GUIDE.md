# CMLSnippet Custom Object - Deployment Guide

## Overview
The **CMLSnippet__c** custom object has been created to store CML (Constraint Modeling Language) code snippets with relationships to various parent objects in Revenue Cloud.

## Object Structure

### Fields Created:
1. **Name** - Text field (Auto-generated name)
2. **Type__c** - Picklist with values:
   - variable
   - annotation
   - constraint
3. **Object__c** - Picklist with values:
   - Product2
   - ProductClassification
   - ProductComponentGroup
   - ProductClassificationAttr
   - ProductRelatedComponent
   - Virtual
4. **ParentProduct2__c** - Lookup to Product2 ✅ Deployed
5. **ParentProductClassification__c** - Lookup to ProductClassification ✅ Deployed
6. **ParentProductComponentGroup__c** - Lookup to ProductComponentGroup ✅ Deployed
7. **ParentProductClassificationAttr__c** - Lookup to ProductClassificationAttr ✅ Deployed
8. **ParentProductRelatedComponent__c** - Lookup to ProductRelatedComponent ⚠️ **Requires Manual Creation**
9. **CML__c** - Long Text Area (32,768 characters) ✅ Deployed

## Deployment Status

✅ **Successfully Deployed (8/9 components):**
- CMLSnippet__c object
- Type__c field
- Object__c field
- ParentProduct2__c field
- ParentProductClassification__c field
- ParentProductComponentGroup__c field
- ParentProductClassificationAttr__c field
- CML__c field

⚠️ **Requires Manual Creation:**
- ParentProductRelatedComponent__c field (see instructions below)

## Manual Field Creation Required

The `ParentProductRelatedComponent__c` lookup field could not be deployed via metadata API. You need to create it manually:

### Steps to Create ParentProductRelatedComponent__c Field:

1. **Navigate to Setup** → Object Manager → CML Snippet
2. Click **Fields & Relationships**
3. Click **New**
4. Select **Lookup Relationship** → Click **Next**
5. **Related To:** Select `ProductRelatedComponent`
6. Click **Next**
7. **Field Label:** `Parent Product Related Component`
8. **Field Name:** `ParentProductRelatedComponent` (should auto-populate)
9. Click **Next**
10. **Field-Level Security:** Set as needed → Click **Next**
11. **Add to Page Layouts:** Check the layouts where you want this field → Click **Next**
12. **Related List Label:** `CML Snippets`
13. Click **Save**

## Deployment Instructions

### 1. Deploy to Salesforce Org
```bash
# Deploy to your target org
sf project deploy start --target-org <your-org-alias> --ignore-conflicts

# Or deploy just the CMLSnippet object
sf project deploy start --source-dir force-app/main/default/objects/CMLSnippet__c --target-org <your-org-alias> --ignore-conflicts
```

### 2. Verify Deployment
```bash
# Check deployment status
sf project deploy report --use-most-recent --target-org <your-org-alias>
```

## Adding Related Lists to Parent Objects

After deployment, you need to manually add the "CML Snippets" related list to the page layouts of the parent objects.

### Steps to Add Related Lists:

1. **Navigate to Setup** → Object Manager
2. **For each parent object** (Product2, ProductClassification, ProductComponentGroup, ProductClassificationAttr, ProductRelatedComponent):
   
   a. Click on the object name
   
   b. Go to **Page Layouts**
   
   c. Click on the layout you want to edit (e.g., "Product2 Layout")
   
   d. In the page layout editor, find **Related Lists** in the palette
   
   e. Drag **"CML Snippets"** to the Related Lists section
   
   f. Click the wrench icon on the related list to configure columns
   
   g. Add these columns to display:
      - Name
      - Type
      - Object
   
   h. Click **OK** and then **Save** the layout

### Parent Objects to Update:
- ✅ Product2
- ✅ ProductClassification
- ✅ ProductComponentGroup
- ✅ ProductClassificationAttr
- ✅ ProductRelatedComponent

## Relationship Names

The lookup fields create the following relationship names that can be used in SOQL queries:

- From Product2: `CML_Snippets__r`
- From ProductClassification: `CML_Snippets__r`
- From ProductComponentGroup: `CML_Snippets__r`
- From ProductClassificationAttr: `CML_Snippets__r`
- From ProductRelatedComponent: `CML_Snippets__r`

### Example SOQL Queries:

```sql
-- Get all CML Snippets for a specific Product2
SELECT Id, Name, Type__c, Object__c, CML__c 
FROM CMLSnippet__c 
WHERE ParentProduct2__c = '01tXXXXXXXXXXXX'

-- Get Product2 with related CML Snippets
SELECT Id, Name, 
       (SELECT Id, Name, Type__c, Object__c FROM CML_Snippets__r)
FROM Product2
WHERE Id = '01tXXXXXXXXXXXX'

-- Get all constraint-type snippets
SELECT Id, Name, Object__c, CML__c
FROM CMLSnippet__c
WHERE Type__c = 'constraint'

-- Get all snippets related to ProductRelatedComponent (after manual field creation)
SELECT Id, Name, Type__c, Object__c, CML__c
FROM CMLSnippet__c
WHERE ParentProductRelatedComponent__c != null
```

## Usage Notes

1. **Multiple Parent Lookups**: Each CML Snippet can be related to only ONE parent object at a time. Use the **Object__c** picklist to indicate which parent object type is being referenced.

2. **CML Field**: The CML__c field supports up to 32,768 characters for storing constraint modeling language code.

3. **Field History Tracking**: History tracking is enabled on the object, allowing you to track changes to CML Snippets over time.

4. **ProductRelatedComponent Limitation**: Due to metadata API limitations, the lookup to ProductRelatedComponent must be created manually through the UI (see instructions above).

## Integration with BLOB Access

As discussed earlier, this object complements the ExpressionSetDefinitionVersion BLOB access pattern:

- **ExpressionSetDefinitionVersion**: Stores complete constraint models as BLOBs
- **CMLSnippet__c**: Stores reusable CML code snippets that can be referenced across multiple products/classifications

You can use the BLOB access pattern documented earlier to:
1. Extract constraint models from ExpressionSetDefinitionVersion
2. Parse and create reusable snippets
3. Store them in CMLSnippet__c for easy reference and reuse

## Next Steps

1. ✅ Deploy the metadata to your Salesforce org (COMPLETED)
2. ⚠️ Manually create the ParentProductRelatedComponent__c lookup field (see instructions above)
3. Add related lists to parent object page layouts
4. Create permission sets if needed to grant access to the CMLSnippet__c object
5. Test creating CML Snippets and viewing them from parent objects

## Troubleshooting

### ProductRelatedComponent Field Issue
If you encounter the error "referenceTo value of 'ProductRelatedComponent' does not resolve to a valid sObject type" when trying to deploy via metadata, this is a known limitation. The ProductRelatedComponent object may have special characteristics that prevent lookup field creation via the Metadata API. Always create this field manually through the UI.
