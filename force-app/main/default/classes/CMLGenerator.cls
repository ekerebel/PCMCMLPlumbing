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
        public List<CMLAttribute> attributes;
        public Id referenceObjectId; // ProductClassification or Product2 ID
        
        public CMLTypeWrapper() {
            this.relations = new List<CMLRelation>();
            this.constraints = new List<String>();
            this.attributes = new List<CMLAttribute>();
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
     * @description Inner class representing an attribute
     */
    public class CMLAttribute {
        public String name;
        public String annotation;
        public String domain;
        public Id attributeDefinitionId; // AttributeDefinition ID
        public Id productClassificationAttrId; // ProductClassificationAttr or ProductAttributeDefinition ID
        public Id picklistId; // Picklist ID if applicable
        public String defaultValue; // Default value from ProductClassificationAttr or picklist
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
            
            // Step 2: Get the ExpressionSet ID (query only, no DML)
            Id expressionSetId = getExpressionSetId(esdv.ExpressionSetDefinition.Id);
            
            // Step 3: Process CML Snippets and build type array (query only, no DML)
            Map<Id, CMLTypeWrapper> typeMap = processSnippets();
            System.debug('Processed ' + typeMap.size() + ' types from snippets');
            
            // Step 4: Generate CML string (in-memory only)
            String cmlContent = generateCML(typeMap);
            System.debug('Generated CML size: ' + cmlContent.length() + ' characters');
            System.debug('Generated CML:\n' + cmlContent);
            
            // Step 5: Read current BLOB content (HTTP callout - BEFORE any DML)
            String currentBlob = readBlobContent(esdv);
            System.debug('Current BLOB size: ' + (currentBlob != null ? currentBlob.length() : 0) + ' characters');
            
            // Step 6: Update BLOB with generated CML (HTTP callout - BEFORE any DML)
            updateBlob(esdv, cmlContent);
            System.debug('BLOB updated successfully');
            
            // Step 7: Delete existing ExpressionSetConstraintObj records for PCM_All (DML)
            deleteExpressionSetConstraintObjs(expressionSetId);
            
            // Step 8: Create ExpressionSetConstraintObj records for each type (DML)
            createExpressionSetConstraintObjs(expressionSetId, typeMap);
            
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
                   ParentProductClassificationAttr__r.ProductClassificationId,
                   ParentProductClassificationAttr__r.AttributeDefinitionId,
                   ParentProductClassificationAttr__r.AttributeDefinition.DeveloperName,
                   ParentProductClassificationAttr__r.AttributeDefinition.DataType,
                   ParentProductClassificationAttr__r.AttributeDefinition.PicklistId,
                   ParentProductClassificationAttr__r.DefaultValue
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
            
            // Create the type if not already present
            // NOTE: Per requirements, we do NOT take the annotations of ProductClassificationAttr yet
            if (!typeMap.containsKey(classificationId)) {
                CMLTypeWrapper type = new CMLTypeWrapper();
                type.typeName = 'ProductClassification_' + classificationId;
                type.annotation = ''; // Empty for now as per requirements
                type.referenceObjectId = classificationId; // Store the ProductClassification ID
                typeMap.put(classificationId, type);
                
                System.debug('Created type: ' + type.typeName);
            }
            
            // Now add an attribute element to the type's attributes array
            // The attribute's annotation comes from the CML snippet
            CMLTypeWrapper type = typeMap.get(classificationId);
            
            // Use the AttributeDefinition DeveloperName as the attribute name
            String attrName = snippet.ParentProductClassificationAttr__r.AttributeDefinition.DeveloperName;
            
            // Check if attribute already exists (by name to avoid duplicates)
            Boolean attrExists = false;
            for (CMLAttribute existingAttr : type.attributes) {
                if (existingAttr.name == attrName) {
                    attrExists = true;
                    break;
                }
            }
            
            if (!attrExists) {
                CMLAttribute attr = new CMLAttribute();
                attr.name = attrName;
                attr.annotation = snippet.CML__c; // Use the CML from the snippet as annotation
                attr.attributeDefinitionId = snippet.ParentProductClassificationAttr__r.AttributeDefinitionId;
                attr.productClassificationAttrId = snippet.ParentProductClassificationAttr__c;
                attr.picklistId = snippet.ParentProductClassificationAttr__r.AttributeDefinition.PicklistId;
                attr.defaultValue = snippet.ParentProductClassificationAttr__r.DefaultValue; // Get default from ProductClassificationAttr
                
                // Set domain based on DataType
                String dataType = snippet.ParentProductClassificationAttr__r.AttributeDefinition.DataType;
                if (dataType == 'Number') {
                    attr.domain = 'decimal(2)';
                } else {
                    attr.domain = 'string';
                }
                
                type.attributes.add(attr);
                
                System.debug('Added attribute: ' + attrName + ' (domain: ' + attr.domain + ', picklistId: ' + attr.picklistId + ', defaultValue: ' + attr.defaultValue + ') to type: ' + type.typeName);
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
            // Add type annotation if present
            if (String.isNotBlank(type.annotation)) {
                cml += type.annotation + '\n';
            }
            
            // Add type definition
            cml += 'type ' + type.typeName + ' {\n';
            
            // Add constraints
            for (String constraint : type.constraints) {
                cml += '    ' + constraint + '\n';
            }
            
            // Add attributes
            for (CMLAttribute attr : type.attributes) {
                // If attribute has a picklist, get values and potentially update default
                if (attr.picklistId != null) {
                    List<String> picklistValues = getPicklistValuesWithExclusions(attr.picklistId, attr.productClassificationAttrId, attr);
                }
                
                // Add attribute annotation with defaultValue if present
                String annotationToUse = attr.annotation;
                if (String.isNotBlank(attr.defaultValue)) {
                    // Add or update annotation with defaultValue
                    if (String.isNotBlank(annotationToUse)) {
                        // Annotation exists, add defaultValue to it
                        // Remove closing parenthesis and add defaultValue
                        if (annotationToUse.endsWith(')')) {
                            annotationToUse = annotationToUse.substring(0, annotationToUse.length() - 1);
                            annotationToUse += ', defaultValue = "' + attr.defaultValue + '")';
                        }
                    } else {
                        // No annotation, create one with just defaultValue
                        annotationToUse = '@(defaultValue = "' + attr.defaultValue + '")';
                    }
                }
                
                if (String.isNotBlank(annotationToUse)) {
                    cml += '    ' + annotationToUse + '\n';
                }
                
                // Add attribute declaration
                cml += '    ' + attr.domain + ' ' + attr.name;
                
                // If attribute has a picklist, add domain values
                if (attr.picklistId != null) {
                    List<String> picklistValues = getPicklistValuesWithExclusions(attr.picklistId, attr.productClassificationAttrId, attr);
                    if (!picklistValues.isEmpty()) {
                        cml += ' = [';
                        for (Integer i = 0; i < picklistValues.size(); i++) {
                            cml += '"' + picklistValues[i] + '"';
                            if (i < picklistValues.size() - 1) {
                                cml += ', ';
                            }
                        }
                        cml += '];\n';
                    } else {
                        cml += ';\n';
                    }
                } else {
                    cml += ';\n';
                }
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
    
    /**
     * @description Gets the ExpressionSet ID by querying the ExpressionSet table
     * @param expressionSetDefinitionId The ExpressionSetDefinition ID (not used, kept for signature)
     * @return Id The ExpressionSet ID
     */
    private static Id getExpressionSetId(Id expressionSetDefinitionId) {
        // Query the ExpressionSet table directly using ApiName
        List<ExpressionSet> expressionSets = [
            SELECT Id
            FROM ExpressionSet
            WHERE ApiName = :ALLOWED_EXPRESSION_SET
            LIMIT 1
        ];
        
        if (expressionSets.isEmpty()) {
            throw new CMLGeneratorException(
                'ExpressionSet with ApiName "' + ALLOWED_EXPRESSION_SET + '" not found.'
            );
        }
        
        return expressionSets[0].Id;
    }
    
    /**
     * @description Deletes all ExpressionSetConstraintObj records for the given ExpressionSet
     * SAFETY: Only deletes for PCM_All ExpressionSet
     * @param expressionSetId The ExpressionSet ID
     */
    private static void deleteExpressionSetConstraintObjs(Id expressionSetId) {
        List<ExpressionSetConstraintObj> objsToDelete = [
            SELECT Id
            FROM ExpressionSetConstraintObj
            WHERE ExpressionSetId = :expressionSetId
        ];
        
        if (!objsToDelete.isEmpty()) {
            System.debug('Deleting ' + objsToDelete.size() + ' ExpressionSetConstraintObj records');
            delete objsToDelete;
            System.debug('Deleted ExpressionSetConstraintObj records successfully');
        } else {
            System.debug('No ExpressionSetConstraintObj records to delete');
        }
    }
    
    /**
     * @description Creates ExpressionSetConstraintObj records for each type
     * @param expressionSetId The ExpressionSet ID
     * @param typeMap Map of types to create constraint objects for
     */
    private static void createExpressionSetConstraintObjs(Id expressionSetId, Map<Id, CMLTypeWrapper> typeMap) {
        List<ExpressionSetConstraintObj> objsToCreate = new List<ExpressionSetConstraintObj>();
        
        for (CMLTypeWrapper type : typeMap.values()) {
            ExpressionSetConstraintObj obj = new ExpressionSetConstraintObj();
            obj.ExpressionSetId = expressionSetId;
            obj.ReferenceObjectId = type.referenceObjectId;
            obj.ConstraintModelTag = type.typeName;
            obj.ConstraintModelTagType = 'Type';
            objsToCreate.add(obj);
        }
        
        if (!objsToCreate.isEmpty()) {
            System.debug('Creating ' + objsToCreate.size() + ' ExpressionSetConstraintObj records');
            insert objsToCreate;
            System.debug('Created ExpressionSetConstraintObj records successfully');
        }
    }
    
    /**
     * @description Gets picklist values with exclusions applied
     * @param picklistId The Picklist ID
     * @param productClassificationAttrId The ProductClassificationAttr ID
     * @param attr The attribute to update with default value
     * @return List<String> List of picklist Name values (excluding any excluded values)
     */
    private static List<String> getPicklistValuesWithExclusions(Id picklistId, Id productClassificationAttrId, CMLAttribute attr) {
        List<String> values = new List<String>();
        
        // Get all picklist values
        List<AttributePicklistValue> picklistValues = [
            SELECT Id, Name, IsDefault
            FROM AttributePicklistValue
            WHERE PicklistId = :picklistId
            ORDER BY Sequence ASC
        ];
        
        // Get excluded picklist value IDs for this ProductClassificationAttr
        Set<Id> excludedPicklistValueIds = new Set<Id>();
        List<AttrPicklistExcludedValue> excludedValues = [
            SELECT AttributePicklistValueId
            FROM AttrPicklistExcludedValue
            WHERE AttributeId = :productClassificationAttrId
        ];
        
        for (AttrPicklistExcludedValue excluded : excludedValues) {
            excludedPicklistValueIds.add(excluded.AttributePicklistValueId);
        }
        
        // Build final list excluding any excluded values
        // Also track the default value from picklist if not already set
        for (AttributePicklistValue pv : picklistValues) {
            if (!excludedPicklistValueIds.contains(pv.Id)) {
                values.add(pv.Name);
                
                // If this is the default and we don't have a default from ProductClassificationAttr, use it
                if (pv.IsDefault && String.isBlank(attr.defaultValue)) {
                    attr.defaultValue = pv.Name;
                }
            }
        }
        
        System.debug('Picklist ' + picklistId + ': Found ' + picklistValues.size() + ' values, excluded ' + excludedPicklistValueIds.size() + ', returning ' + values.size() + ', default: ' + attr.defaultValue);
        
        return values;
    }
}
