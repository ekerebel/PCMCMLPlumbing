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

Each "relation" is also an object that contains:
- an annotation section (string)
- a reference to another type
- cardinality min (integer)
- cardinality max (integer)

Now, we will start from the CML Snippets that have Object=='ProductClassificationAttr' and Type="annotation".
For each such snippet:
1- identify which product classification it is linked to (use ParentClassificationAttr__c which gives you the ProductClassificationAttr object. In that object, use the ProductClassification lookup field).
2- take that Product Classification and add it as a type in your array if not already present. The name of the type would be "ProductClassification_"+ProductClassification.Id.


At the very end, we will constitute the CML.
For each type in the array, add the following to the CML blob:

<type annotation>
type <typeName>{
    <for each constraint in the type's constraint array>
        <constraint's string>
    </end for each constraint in the type's constraint array>
}

Update the blob associated with the expression set. Refer to CML_Blob_Update.md for instructions.

