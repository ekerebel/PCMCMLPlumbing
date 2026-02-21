# Run CML Generator from Developer Console

## Quick Start - 3 Steps

### Step 1: Configure Remote Site Setting (One-time setup)

1. Go to **Setup** → Search for **Remote Site Settings**
2. Click **New Remote Site**
3. Fill in:
   - **Remote Site Name**: `SalesforceOrg`
   - **Remote Site URL**: Your org's URL (e.g., `https://your-instance.salesforce.com`)
   - **Active**: ✅ Checked
4. Click **Save**

### Step 2: Open Developer Console

1. Click the **⚙️ (gear icon)** in the top right
2. Select **Developer Console**

### Step 3: Run the Code

1. In Developer Console, click **Debug** → **Open Execute Anonymous Window**
2. Paste this code:

```apex
String result = CMLGenerator.execute();
System.debug('Result: ' + result);
```

3. Check **Open Log** checkbox
4. Click **Execute**
5. View the results in the log!

## What to Look For in the Log

The log will show:
- ✅ "=== CML Generator Started ==="
- ✅ "Found ExpressionSet: PCM_All"
- ✅ Number of snippets processed
- ✅ Generated CML content
- ✅ "BLOB updated successfully"
- ✅ "=== CML Generator Completed Successfully ==="

## Example Log Output

```
=== CML Generator Started ===
Found ExpressionSet: PCM_All
Current BLOB size: 0 characters
Found 3 ProductClassificationAttr annotation snippets
Processed 2 types from snippets
Created type: ProductClassification_a1B5e000000XyZ1EAK
Created type: ProductClassification_a1B5e000000XyZ2EAK
Generated CML size: 245 characters
Generated CML:
// @annotation("Product Classification 1")
type ProductClassification_a1B5e000000XyZ1EAK {
}

// @annotation("Product Classification 2")
type ProductClassification_a1B5e000000XyZ2EAK {
}

BLOB updated successfully. Status: 204
=== CML Generator Completed Successfully ===
Result: CML generated and updated successfully for 2 types.
```

## Troubleshooting

### Error: "Unauthorized endpoint"
- **Fix**: Configure the Remote Site Setting (Step 1 above)

### Error: "PCM_All ExpressionSet not found"
- **Fix**: Ensure you have an ExpressionSet with DeveloperName = 'PCM_All' in your org

### Error: "No such column 'ProductClassificationId'"
- **Fix**: Ensure Revenue Cloud is enabled in your org

### No snippets processed (0 types)
- **Fix**: Create CML Snippets with:
  - Object__c = 'ProductClassificationAttr'
  - Type__c = 'annotation'
  - ParentProductClassificationAttr__c populated

## Advanced: View More Debug Info

For more detailed logging, set the log level:

1. In Developer Console: **Debug** → **Change Log Levels**
2. Add your user
3. Set **Apex Code** to **FINEST**
4. Run the code again

## Safety Features

The code will ONLY work with the 'PCM_All' ExpressionSet. It has multiple safety checks to prevent accidental modification of other ExpressionSets.

## Next Steps

Once you verify it works from Developer Console, you can:
- Add the utility bar component to Product Catalog Management app
- Schedule it to run automatically
- Extend it to process more snippet types (per PCM_CML_Translation.md)
