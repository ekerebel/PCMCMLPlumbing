# CML Generation Algorithm - Functional Description

## Overview

This document describes the functional algorithm for converting CMLSnippet records into a complete CML (Constraint Modeling Language) file for the PCM_All ExpressionSet in Salesforce Revenue Cloud.

## Data Structure

The algorithm maintains an in-memory collection of **Types**, where each type represents either a ProductClassification or a Product2 record.

### Type Structure
Each type contains:
- **Type Name**: `ProductClassification_<ID>` or `Product2_<ID>` (or clean Product2 name for virtual types)
- **Annotation**: String containing type-level annotations
- **Reference Object ID**: The Salesforce ID of the ProductClassification or Product2
- **Attributes Array**: Collection of attribute definitions
- **Constraints Array**: Collection of constraint strings
- **Relations Array**: Collection of relations to other types

### Attribute Structure
Each attribute contains:
- **Name**: AttributeDefinition.DeveloperName
- **Domain**: Data type (`decimal(2)` for Number, `string` for others)
- **Annotation**: Attribute-level annotations
- **AttributeDefinition ID**: Reference to the AttributeDefinition
- **ProductClassificationAttr/ProductAttributeDefinition ID**: Reference to the parent record
- **Picklist ID**: If the attribute uses a picklist
- **Default Value**: Default value for the attribute

### Relation Structure
Each relation contains:
- **Object Type**: Either `ProductComponentGroup` or `ProductRelatedComponent`
- **Object ID**: The Salesforce ID of the ProductComponentGroup or ProductRelatedComponent
- **Annotation**: Relation-level annotations
- **Reference Type**: The target type name

---

## Processing Steps

### Step 1: Process ProductClassificationAttr Annotation Snippets

**Query**: `Object__c = 'ProductClassificationAttr' AND Type__c = 'annotation'`

For each snippet:
1. Navigate from `ParentProductClassificationAttr__c` → `ProductClassificationId` to identify the ProductClassification
2. Create or retrieve the type: `ProductClassification_<ID>`
3. Add the attribute to the type's attributes array:
   - Name: From `AttributeDefinition.DeveloperName`
   - Annotation: From the snippet's `CML__c` field
   - Domain: Based on `AttributeDefinition.DataType`
   - Store AttributeDefinition ID, ProductClassificationAttr ID, Picklist ID, and Default Value

**Note**: Type-level annotations are NOT taken from ProductClassificationAttr at this stage.

---

### Step 2: Process ProductClassification Constraint Snippets

**Query**: `Object__c = 'ProductClassification' AND Type__c = 'constraint'`

For each snippet:
1. Navigate from `ParentProductClassification__c` to identify the ProductClassification
2. Create or retrieve the type: `ProductClassification_<ID>`
3. Add the constraint string to the type's constraints array
4. **Parse the constraint** to identify referenced elements:

#### Attribute Detection
- Query all `ProductClassificationAttr` records for this ProductClassification
- For each ProductClassificationAttr, get the `AttributeDefinition.DeveloperName`
- Check if the DeveloperName appears in the constraint string
- If found and not already in the type's attributes array, add it (without annotation)

#### Relation Detection
- **ProductComponentGroup Pattern**: `ProductComponentGroup_<ID>` or `REL_ProductComponentGroup_<ID>`
- **ProductRelatedComponent Pattern**: `ProductRelatedComponent_<ID>` or `REL_ProductRelatedComponent_<ID>`
- Extract IDs and add to the type's relations array

---

### Step 3: Process Product2 Constraint Snippets

**Query**: `Object__c = 'Product2' AND Type__c = 'constraint'`

For each snippet:
1. Navigate from `ParentProduct2__c` to identify the Product2
2. Create or retrieve the type: `Product2_<ID>`
3. Add the constraint string to the type's constraints array
4. **Parse the constraint** to identify referenced elements:

#### Attribute Detection (Two Paths)

**Path A - Product2 Attributes**:
- Query all `ProductAttributeDefinition` records for this Product2
- For each ProductAttributeDefinition, get the `AttributeDefinition.DeveloperName`
- Check if the DeveloperName appears in the constraint string
- If found and not already in the type's attributes array, add it

**Path B - ProductClassification Attributes**:
- Get the Product2's `BasedOnId` (ProductClassification)
- Query all `ProductClassificationAttr` records for that ProductClassification
- For each ProductClassificationAttr, get the `AttributeDefinition.DeveloperName`
- Check if the DeveloperName appears in the constraint string
- If found and not already in the type's attributes array, add it

#### Relation Detection
Same as ProductClassification (ProductComponentGroup and ProductRelatedComponent patterns)

---

## CML Generation

### Initialization
1. Start with: `property allowMissingRelations = "true";\n\n`
2. Delete all existing `ExpressionSetConstraintObj` records for the PCM_All ExpressionSet

### For Each Type

#### Type Declaration

**Standard Types**:
```
[type annotation if present]
[Product2 annotation if present and type is Product2]
type <TypeName> [: <ParentClassification>] {
```

