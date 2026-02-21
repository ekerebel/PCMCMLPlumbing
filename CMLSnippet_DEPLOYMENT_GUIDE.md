# CMLSnippet Custom Object - Deployment Guide

## Overview
The **CMLSnippet__c** custom object has been created to store CML (Constraint Modeling Language) code snippets with relationships to various parent objects in Revenue Cloud.

## Deployment Status

✅ **SUCCESSFULLY DEPLOYED - All components are live in stg4sgartner org!**

## Object Structure

### Fields Created:
1. **Name** - Text field (Auto-generated name) ✅ Deployed
2. **Type__c** - Picklist with values: ✅ Deployed
   - variable
   - annotation
   - constraint
3. **Object__c** - Picklist with values: ✅ Deployed
   - Product2
   - ProductClassification
   - ProductComponentGroup
   - ProductClassificationAttr
   - ProductRelComponentOverride
   - Virtual
4. **ParentProduct2__c** - Lookup to Product2 ✅ Deployed
5. **ParentProductClassification__c** - Lookup to ProductClassification ✅ Deployed
6. **ParentProductComponentGroup__c** - Lookup to ProductComponentGroup ✅ Deployed
7. **ParentProductClassificationAttr__c** - Lookup to ProductClassificationAttr ✅ Deployed
8. **ParentProductRelComponentOverride__c** - Lookup to ProductRelComponentOverride ✅ Deployed
9. **CML__c** - Long Text Area (32,768 characters) ✅ Deployed

## Deployment Commands

### Deploy All Components
```bash
# Deploy the entire CMLSnippet object
sf project deploy start --source-dir force-app/main/default/objects/CMLSnippet__c --target-org <your-org-alias> --ignore-conflicts --ignore-errors

# Or deploy just the fields
sf project deploy start --source-dir force-app/main/default/objects/CMLSnippet__c/fields --target-org <your-org-alias> --ignore-conflicts
```

### Verify Deployment
```bash
# Check deployment status
sf project deploy report --use-most-recent --target-org <your-org-alias>

# Test query
sf data query --query "SELECT Id, Name FROM CMLSnippet__c LIMIT 1" --target-org <your-org-alias>
```

## Adding Related Lists to Parent Objects

After deployment, you need to manually add the "CML Snippets" related list to the page layouts of the parent objects.

### Steps to Add Related Lists:

1. **Navigate to Setup** → Object Manager
2. **For each parent object** (Product2, ProductClassification, ProductComponentGroup, ProductClassificationAttr, ProductRelComponentOverride):
   
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
- ✅ ProductRelComponentOverride

## Relationship Names

The lookup fields create the following relationship names that can be used in SOQL queries:

- From Product2: `CML_Snippets__r`
- From ProductClassification: `CML_Snippets__r`
- From ProductComponentGroup: `CML_Snippets__r`
- From ProductClassificationAttr: `CML_Snippets__r`
- From ProductRelComponentOverride: `CML_Snippets__r`

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

-- Get all snippets related to ProductRelComponentOverride
SELECT Id, Name, Type__c, Object__c, CML__c
FROM CMLSnippet__c
WHERE ParentProductRelComponentOverride__c != null

-- Get snippets by object type
SELECT Id, Name, Type__c, CML__c
FROM CMLSnippet__c
WHERE Object__c = 'ProductRelComponentOverride'
```

## Usage Notes

1. **Multiple Parent Lookups**: Each CML Snippet can be related to only ONE parent object at a time. Use the **Object__c** picklist to indicate which parent object type is being referenced.

2. **CML Field**: The CML__c field supports up to 32,768 characters for storing constraint modeling language code.

3. **Field History Tracking**: History tracking is enabled on the object, allowing you to track changes to CML Snippets over time.

4. **ProductRelComponentOverride**: This is a custom object (with __c suffix) that represents product relationship component overrides in Revenue Cloud.

## Integration with BLOB Access

As discussed earlier, this object complements the ExpressionSetDefinitionVersion BLOB access pattern:

- **ExpressionSetDefinitionVersion**: Stores complete constraint models as BLOBs
- **CMLSnippet__c**: Stores reusable CML code snippets that can be referenced across multiple products/classifications

### BLOB Access Pattern (from earlier discussion):

**Reading BLOBs:**
1. Query ExpressionSetDefinitionVersion for the ConstraintModel field
2. The field returns a URL path like `/services/data/vXX.0/sobjects/ExpressionSetDefinitionVersion/{Id}/ConstraintModel`
3. Make a REST API GET request to `{instanceUrl} + {ConstraintModel URL path}` with proper authentication
4. The response body contains the raw BLOB data

**Updating BLOBs:**
1. Use REST API PATCH/POST to the same endpoint
2. Send binary data in the request body
3. Endpoint pattern: `{instanceUrl}/services/data/v{version}/sobjects/ExpressionSetDefinitionVersion/{recordId}/ConstraintModel`

You can use this pattern to:
1. Extract constraint models from ExpressionSetDefinitionVersion
2. Parse and create reusable snippets
3. Store them in CMLSnippet__c for easy reference and reuse

## Next Steps

1. ✅ Deploy the metadata to your Salesforce org (COMPLETED)
2. ✅ All fields including ParentProductRelComponentOverride__c are deployed (COMPLETED)
3. ⚠️ Add related lists to parent object page layouts (Manual step required)
4. Create permission sets if needed to grant access to the CMLSnippet__c object
5. Test creating CML Snippets and viewing them from parent objects

## Troubleshooting

### Deployment Issues
If you encounter deployment errors:
- Use `--ignore-conflicts` flag to bypass source tracking issues
- Use `--ignore-errors` flag to allow partial deployments (prevents rollback on error)
- Check that all parent objects exist in your target org

### Field Not Found Errors
If you get "No such column" errors when querying:
- Wait a few minutes for metadata to fully propagate
- Clear your org's schema cache
- Verify the field was actually deployed using `sf project deploy report`

### Related List Not Appearing
- Ensure the lookup field is deployed successfully
- Check that you're editing the correct page layout
- Verify the relationship name is `CML_Snippets` (with underscore, not hyphen)
