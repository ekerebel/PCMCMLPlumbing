public class QuoteLineCreator {
    
    /**
     * Adds a parent Quote Line with two child Quote Lines to an existing Quote
     * @param quoteId The existing Quote Id
     * @param parentProductId Product Id for the parent Quote Line
     * @param childProductId1 Product Id for the first child Quote Line
     * @param childProductId2 Product Id for the second child Quote Line
     * @return Id The Quote Id after successful execution
     */
    public static Id addQuoteLinesWithChildren(Id quoteId, Id parentProductId, Id childProductId1, Id childProductId2) {
        System.debug('=== QuoteLineCreator START ===');
        System.debug('Input - quoteId: ' + quoteId);
        System.debug('Input - parentProductId: ' + parentProductId);
        System.debug('Input - childProductId1: ' + childProductId1);
        System.debug('Input - childProductId2: ' + childProductId2);
        
        // 1. Query Standard Pricebook
        System.debug('--- Step 1: Querying Standard Pricebook ---');
        List<Pricebook2> standardPricebooks = [
            SELECT Id 
            FROM Pricebook2 
            WHERE IsStandard = true 
            LIMIT 1
        ];
        
        if (standardPricebooks.isEmpty()) {
            throw new QuoteLineCreatorException('Standard Pricebook not found');
        }
        
        Id standardPricebookId = standardPricebooks[0].Id;
        System.debug('Standard Pricebook ID: ' + standardPricebookId);
        
        // 2. Query PricebookEntries for all three products
        System.debug('--- Step 2: Querying PricebookEntries ---');
        List<Id> productIds = new List<Id>{parentProductId, childProductId1, childProductId2};
        
        List<PricebookEntry> pbes = [
            SELECT Id, Product2Id 
            FROM PricebookEntry 
            WHERE Product2Id IN :productIds 
            AND Pricebook2Id = :standardPricebookId
        ];
        System.debug('Found ' + pbes.size() + ' PricebookEntries');
        
        // Build map of Product2Id to PricebookEntryId
        Map<Id, Id> productToPbeMap = new Map<Id, Id>();
        for (PricebookEntry pbe : pbes) {
            productToPbeMap.put(pbe.Product2Id, pbe.Id);
            System.debug('Mapped Product2Id ' + pbe.Product2Id + ' -> PBE Id ' + pbe.Id);
        }
        
        // Validate all three products have PricebookEntries
        System.debug('--- Step 3: Validating PricebookEntries ---');
        if (!productToPbeMap.containsKey(parentProductId)) {
            System.debug('ERROR: PricebookEntry not found for parent product: ' + parentProductId);
            throw new QuoteLineCreatorException('PricebookEntry not found for parent product: ' + parentProductId);
        }
        System.debug('✓ Parent Product PBE found: ' + productToPbeMap.get(parentProductId));
        
        if (!productToPbeMap.containsKey(childProductId1)) {
            System.debug('ERROR: PricebookEntry not found for child product 1: ' + childProductId1);
            throw new QuoteLineCreatorException('PricebookEntry not found for child product 1: ' + childProductId1);
        }
        System.debug('✓ Child1 Product PBE found: ' + productToPbeMap.get(childProductId1));
        
        if (!productToPbeMap.containsKey(childProductId2)) {
            System.debug('ERROR: PricebookEntry not found for child product 2: ' + childProductId2);
            throw new QuoteLineCreatorException('PricebookEntry not found for child product 2: ' + childProductId2);
        }
        System.debug('✓ Child2 Product PBE found: ' + productToPbeMap.get(childProductId2));
        
        // 3. Query default ProductRelationshipType
        System.debug('--- Step 4: Querying ProductRelationshipType ---');
        List<ProductRelationshipType> relationshipTypes = [
            SELECT Id 
            FROM ProductRelationshipType 
            LIMIT 1
        ];
        
        if (relationshipTypes.isEmpty()) {
            throw new QuoteLineCreatorException('ProductRelationshipType not found');
        }
        
        Id relationshipTypeId = relationshipTypes[0].Id;
        System.debug('ProductRelationshipType ID: ' + relationshipTypeId);
        
        // 4. Build PlaceQuote Graph Request
        System.debug('--- Step 5: Building PlaceQuote Graph ---');
        List<PlaceQuote.RecordWithReferenceRequest> listOfRecords = new List<PlaceQuote.RecordWithReferenceRequest>();
        
        // Add the Quote record to the graph (required by PlaceQuote API)
        // For PATCH operations, use the 3-parameter constructor with the record ID
        PlaceQuote.RecordResource quoteRecord = new PlaceQuote.RecordResource(Quote.getSobjectType(), 'PATCH', quoteId);
        Map<String, Object> quoteFieldValues = new Map<String, Object>();
        quoteRecord.fieldValues = quoteFieldValues;
        
        PlaceQuote.RecordWithReferenceRequest quoteRequest = new PlaceQuote.RecordWithReferenceRequest('refQuote', quoteRecord);
        listOfRecords.add(quoteRequest);
        System.debug('Added Quote to graph with ID: ' + quoteId);
        
        // Create parent QuoteLineItem
        PlaceQuote.RecordResource parentQuoteLineRecord = new PlaceQuote.RecordResource(QuoteLineItem.getSobjectType(), 'POST');
        Map<String, Object> parentFieldValues = new Map<String, Object>();
        parentFieldValues.put('QuoteId', '@{refQuote.id}');  // Reference the Quote from the graph
        parentFieldValues.put('Product2Id', parentProductId);
        parentFieldValues.put('PricebookEntryId', productToPbeMap.get(parentProductId));
        parentFieldValues.put('Quantity', '1');
        parentFieldValues.put('StartDate', '2026-01-01');
        parentFieldValues.put('EndDate', '2026-12-31');
        parentQuoteLineRecord.fieldValues = parentFieldValues;
        
        PlaceQuote.RecordWithReferenceRequest parentQuoteLineRequest = new PlaceQuote.RecordWithReferenceRequest('refParentQuoteLine', parentQuoteLineRecord);
        listOfRecords.add(parentQuoteLineRequest);
        System.debug('Added parent QuoteLine to graph');
        
        // Create first child QuoteLineItem
        PlaceQuote.RecordResource child1QuoteLineRecord = new PlaceQuote.RecordResource(QuoteLineItem.getSobjectType(), 'POST');
        Map<String, Object> child1FieldValues = new Map<String, Object>();
        child1FieldValues.put('QuoteId', '@{refQuote.id}');  // Reference the Quote from the graph
        child1FieldValues.put('Product2Id', childProductId1);
        child1FieldValues.put('PricebookEntryId', productToPbeMap.get(childProductId1));
        child1FieldValues.put('Quantity', '1');
        child1FieldValues.put('StartDate', '2026-01-01');
        child1FieldValues.put('EndDate', '2026-12-31');
        child1QuoteLineRecord.fieldValues = child1FieldValues;
        
        PlaceQuote.RecordWithReferenceRequest child1QuoteLineRequest = new PlaceQuote.RecordWithReferenceRequest('refChild1QuoteLine', child1QuoteLineRecord);
        listOfRecords.add(child1QuoteLineRequest);
        System.debug('Added child1 QuoteLine to graph');
        
        // Create second child QuoteLineItem
        PlaceQuote.RecordResource child2QuoteLineRecord = new PlaceQuote.RecordResource(QuoteLineItem.getSobjectType(), 'POST');
        Map<String, Object> child2FieldValues = new Map<String, Object>();
        child2FieldValues.put('QuoteId', '@{refQuote.id}');  // Reference the Quote from the graph
        child2FieldValues.put('Product2Id', childProductId2);
        child2FieldValues.put('PricebookEntryId', productToPbeMap.get(childProductId2));
        child2FieldValues.put('Quantity', '1');
        child2FieldValues.put('StartDate', '2026-01-01');
        child2FieldValues.put('EndDate', '2026-12-31');
        child2QuoteLineRecord.fieldValues = child2FieldValues;
        
        PlaceQuote.RecordWithReferenceRequest child2QuoteLineRequest = new PlaceQuote.RecordWithReferenceRequest('refChild2QuoteLine', child2QuoteLineRecord);
        listOfRecords.add(child2QuoteLineRequest);
        System.debug('Added child2 QuoteLine to graph');
        
        // Create first QuoteLineRelationship (parent to child1)
        PlaceQuote.RecordResource qlr1Record = new PlaceQuote.RecordResource(QuoteLineRelationship.getSobjectType(), 'POST');
        Map<String, Object> qlr1Fields = new Map<String, Object>();
        qlr1Fields.put('ProductRelationshipTypeId', relationshipTypeId);
        qlr1Fields.put('MainQuoteLineId', '@{refParentQuoteLine.id}');
        qlr1Fields.put('AssociatedQuoteLineId', '@{refChild1QuoteLine.id}');
        qlr1Fields.put('AssociatedQuoteLinePricing', 'IncludedInBundlePrice');
        //qlr1Fields.put('ProductRelatedComponentId', '0dSgh00000000AiEAI');
        qlr1Record.fieldValues = qlr1Fields;
        
        PlaceQuote.RecordWithReferenceRequest qlr1Request = new PlaceQuote.RecordWithReferenceRequest('refQLR1', qlr1Record);
        listOfRecords.add(qlr1Request);
        System.debug('Added QuoteLineRelationship 1 to graph');
        
        // Create second QuoteLineRelationship (parent to child2)
        PlaceQuote.RecordResource qlr2Record = new PlaceQuote.RecordResource(QuoteLineRelationship.getSobjectType(), 'POST');
        Map<String, Object> qlr2Fields = new Map<String, Object>();
        qlr2Fields.put('ProductRelationshipTypeId', relationshipTypeId);
        qlr2Fields.put('MainQuoteLineId', '@{refParentQuoteLine.id}');
        qlr2Fields.put('AssociatedQuoteLineId', '@{refChild2QuoteLine.id}');
        qlr2Fields.put('AssociatedQuoteLinePricing', 'IncludedInBundlePrice');
        qlr2Record.fieldValues = qlr2Fields;
        
        PlaceQuote.RecordWithReferenceRequest qlr2Request = new PlaceQuote.RecordWithReferenceRequest('refQLR2', qlr2Record);
        listOfRecords.add(qlr2Request);
        System.debug('Added QuoteLineRelationship 2 to graph');
        
        // 5. Execute PlaceQuote
        System.debug('--- Step 6: Executing PlaceQuote API ---');
        System.debug('Total records in graph: ' + listOfRecords.size());
        PlaceQuote.GraphRequest graph = new PlaceQuote.GraphRequest('addQuoteLines', listOfRecords);
        
        PlaceQuote.ConfigurationOptionsInput configOptions = new PlaceQuote.ConfigurationOptionsInput();
        configOptions.validateProductCatalog = false;
        configOptions.validateAmendRenewCancel = false;
        configOptions.executeConfigurationRules = false;
        configOptions.addDefaultConfiguration = false;
        
        PlaceQuote.PlaceQuoteResponse response = PlaceQuote.PlaceQuoteRLMApexProcessor.execute(
            PlaceQuote.PricingPreferenceEnum.System,
            graph,
            PlaceQuote.ConfigurationInputEnum.Skip,
            configOptions
        );
        System.debug('PlaceQuote execution complete');
        System.debug('Response: ' + response);
        
        // 6. Return Quote Id
        System.debug('--- Step 7: Processing Response ---');
        if (response != null && response.quoteId != null) {
            System.debug('SUCCESS! Returning Quote ID: ' + response.quoteId);
            System.debug('=== QuoteLineCreator END ===');
            return response.quoteId;
        } else {
            System.debug('ERROR: PlaceQuote execution failed');
            System.debug('Response details: ' + response);
            throw new QuoteLineCreatorException('PlaceQuote execution failed: ' + response);
        }
    }
    
    /**
     * Custom exception class for QuoteLineCreator errors
     */
    public class QuoteLineCreatorException extends Exception {}
}