public with sharing class ConstraintStudioController {
    
    @AuraEnabled(cacheable=true)
    public static List<CMLSnippet__c> getCMLSnippets(String recordId, String objectApiName, String searchTerm) {
        try {
            String query = 'SELECT Id, Name, Label__c, CML__c, Type__c FROM CMLSnippet__c WHERE Type__c = \'constraint\'';
            
            // Filter by parent record based on object type
            if (objectApiName == 'Product2') {
                query += ' AND ParentProduct2__c = :recordId';
            } else if (objectApiName == 'ProductClassification') {
                query += ' AND ParentProductClassification__c = :recordId';
            }
            
            // Add search filter if provided
            if (String.isNotBlank(searchTerm)) {
                String searchPattern = '%' + searchTerm + '%';
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
}
