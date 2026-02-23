The goal is to automatically populate a CML (from an existing ExpressionSetVersion).
Let's build an apex class that does this on demand (let's add a button in the Product Catalog Management App if we can)
1- search for an ExpressionSet with API Name='PCM_All'.
2- Get its blob (remember what we talked about earlier).
3- Update its blob (empty it for now).

Then, we will gradually build a CML file based on all of our CML Snippets.
We will need to keep in memory an array of objects called "type" that contains:
- a type name
- an annotation section (String)
- an array of "relations"
- an array of "constraints" (strings)
- an array of "attributes"
- an Id, which is the Id of the Product2 or the ProductClassification

Each "relation" is also an object that contains:
- an annotation section (string)
- a reference to another type
- an object type (ProductComponentGroup or ProductRelatedComponent)
- an object id

Each "attribute" can have:
- a name
- The Id of the AttributeDefinition (get it via a lookup from the ProductClassificationAttr or the ProductAttributeDefinition that is linked to the CML Snippet.)
- the Id of the ProductClassificationAttr or the ProductAttributeDefinition
- an annotation section (String)
- a domain (String)




========================================================================

-------------------------------------------------------------------------
CMLSnippets: Object=='ProductClassificationAttr' and Type="annotation"
-------------------------------------------------------------------------
For each such snippet:
1- identify which product classification it is linked to (use ParentClassificationAttr__c which gives you the ProductClassificationAttr object. In that object, use the ProductClassification lookup field).
2- take that Product Classification and add it as a type in your array if not already present. The name of the type would be "ProductClassification_"+ProductClassification.Id.
(Note): we do not take the annotations of the ProductClassificationAttr just yet
3- Not, if not already there, add an attribute element to the array, and inform its annotation section based the CML in the CML Snippet

-------------------------------------------------------------------------
CMLSnippets: Object=='ProductClassification' and Type="constraint"
-------------------------------------------------------------------------
For each such snippet:
1- identify which product classification it is linked to (use ParentProductClassificationAttr__c which gives you the ProductClassificationAttr object. In that object, use the ProductClassification lookup field).
2- take that Product Classification and add it as a type in your array if not already present. The name of the type would be "ProductClassification_"+ProductClassification.Id.
3- Add the CML Snippet to the constraint array for that type
4- parse the constraint and identify attributes being mentioned. In order to do that, extract the ProductClassificationAttr records that are linked to the ProductClassification (see lookup ProductClassificationId), and get the AttributeDefinition's ApiName (use AttributeDefinitionId to get the AttributeDefinition). Then see if that attribute is referenced in the CML Snipped. If it is, we add it to the type's attributes array
If the attribute referenced is already present in the type's attribute array, ignore, if not, add it (like for the previous CML Snippet paragraph above)


[TO DO] Need to account for overrides as well

-------------------------------------------------------------------------
CMLSnippets: Object=='Product2' and Type="constraint"
-------------------------------------------------------------------------
For each such snippet:
1- identify which product2 it is linked to (use ParentProduct2__c which gives you the Product2 object. In that object, use the ParentProduct2__c lookup field).
2- take that Product Classification and add it as a type in your array if not already present. The name of the type would be "ParentProduct2__c"+ParentProduct2__c.Id.
3- Add the CML Snippet to the constraint array for that type
4- parse the constraint and identify attributes being mentioned. In order to do that, extract the ProductAttributeDefinition records that are linked to the Product2 (see lookup Product2Id), and get the AttributeDefinition's ApiName (use AttributeDefinitionId to get the AttributeDefinition). Then see if that attribute is referenced in the CML Snippet. If it is, we add it to the type's attributes array
If the attribute referenced is already present in the type's attribute array, ignore, if not, add it (like for the previous CML Snippet paragraph above)
5- Get the Product2 record's Product Classification (Product2Id lookup field) and get the attributes of the class. Check their presence in the current CMNL Snipped and if they are, add them to the current type's attributes array as well
6- Parse the constraint and detect ProductComponentGroups being mentioned.
They would look like: ProductComponentGroup_<ProductComponentGroup Id>
With that, add the ProductComponentGroup as a relation array entry for the type detected. Relation's object type is ProductComponentGroup
Relation's object id is the ProductComponentGroup id
6- Parse the constraint and detect ProductRelatedComponent being mentioned.
They would look like: ProductRelatedComponent_<ProductRelatedComponent Id>
With that, add the ProductRelatedComponent as a relation array entry for the type detected
Relation's object type is ProductRelatedComponent
Relation's object id is the ProductRelatedComponent id

[TO DO] Need to account for overrides as well

========================================================================
At the very end, we will constitute the CML.

As a start, delete the rows of ExpressionSetConstraintObj for the ExpressionSetId of our CML. IMPORTANT: Only for the PCM_All ExpressionSet.

For each type in the array, add the following to the CML blob:

