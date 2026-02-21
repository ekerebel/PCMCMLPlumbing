/**
 * @description Generates CML (Constraint Modeling Language) from CMLSnippet records
 * and updates the PCM_All ExpressionSet BLOB.
 * 
 * SAFETY: This class ONLY works with the 'PCM_All' ExpressionSet to prevent
 * accidental modification of other constraint models.
 */
public with sharing class CMLGenerator {
    
    // SAFETY: Hard-coded allowed ExpressionSet name
    private static final String ALLOWED_EXPRESSION_SET = 'PCM_All';
    private static final String API_VERSION = 'v65.0';
    
    /**
     * @description Inner class representing a CML Type
     */
    public class CMLTypeWrapper {
        public String typeName;
        public String annotation;
        public List<CMLRelation> relations;
        public List<String> constraints;
        
        public CMLTypeWrapper() {
            this.relations = new List<CMLRelation>();
            this.constraints = new List<String>();
        }
    }
    
    /**
     * @description Inner class representing a relation between types
     */
    public class CMLRelation {
        public String annotation;
        public String referenceType;
        public Integer cardinalityMin;
        public Integer cardinalityMax;
    }
    
    /**
     * @description Custom exception for CML Generator errors
     */
    public class CMLGeneratorException extends Exception {}
    
    /**
     * @description Main execution method - orchestrates the entire CML generation process
     * @return String Success message
     */
    public static String execute() {
        try {
            System.debug('=== CML Generator Started ===');
            
            // Step 1: Find the PCM_All ExpressionSet
            ExpressionSetDefinitionVersion esdv = findPCMAllExpressionSet();
            System.debug('Found ExpressionSet: ' + esdv.ExpressionSetDefinition.DeveloperName);
            
            // Step 2: Read current BLOB content
            String currentBlob = readBlobContent(esdv);
            System.debug('Current BLOB size: ' + (currentBlob != null ? currentBlob.length() : 0) + ' characters');
            
            // Step 3: Process CML Snippets and build type array
            Map<Id, CMLTypeWrapper> typeMap = processSnippets();
            System.debug('Processed ' + typeMap.size() + ' types from snippets');
            
            // Step 4: Generate CML string
            String cmlContent = generateCML(typeMap);
            System.debug('Generated CML size: ' + cmlContent.length() + ' characters');
            System.debug('Generated CML:\n' + cmlContent);
            
            // Step 5: Update BLOB with generated CML
            updateBlob(esdv, cmlContent);
            System.debug('BLOB updated successfully');
            
            System.debug('=== CML Generator Completed Successfully ===');
            return 'CML generated and updated successfully for ' + typeMap.size() + ' types.';
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CML Generator Error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
            throw new CMLGeneratorException('Failed to generate CML: ' + e.getMessage());
        }
    }
    
    /**
     * @description Finds the PCM_All ExpressionSet with safety validation
     * @return ExpressionSetDefinitionVersion The latest version of PCM_All
     */
    private static ExpressionSetDefinitionVersion findPCMAllExpressionSet() {
        List<ExpressionSetDefinitionVersion> versions = [
            SELECT Id, ConstraintModel, VersionNumber,
                   ExpressionSetDefinition.DeveloperName,
                   ExpressionSetDefinition.Id
            FROM ExpressionSetDefinitionVersion
            WHERE ExpressionSetDefinition.DeveloperName = :ALLOWED_EXPRESSION_SET
            ORDER BY VersionNumber DESC
            LIMIT 1
        ];
        
        if (versions.isEmpty()) {
            throw new CMLGeneratorException(
                'ExpressionSet "' + ALLOWED_EXPRESSION_SET + '" not found. ' +
                'Please ensure it exists in your org.'
            );
        }
        
        ExpressionSetDefinitionVersion esdv = versions[0];
        
        // SAFETY: Double-check we're working with the correct ExpressionSet
        validateExpressionSet(esdv.ExpressionSetDefinition.DeveloperName);
        
        return esdv;
    }
    
    /**
     * @description Safety validation to ensure we only work with PCM_All
     * @param developerName The DeveloperName to validate
     */
    private static void validateExpressionSet(String developerName) {
        if (developerName != ALLOWED_EXPRESSION_SET) {
            throw new CMLGeneratorException(
                'SAFETY CHECK FAILED: This tool can only be used with the "' + 
                ALLOWED_EXPRESSION_SET + '" ExpressionSet. ' +
                'Attempted to use: ' + developerName
            );
        }
    }
    
    /**
     * @description Reads the current BLOB content via HTTP callout
     * @param esdv The ExpressionSetDefinitionVersion record
     * @return String The current BLOB content
     */
    private static String readBlobContent(ExpressionSetDefinitionVersion esdv) {
        // Construct the BLOB URL manually since ConstraintModel returns a Blob object
        String blobUrl = '/services/data/' + API_VERSION + '/sobjects/ExpressionSetDefinitionVersion/' + 
                         esdv.Id + '/ConstraintModel';
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        String fullUrl = instanceUrl + blobUrl;
        
        System.debug('Reading BLOB from: ' + fullUrl);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(fullUrl);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/octet-stream');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            return res.getBody();
        } else {
            throw new CMLGeneratorException(
                'Failed to read BLOB. Status: ' + res.getStatusCode() + 
                ', Body: ' + res.getBody()
            );
        }
    }
    
    /**
     * @description Processes CML Snippets and builds the type map
     * Currently processes ProductClassificationAttr annotations
     * @return Map<Id, CMLTypeWrapper> Map of ProductClassification IDs to types
     */
    private static Map<Id, CMLTypeWrapper> processSnippets() {
        Map<Id, CMLTypeWrapper> typeMap = new Map<Id, CMLTypeWrapper>();
        
        // Query CML Snippets for ProductClassificationAttr annotations
        List<CMLSnippet__c> snippets = [
            SELECT Id, CML__c, Type__c, Object__c,
                   ParentProductClassificationAttr__c,
                   ParentProductClassificationAttr__r.ProductClassificationId
            FROM CMLSnippet__c
            WHERE Object__c = 'ProductClassificationAttr'
            AND Type__c = 'annotation'
            AND ParentProductClassificationAttr__c != null
        ];
        
        System.debug('Found ' + snippets.size() + ' ProductClassificationAttr annotation snippets');
        
        for (CMLSnippet__c snippet : snippets) {
            // Get the ProductClassification ID
            Id classificationId = snippet.ParentProductClassificationAttr__r.ProductClassificationId;
            
            if (classificationId == null) {
                System.debug('Warning: Snippet ' + snippet.Id + ' has no ProductClassification');
                continue;
            }
            
            // Create or get the type
            if (!typeMap.containsKey(classificationId)) {
                CMLTypeWrapper type = new CMLTypeWrapper();
                type.typeName = 'ProductClassification_' + classificationId;
                type.annotation = snippet.CML__c;
                typeMap.put(classificationId, type);
                
                System.debug('Created type: ' + type.typeName);
            } else {
                // If type already exists, append annotation
                CMLTypeWrapper existingType = typeMap.get(classificationId);
                if (String.isNotBlank(snippet.CML__c)) {
                    existingType.annotation += '\n' + snippet.CML__c;
                }
            }
        }
        
        return typeMap;
    }
    
    /**
     * @description Generates the CML string from the type map
     * @param typeMap Map of types to generate CML from
     * @return String The complete CML content
     */
    private static String generateCML(Map<Id, CMLTypeWrapper> typeMap) {
        if (typeMap.isEmpty()) {
            System.debug('Warning: No types to generate CML from');
            return '// No CML types generated\n';
        }
        
        String cml = '';
        
        for (CMLTypeWrapper type : typeMap.values()) {
            // Add annotation if present
            if (String.isNotBlank(type.annotation)) {
                cml += type.annotation + '\n';
            }
            
            // Add type definition
            cml += 'type ' + type.typeName + ' {\n';
            
            // Add constraints
            for (String constraint : type.constraints) {
                cml += '    ' + constraint + '\n';
            }
            
            cml += '}\n\n';
        }
        
        return cml;
    }
    
    /**
     * @description Updates the BLOB content via Composite API
     * @param esdv The ExpressionSetDefinitionVersion record
     * @param cmlContent The CML content to write
     */
    private static void updateBlob(ExpressionSetDefinitionVersion esdv, String cmlContent) {
        // SAFETY: Final validation before update
        validateExpressionSet(esdv.ExpressionSetDefinition.DeveloperName);
        
        // Use Composite API with SObject Collections to update
        String compositeUrl = '/services/data/' + API_VERSION + '/composite/sobjects';
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        String fullUrl = instanceUrl + compositeUrl;
        
        System.debug('Updating via Composite API at: ' + fullUrl);
        
        // Create JSON payload with base64 encoded BLOB
        String base64Blob = EncodingUtil.base64Encode(Blob.valueOf(cmlContent));
        
        // Escape any quotes in the base64 string
        base64Blob = base64Blob.replace('"', '\\"');
        
        String jsonBody = '{' +
            '"allOrNone": false,' +
            '"records": [{' +
                '"attributes": {"type": "ExpressionSetDefinitionVersion"},' +
                '"Id": "' + esdv.Id + '",' +
                '"ConstraintModel": "' + base64Blob + '"' +
            '}]' +
        '}';
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(fullUrl);
        req.setMethod('PATCH');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');
        req.setBody(jsonBody);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Response Status: ' + res.getStatusCode());
        System.debug('Response Body: ' + res.getBody());
        
        if (res.getStatusCode() != 200) {
            throw new CMLGeneratorException(
                'Failed to update via Composite API. Status: ' + res.getStatusCode() + 
                ', Body: ' + res.getBody()
            );
        }
        
        // Check for errors in the response
        if (res.getBody().contains('"success":false')) {
            throw new CMLGeneratorException(
                'Composite API returned errors: ' + res.getBody()
            );
        }
        
        System.debug('BLOB updated successfully via Composite API');
    }
}
