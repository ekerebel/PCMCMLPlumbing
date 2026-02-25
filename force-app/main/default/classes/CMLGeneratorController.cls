/**
 * @description Controller class for CML Generator Lightning Web Component
 * Provides @AuraEnabled methods for UI interaction
 */
public with sharing class CMLGeneratorController {
    
    /**
     * @description Executes the CML generation process using Queueable
     * This avoids session ID issues by running in a system context
     * @return String Success message with job ID
     */
    @AuraEnabled
    public static String generateCML() {
        try {
            // Enqueue the job to run in system context
            Id jobId = CMLGeneratorQueueable.enqueue();
            
            return 'CML deployment job started successfully. Job ID: ' + jobId + 
                   '. Check the debug logs for results.';
        } catch (Exception e) {
            // Log the error
            System.debug(LoggingLevel.ERROR, 'CMLGeneratorController Error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
            
            // Throw AuraHandledException for proper LWC error handling
            throw new AuraHandledException('Error starting CML generation: ' + e.getMessage());
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
     * @description Gets count of ALL CML Snippets available for processing
     * @return Integer Count of snippets
     */
    @AuraEnabled(cacheable=true)
    public static Integer getSnippetCount() {
        try {
            return [
                SELECT COUNT()
                FROM CMLSnippet__c
            ];
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting snippet count: ' + e.getMessage());
            return 0;
        }
    }
}
