/**
 * @description Controller class for CML Generator Lightning Web Component
 * Provides @AuraEnabled methods for UI interaction
 */
public with sharing class CMLGeneratorController {
    
    /**
     * @description Executes the CML generation process
     * @return String Success or error message
     */
    @AuraEnabled
    public static String generateCML() {
        try {
            String result = CMLGenerator.execute();
            return result;
        } catch (Exception e) {
            // Log the error
            System.debug(LoggingLevel.ERROR, 'CMLGeneratorController Error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
            
            // Throw AuraHandledException for proper LWC error handling
            throw new AuraHandledException('Error generating CML: ' + e.getMessage());
        }
    }
    
    /**
     * @description Checks if the PCM_All ExpressionSet exists
     * @return Boolean True if PCM_All exists
     */
    @AuraEnabled(cacheable=true)
    public static Boolean checkPCMAllExists() {
        try {
            List<ExpressionSetDefinition> expressionSets = [
                SELECT Id, DeveloperName
                FROM ExpressionSetDefinition
                WHERE DeveloperName = 'PCM_All'
                LIMIT 1
            ];
            return !expressionSets.isEmpty();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error checking PCM_All: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Gets count of CML Snippets available for processing
     * @return Integer Count of snippets
     */
    @AuraEnabled(cacheable=true)
    public static Integer getSnippetCount() {
        try {
            return [
                SELECT COUNT()
                FROM CMLSnippet__c
                WHERE Object__c = 'ProductClassificationAttr'
                AND Type__c = 'annotation'
                AND ParentProductClassificationAttr__c != null
            ];
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting snippet count: ' + e.getMessage());
            return 0;
        }
    }
}
