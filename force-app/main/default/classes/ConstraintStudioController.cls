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
            
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching CML Snippets: ' + e.getMessage());
        }
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
    public static List<String> getAttributeDefinitions(String recordId, String objectApiName) {
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
            
            // Convert to sorted list
            List<String> result = new List<String>(attributeNames);
            result.sort();
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching attribute definitions: ' + e.getMessage());
        }
    }
}