<type annotation>
type <typeName>{ //Note: when creating a type for a Product2, check its ProductClassification (lookup BasedOn in Product2). Always add " : ProductClassification_<ProductClassification's Id> after <typeName>. Also, ensure that there is already a type for the ProductClassification and if not, add it.
    <for each constraint in the type's constraint array>
        <constraint's string>
    </end for each constraint in the type's constraint array>
    <for each attribute in the type's attribute's array>
        
        get the attribute's developer name. Find this in the AttributeDefinition object, DeveloperName.
        get the Data Type from the Attribute Definition.
        add "decimal(2)" if Data Type is number, "string" in all the other cases.
        After that, add a space, the attribute's name
        If the attribute has an associated picklist, we need to prepare the domain. More on that later. If not, just end the line with ";"
        In order to create the domain, start from the AttributeDefinition, get the related picklist (lookup PicklistId), and extract all values. Get all the "Name" values from the AttributePicklistValue table. If there is a default value (Default field is checked), keep track of that.
        Now, we may need to exclude some values. Associated to the ProductClassificationAttr or the ProductAttributeDefinition (we should have one or the other id), we will find a related list of AttrPicklistExcludedValue.
        If we find records here, exclude them from the list prepared above.
        Also, in the ProductClassificationAttr or the ProductAttributeDefinition, we may have a DefaultValue informed. If we do, get it, this overrides the one above.
        Finaly, append after the name of the attribute '= ["value1", "value2", ...];'
        
        add <Annotaton's string> (before the name of the attribute).
        Now if we do have an annotation string already (example: @(domainComputation = "true", sequence = 6))and we also have a DefaultValue, append it to the annotation (in our example: @(defaultValue = "Hydrogen (H2)", domainComputation = "true", sequence = 6)).
        If there was not annotation, add it with the default: @(defaultValue = "Hydrogen (H2)")

    </end for each attribute in the type's attribute's array>
    <for each relation in the type's relation array>
        if the relation's object type is ProductRelatedComponent:
            - retrieve the cardinality of that ProductRelatedComponent (query its table ProductRelatedComponent, MinQuantity, MaxQuantity)
            - append to the CML blob, within the current type's section: 
                <Relation's annotation if any>
                relation Rel_ProductRelatedComponent_<ProductRelatedComponent> : Product2_<Product2 Id>[<MinQuantity..MaxQuantity>]; (If MinQuantity and MaxQuantity are empty, remove the [])
                Note: if there is not already a type for the Product2 referenced, we need to add one
            - Add a record to ExpressionSetConstraintObj:
                Name: let auto-number
                ExpressionSetId: the one for our PCM_All Expression set)
                ExpressionSet.ApiName: PCM_All
                ReferenceObjectId: <ProductRelatedComponent id>
                ConstraintModelTag: <Rel_ProductRelatedComponent_<ProductRelatedComponent>
                ConstraintModelTagType: Port
            - if not already added, add a type in the CML for Product2 related to the ProductRelatedComponent (to treat after)
        if the relation's object type is ProductComponentGroup:
            - check ProductComponentGroup MinBundleComponents and MaxBundleComponents fields.
                - if MaxBundleComponents = 1 and all the ProductRelatedComponent related to ProductComponentGroup (lookup field on ProductRelatedComponent) are Product2 records (ChildProductId not null) and all the Product2 records based on the same Product Classification (BasedOnId is the same in the Product2 table):
                    - append to the CML blob, within the current type's section: 
                    <Relation's annotation if any>
                    relation Rel_ProductComponentGroup_<ProductComponentGroup> : ProductClassification_<ProductClassification id of the product2 records identified above>[<MinBundleComponents..MaxBundleComponents>]; (If MinQuantity is empty, make it 0)
                    - For every ProductRelatedComponent looking up to the ProductComponentGroup:
                        - Add a record to ExpressionSetConstraintObj:
                            Name: let auto-number
                            ExpressionSetId: the one for our PCM_All Expression set)
                            ExpressionSet.ApiName: PCM_All
                            ReferenceObjectId: <ProductRelatedComponent id>
                            ConstraintModelTag: <Type's name>.Rel_ProductComponentGroup_<ProductComponentGroup>
                            COnstraintModelTagType: Port
                        - if not already added, add a type in the CML for Product2 related to the ProductRelatedComponent (to treat after)
            
                - else:
                    - For every ProductRelatedComponent looking up to the ProductComponentGroup:
                        - retrieve the cardinality of that ProductRelatedComponent (query its table ProductRelatedComponent, MinQuantity, MaxQuantity)
                        - append to the CML blob, within the current type's section: 
                            <Relation's annotation if any>
                            relation Rel_ProductRelatedComponent_<ProductRelatedComponent> : ProductRelatedComponent_<ProductRelatedComponent>[<MinQuantity..MaxQuantity>]; (If MinQuantity and MaxQuantity are empty, remove the [])
                        - Add a record to ExpressionSetConstraintObj:
                            Name: let auto-number
                            ExpressionSetId: the one for our PCM_All Expression set)
                            ExpressionSet.ApiName: PCM_All
                            ReferenceObjectId: <ProductRelatedComponent id>
                            ConstraintModelTag: <Type's name>.<Rel_ProductRelatedComponent_<ProductRelatedComponent>
                            COnstraintModelTagType: Port
                        - if not already added, add a type in the CML for Product2 related to the ProductRelatedComponent (to treat after)

    </end for each relation in the type's constraint array>
}
Also, for each type that gets created, we need to add a row in ExpressionSetConstraintObj
Name: let auto-number
ExpressionSetId: the one for our PCM_All Expression set)
ExpressionSet.ApiName: PCM_All
ReferenceObjectId: The type's Id (should be in our array)
ConstraintModelTag: the Type's Name
COnstraintModelTagType: Type

Update the blob associated with the expression set. Refer to CML_Blob_Update.md for instructions.

