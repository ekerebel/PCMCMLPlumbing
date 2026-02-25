public with sharing class ConstraintStudioController {
    
    @AuraEnabled(cacheable=true)
    public static List<CMLSnippet__c> getCMLSnippets(String recordId, String objectApiName, String searchTerm, String cacheBuster) {
        try {
            String query = 'SELECT Id, Name, Label__c, CML__c, Type__c FROM CMLSnippet__c WHERE Type__c = \'constraint\'';
            
            // Filter by parent record based on object type
            if (objectApiName == 'Product2') {
                query += ' AND ParentProduct2__c = :recordId';
            } else if (objectApiName == 'ProductClassification') {
                query += ' AND ParentProductClassification__c = :recordId';
            }
            
            // Add search filter if provided (ignore cacheBuster in search)
            String actualSearchTerm = searchTerm;
            if (String.isNotBlank(searchTerm) && searchTerm.contains('|')) {
                actualSearchTerm = searchTerm.substringBefore('|');
            }
            
            if (String.isNotBlank(actualSearchTerm)) {
                String searchPattern = '%' + actualSearchTerm + '%';
                query += ' AND (Label__c LIKE :searchPattern OR Name LIKE :searchPattern)';
            }
            
            query += ' ORDER BY Label__c ASC NULLS LAST, Name ASC';
            
            List<CMLSnippet__c> snippets = Database.query(query);
            
            // Transform Product2 IDs back to names for display
            for (CMLSnippet__c snippet : snippets) {
                if (String.isNotBlank(snippet.CML__c)) {
                    snippet.CML__c = transformProduct2IdsToNames(snippet.CML__c);
                }
            }
            
            return snippets;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching CML Snippets: ' + e.getMessage());
        }
    }
    
    /**
     * @description Transforms Product2 IDs in CML back to Product2 Names for display
     * @param cml The CML string containing Product2_<ID> references
     * @return String The CML with Product2 names instead of IDs
     */
    private static String transformProduct2IdsToNames(String cml) {
        // Pattern to match Product2_<ID>
        Pattern product2Pattern = Pattern.compile('Product2_([a-zA-Z0-9]{15,18})');
        Matcher matcher = product2Pattern.matcher(cml);
        
        // Collect all Product2 IDs
        Set<Id> product2Ids = new Set<Id>();
        while (matcher.find()) {
            try {
                product2Ids.add(matcher.group(1));
            } catch (Exception e) {
                // Invalid ID, skip
            }
        }
        
        if (product2Ids.isEmpty()) {
            return cml;
        }
        
        // Query Product2 names
        Map<Id, String> idToNameMap = new Map<Id, String>();
        for (Product2 p : [SELECT Id, Name FROM Product2 WHERE Id IN :product2Ids]) {
            String cleanName = p.Name.replaceAll('[^a-zA-Z0-9]', '_');
            idToNameMap.put(p.Id, cleanName);
        }
        
        // Replace IDs with names
        String result = cml;
        for (Id productId : idToNameMap.keySet()) {
            String productName = idToNameMap.get(productId);
            result = result.replaceAll('Product2_' + productId, productName);
        }
        
        return result;
    }
    
    @AuraEnabled
    public static void deleteCMLSnippet(String snippetId) {
        try {
            CMLSnippet__c snippet = [SELECT Id FROM CMLSnippet__c WHERE Id = :snippetId LIMIT 1];
            delete snippet;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting CML Snippet: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static CMLSnippet__c saveCMLSnippet(String snippetId, String label, String cml) {
        try {
            CMLSnippet__c snippet = [SELECT Id, Label__c, CML__c FROM CMLSnippet__c WHERE Id = :snippetId LIMIT 1];
            snippet.Label__c = label;
            snippet.CML__c = cml;
            update snippet;
            return snippet;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving CML Snippet: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static CMLSnippet__c createCMLSnippet(String recordId, String objectApiName, String keyword, String label) {
        try {
            CMLSnippet__c snippet = new CMLSnippet__c();
            snippet.Label__c = label;
            snippet.Type__c = 'constraint';
            snippet.Object__c = objectApiName;
            
            // Set the default CML based on keyword
            snippet.CML__c = keyword + '();';
            
            // Set the parent lookup based on object type
            if (objectApiName == 'Product2') {
                snippet.ParentProduct2__c = recordId;
            } else if (objectApiName == 'ProductClassification') {
                snippet.ParentProductClassification__c = recordId;
            }
            
            insert snippet;
            
            // Return the created snippet with all fields
            return [SELECT Id, Name, Label__c, CML__c, Type__c FROM CMLSnippet__c WHERE Id = :snippet.Id LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('Error creating CML Snippet: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAttributeDefinitions(String recordId, String objectApiName) {
        try {
            Set<String> attributeNames = new Set<String>();
            
            if (objectApiName == 'ProductClassification') {
                // Get ProductClassificationAttr related to the current ProductClassification
                List<ProductClassificationAttr> pcAttrs = [
                    SELECT AttributeDefinition.DeveloperName 
                    FROM ProductClassificationAttr 
                    WHERE ProductClassificationId = :recordId 
                    AND AttributeDefinition.DeveloperName != null
                ];
                
                for (ProductClassificationAttr pcAttr : pcAttrs) {
                    attributeNames.add(pcAttr.AttributeDefinition.DeveloperName);
                }
                
            } else if (objectApiName == 'Product2') {
                // Path #1: Get attributes via BasedOn ProductClassification
                Product2 product = [
                    SELECT BasedOnId 
                    FROM Product2 
                    WHERE Id = :recordId 
                    LIMIT 1
                ];
                
                if (product.BasedOnId != null) {
                    List<ProductClassificationAttr> pcAttrs = [
                        SELECT AttributeDefinition.DeveloperName 
                        FROM ProductClassificationAttr 
                        WHERE ProductClassificationId = :product.BasedOnId 
                        AND AttributeDefinition.DeveloperName != null
                    ];
                    
                    for (ProductClassificationAttr pcAttr : pcAttrs) {
                        attributeNames.add(pcAttr.AttributeDefinition.DeveloperName);
                    }
                }
                
                // Path #2: Get attributes via ProductAttributeDefinition
                List<ProductAttributeDefinition> padList = [
                    SELECT AttributeDefinitionId, AttributeDefinition.DeveloperName 
                    FROM ProductAttributeDefinition 
                    WHERE Product2Id = :recordId 
                    AND AttributeDefinition.DeveloperName != null
                ];
                
                for (ProductAttributeDefinition pad : padList) {
                    attributeNames.add(pad.AttributeDefinition.DeveloperName);
                }
            }
            
            // Convert to list with type and display name
            List<Map<String, String>> result = new List<Map<String, String>>();
            List<String> sortedNames = new List<String>(attributeNames);
            sortedNames.sort();
            
            for (String attrName : sortedNames) {
                result.add(new Map<String, String>{
                    'type' => 'Attribute',
                    'value' => attrName,
                    'displayName' => 'Attribute: ' + attrName,
                    'color' => 'blue'
                });
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching attribute definitions: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getProductComponentSuggestions(String recordId) {
        try {
            List<Map<String, String>> result = new List<Map<String, String>>();
            
            // Get all ProductComponentGroups for this Product2
            List<ProductComponentGroup> pcgList = [
                SELECT Id, Name, MaxBundleComponents
                FROM ProductComponentGroup
                WHERE ParentProductId = :recordId
            ];
            
            // Get all ProductRelatedComponents for these groups to check if they have children
            Set<Id> pcgIds = new Set<Id>();
            for (ProductComponentGroup pcg : pcgList) {
                pcgIds.add(pcg.Id);
            }
            
            List<ProductRelatedComponent> prcList = [
                SELECT Id, ProductComponentGroupId
                FROM ProductRelatedComponent
                WHERE ProductComponentGroupId IN :pcgIds
            ];
            
            // Group PRCs by PCG to check which groups have children
            Map<Id, List<ProductRelatedComponent>> prcByPcg = new Map<Id, List<ProductRelatedComponent>>();
            for (ProductRelatedComponent prc : prcList) {
                if (!prcByPcg.containsKey(prc.ProductComponentGroupId)) {
                    prcByPcg.put(prc.ProductComponentGroupId, new List<ProductRelatedComponent>());
                }
                prcByPcg.get(prc.ProductComponentGroupId).add(prc);
            }
            
            // Only add ProductComponentGroups (no individual Product2 records)
            for (ProductComponentGroup pcg : pcgList) {
                List<ProductRelatedComponent> relatedComponents = prcByPcg.get(pcg.Id);
                if (relatedComponents == null || relatedComponents.size() == 0) {
                    continue;
                }
                
                // Add ProductComponentGroup
                String cleanName = pcg.Name.replaceAll('[^a-zA-Z0-9]', '_');
                result.add(new Map<String, String>{
                    'type' => 'ProductComponentGroup',
                    'value' => 'REL_ProductComponentGroup_' + pcg.Id,
                    'displayName' => 'Product Component Group: ' + cleanName,
                    'actualName' => cleanName,
                    'color' => 'purple',
                    'recordId' => pcg.Id
                });
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching product component suggestions: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPicklistValues(String recordId, String objectApiName, String attributeName) {
        try {
            List<Map<String, String>> result = new List<Map<String, String>>();
            
            // Find the AttributeDefinition for this attribute
            List<AttributeDefinition> attrDefs = [
                SELECT Id, PicklistId
                FROM AttributeDefinition
                WHERE DeveloperName = :attributeName
                LIMIT 1
            ];
            
            if (attrDefs.isEmpty() || attrDefs[0].PicklistId == null) {
                return result; // No picklist found
            }
            
            Id picklistId = attrDefs[0].PicklistId;
            
            // Get picklist values
            List<AttributePicklistValue> picklistValues = [
                SELECT Id, Value
                FROM AttributePicklistValue
                WHERE PicklistId = :picklistId
                ORDER BY Value ASC
            ];
            
            for (AttributePicklistValue pv : picklistValues) {
                result.add(new Map<String, String>{
                    'type' => 'PicklistValue',
                    'value' => pv.Value,
                    'displayName' => pv.Value,
                    'color' => '#F59E0B' // Orange color for picklist values
                });
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching picklist values: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getContextualProducts(String contextId, String contextType) {
        try {
            List<Map<String, String>> result = new List<Map<String, String>>();
            
            if (contextType == 'ProductComponentGroup') {
                // Get all products for this ProductComponentGroup
                List<ProductRelatedComponent> prcList = [
                    SELECT Id, ChildProductId, ChildProduct.Name
                    FROM ProductRelatedComponent
                    WHERE ProductComponentGroupId = :contextId
                ];
                
                for (ProductRelatedComponent prc : prcList) {
                    String cleanName = prc.ChildProduct.Name.replaceAll('[^a-zA-Z0-9]', '_');
                    result.add(new Map<String, String>{
                        'type' => 'Product',
                        'value' => 'Product2_' + prc.ChildProductId,
                        'displayName' => 'Product: ' + cleanName,
                        'actualName' => cleanName,
                        'color' => 'green',
                        'recordId' => prc.ChildProductId
                    });
                }
                
            } else if (contextType == 'ProductRelatedComponent') {
                // Get the specific product for this ProductRelatedComponent
                ProductRelatedComponent prc = [
                    SELECT Id, ChildProductId, ChildProduct.Name
                    FROM ProductRelatedComponent
                    WHERE Id = :contextId
                    LIMIT 1
                ];
                
                String cleanName = prc.ChildProduct.Name.replaceAll('[^a-zA-Z0-9]', '_');
                result.add(new Map<String, String>{
                    'type' => 'Product',
                    'value' => 'Product2_' + prc.ChildProductId,
                    'displayName' => 'Product: ' + cleanName,
                    'actualName' => cleanName,
                    'color' => 'green',
                    'recordId' => prc.ChildProductId
                });
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching contextual products: ' + e.getMessage());
        }
    }
}