**Virtual Product2 Types** (with `@(virtual=true)` annotation):
```
@(virtual=true)
type <CleanProduct2Name> : <ParentClassification> {
```
- Clean name: Product2.Name with special characters replaced by underscores
- **No ExpressionSetConstraintObj record created for virtual types**

**Inheritance**:
- For Product2 types, query `Product2.BasedOnId` to get the ProductClassification
- Add `: ProductClassification_<ID>` after the type name
- Ensure the ProductClassification type exists (create if needed)

#### Constraints
For each constraint in the type's constraints array:
```
    <constraint string>
```

#### Attributes
For each attribute in the type's attributes array:

1. **Determine Domain Values** (if picklist):
   - Query `AttributePicklistValue` for the picklist
   - Exclude values listed in `AttrPicklistExcludedValue` for this ProductClassificationAttr/ProductAttributeDefinition
   - Track the default value (from picklist `IsDefault` or ProductClassificationAttr/ProductAttributeDefinition `DefaultValue`)

2. **Build Annotation**:
   - Start with the attribute's annotation (if any)
   - If a default value exists, add or append: `defaultValue = "<value>"`
   - Example: `@(defaultValue = "Hydrogen (H2)", domainComputation = "true", sequence = 6)`

3. **Generate Attribute Line**:
```
    [annotation if present]
    <domain> <AttributeName>[ = ["value1", "value2", ...]];
```

#### Relations
For each relation in the type's relations array:

**ProductRelatedComponent Relations**:
1. Query the ProductRelatedComponent for `ChildProductId`, `MinQuantity`, `MaxQuantity`
2. Ensure the child Product2 type exists (create if needed)
3. **For virtual Product2 parent types**, add:
   ```
   @(sourceContextNode = "SalesTransaction.SalesTransactionItem")
   ```
4. Generate:
   ```
   [relation annotation if present]
   relation REL_ProductRelatedComponent_<ID> : Product2_<ChildProductId>[<MinQuantity>..<MaxQuantity>];
   ```
5. Create ExpressionSetConstraintObj:
   - ReferenceObjectId: ProductRelatedComponent ID
   - ConstraintModelTag: `REL_ProductRelatedComponent_<ID>`
   - ConstraintModelTagType: `Port`

**ProductComponentGroup Relations**:

Query the ProductComponentGroup for `MinBundleComponents`, `MaxBundleComponents`

**Qualification Check** (for ProductClassification relation):
- `MaxBundleComponents == 1`
- All ProductRelatedComponents have non-null `ChildProductId`
- All child Product2 records have the same `BasedOnId` (ProductClassification)

**If Qualified**:
1. Ensure all child Product2 types exist
2. **For virtual Product2 parent types**, add:
   ```
   @(sourceContextNode = "SalesTransaction.SalesTransactionItem")
   ```
3. Generate:
   ```
   [relation annotation if present]
   relation REL_ProductComponentGroup_<ID> : ProductClassification_<ID>[<MinBundleComponents>..<MaxBundleComponents>];
   ```
4. For each ProductRelatedComponent in the group, create ExpressionSetConstraintObj:
   - ReferenceObjectId: ProductRelatedComponent ID
   - ConstraintModelTag: `REL_ProductComponentGroup_<ID>`
   - ConstraintModelTagType: `Port`

**If Not Qualified**:
1. For each ProductRelatedComponent in the group:
   - Query `ChildProductId`, `MinQuantity`, `MaxQuantity`
   - Ensure child Product2 type exists
   - **For virtual Product2 parent types**, add sourceContextNode annotation
   - Generate individual ProductRelatedComponent relation
   - Create ExpressionSetConstraintObj (Port)

#### Type Closure
```
}

```

#### ExpressionSetConstraintObj for Type
Create a record for the type itself (unless it's a virtual Product2):
- ReferenceObjectId: The type's reference object ID (ProductClassification or Product2)
- ConstraintModelTag: The type name
- ConstraintModelTagType: `Type`

---

## Special Cases

### Virtual Product2 Types
Product2 records with an annotation snippet containing `@(virtual=true)`:
1. **Type Name**: Use clean Product2 name instead of `Product2_<ID>`
2. **Type Annotation**: Include the `@(virtual=true)` annotation
3. **Relation Annotations**: Add `@(sourceContextNode = "SalesTransaction.SalesTransactionItem")` to all relations
4. **ExpressionSetConstraintObj**: Skip creating the Type record (only create Port records for relations)

### Dynamic Type Creation
When processing relations, if a referenced Product2 or ProductClassification type doesn't exist:
1. Create the type with minimal information (name, reference ID)
2. Add to the type collection
3. Process it in the generation loop

### Cardinality Handling
- If `MinQuantity` is null, use `0`
- If `MaxQuantity` is null, use `*`
- If both are null, omit the cardinality brackets entirely

---

## Output

The final CML is written to the `ExpressionSetDefinitionVersion.ConstraintModel` BLOB field for the PCM_All ExpressionSet, and the ExpressionSetConstraintObj records are created to map CML elements to Salesforce records.
