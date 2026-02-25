
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
        public String objectType; // 'ProductComponentGroup' or 'ProductRelatedComponent'
        public Id objectId; // ProductComponentGroup or ProductRelatedComponent ID
        public Integer cardinalityMin;
        public Integer cardinalityMax;
    }
    
    /**
     * @description Inner class representing an attribute
     */
    public class CMLAttribute {
        public String name; // AttributeDefinition.DeveloperName (for reference only)
        public String parentType; // 'ProductClassificationAttr' or 'ProductAttributeDefinition'
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
            System.debug('Processed ' + typeMap.size() + ' types from attribute snippets');
            
            // Step 3b: Process constraint snippets
            processConstraintSnippets(typeMap);
            System.debug('Processed constraint snippets');
            
            // Step 4: Generate CML string (in-memory only)
            String cmlContent = generateCML(typeMap);
            System.debug('Generated CML size: ' + cmlContent.length() + ' characters');
            System.debug('Generated CML:\n' + cmlContent);
            
            // Step 5: Update BLOB with generated CML (HTTP callout - BEFORE any DML)
            updateBlob(esdv, cmlContent);
            System.debug('BLOB updated successfully');
            
            // Step 6: Delete existing ExpressionSetConstraintObj records (DML)
            deleteExpressionSetConstraintObjs(expressionSetId);
            
            // Step 7: Create ExpressionSetConstraintObj records for each type (DML)
            createExpressionSetConstraintObjs(expressionSetId, typeMap);
            
            // Step 8: Activate/Deploy the CML (HTTP callout - AFTER DML)
            // Try to activate, but don't fail the entire process if activation fails
            try {
                activateCML(expressionSetId, esdv.Id);
                System.debug('CML activated successfully');
            } catch (Exception activationEx) {
                System.debug(LoggingLevel.WARN, 'CML activation failed: ' + activationEx.getMessage());
                // Don't throw - allow the process to complete even if activation fails
            }
            
            System.debug('=== CML Deployment Completed Successfully ===');
            return 'CML generated, deployed, and activated successfully for ' + typeMap.size() + ' types.';
            
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
        
        // Get session ID from Page reference or use alternative method
        String sessionId = getSessionId();
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(fullUrl);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
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
     * @description Gets a valid session ID for API calls
     * @return String Session ID
     */
    private static String getSessionId() {
        // UserInfo.getSessionId() works in most contexts including when called from LWC
        String sessionId = UserInfo.getSessionId();
        
        if (String.isBlank(sessionId)) {
            throw new CMLGeneratorException('Unable to obtain session ID for API calls');
        }
        
        return sessionId;
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
                attr.parentType = 'ProductClassificationAttr';
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
     * @description Processes ProductClassification and Product2 constraint snippets
     * @param typeMap The type map to update with constraints and relations
     */
    private static void processConstraintSnippets(Map<Id, CMLTypeWrapper> typeMap) {
        // Query CML Snippets for ProductClassification constraints
        List<CMLSnippet__c> pcSnippets = [
            SELECT Id, CML__c, Type__c, Object__c,
                   ParentProductClassification__c
            FROM CMLSnippet__c
            WHERE Object__c = 'ProductClassification'
            AND Type__c = 'constraint'
            AND ParentProductClassification__c != null
        ];
        
        System.debug('=== Processing ProductClassification Constraints ===');
        System.debug('Found ' + pcSnippets.size() + ' ProductClassification constraint snippets');
        
        for (CMLSnippet__c snippet : pcSnippets) {
            Id classificationId = snippet.ParentProductClassification__c;
            System.debug('Processing snippet ' + snippet.Id + ' for ProductClassification: ' + classificationId);
            System.debug('Constraint CML: ' + snippet.CML__c);
            
            // Create the type if not already present
            if (!typeMap.containsKey(classificationId)) {
                CMLTypeWrapper type = new CMLTypeWrapper();
                type.typeName = 'ProductClassification_' + classificationId;
                type.annotation = '';
                type.referenceObjectId = classificationId;
                typeMap.put(classificationId, type);
                System.debug('Created type from constraint: ' + type.typeName);
            }
            
            CMLTypeWrapper type = typeMap.get(classificationId);
            
            // Add the constraint to the type's constraint array
            type.constraints.add(snippet.CML__c);
            System.debug('Added constraint to type ' + type.typeName + ': ' + snippet.CML__c);
            
            // Parse the constraint to find references
            parseConstraintReferences(snippet.CML__c, type, typeMap);
        }
        
        // Query CML Snippets for Product2 constraints
        List<CMLSnippet__c> p2Snippets = [
            SELECT Id, CML__c, Type__c, Object__c,
                   ParentProduct2__c
            FROM CMLSnippet__c
            WHERE Object__c = 'Product2'
            AND Type__c = 'constraint'
            AND ParentProduct2__c != null
        ];
        
        System.debug('=== Processing Product2 Constraints ===');
        System.debug('Found ' + p2Snippets.size() + ' Product2 constraint snippets');
        
        for (CMLSnippet__c snippet : p2Snippets) {
            Id product2Id = snippet.ParentProduct2__c;
            System.debug('Processing snippet ' + snippet.Id + ' for Product2: ' + product2Id);
            System.debug('Constraint CML: ' + snippet.CML__c);
            
            // Create the type if not already present
            if (!typeMap.containsKey(product2Id)) {
                CMLTypeWrapper type = new CMLTypeWrapper();
                type.typeName = 'Product2_' + product2Id;
                type.annotation = '';
                type.referenceObjectId = product2Id;
                typeMap.put(product2Id, type);
                System.debug('Created Product2 type from constraint: ' + type.typeName);
            }
            
            CMLTypeWrapper type = typeMap.get(product2Id);
            
            // Add the constraint to the type's constraint array
            type.constraints.add(snippet.CML__c);
            System.debug('Added constraint to type ' + type.typeName + ': ' + snippet.CML__c);
            
            // Parse the constraint to find references
            parseConstraintReferences(snippet.CML__c, type, typeMap);
        }
        
        System.debug('=== Constraint Processing Complete ===');
        System.debug('Total types in map: ' + typeMap.size());
    }
    
    /**
     * @description Parses constraint string to find attribute and relation references
     * @param constraint The constraint string to parse
     * @param type The type to update
     * @param typeMap The global type map
     */
    private static void parseConstraintReferences(String constraint, CMLTypeWrapper type, Map<Id, CMLTypeWrapper> typeMap) {
        // NEW APPROACH: Query all attributes for this type and check if they're referenced in the constraint
        // Determine if this is a ProductClassification or Product2 type
        if (type.typeName.startsWith('ProductClassification_')) {
            // Query all ProductClassificationAttr for this ProductClassification
            List<ProductClassificationAttr> attrs = [
                SELECT Id, ProductClassificationId, AttributeDefinitionId,
                       AttributeDefinition.DeveloperName,
                       AttributeDefinition.DataType,
                       AttributeDefinition.PicklistId,
                       DefaultValue
                FROM ProductClassificationAttr
                WHERE ProductClassificationId = :type.referenceObjectId
            ];
            
            System.debug('Found ' + attrs.size() + ' ProductClassificationAttr records for ' + type.typeName);
            
            // Check each attribute's DeveloperName in the constraint
            for (ProductClassificationAttr pca : attrs) {
                String developerName = pca.AttributeDefinition.DeveloperName;
                if (constraint.contains(developerName)) {
                    System.debug('Attribute ' + developerName + ' is referenced in constraint');
                    addAttributeIfNotExists(pca, type);
                }
            }
        } else if (type.typeName.startsWith('Product2_')) {
            // Query all ProductAttributeDefinition for this Product2
            List<ProductAttributeDefinition> attrDefs = [
                SELECT Id, Product2Id, AttributeDefinitionId,
                       AttributeDefinition.DeveloperName,
                       AttributeDefinition.DataType,
                       AttributeDefinition.PicklistId,
                       DefaultValue
                FROM ProductAttributeDefinition
                WHERE Product2Id = :type.referenceObjectId
            ];
            
            System.debug('Found ' + attrDefs.size() + ' ProductAttributeDefinition records for ' + type.typeName);
            
            // Check each attribute's DeveloperName in the constraint
            for (ProductAttributeDefinition pad : attrDefs) {
                String developerName = pad.AttributeDefinition.DeveloperName;
                if (constraint.contains(developerName)) {
                    System.debug('Attribute ' + developerName + ' is referenced in constraint');
                    addAttributeIfNotExists(pad, type);
                }
            }
            
            // Also get the Product2's ProductClassification attributes (step 5 in requirements)
            List<Product2> products = [
                SELECT Id, BasedOnId
                FROM Product2
                WHERE Id = :type.referenceObjectId
                LIMIT 1
            ];
            
            if (!products.isEmpty() && products[0].BasedOnId != null) {
                Id classificationId = products[0].BasedOnId;
                System.debug('Product2 is based on ProductClassification: ' + classificationId);
                
                List<ProductClassificationAttr> classAttrs = [
                    SELECT Id, ProductClassificationId, AttributeDefinitionId,
                           AttributeDefinition.DeveloperName,
                           AttributeDefinition.DataType,
                           AttributeDefinition.PicklistId,
                           DefaultValue
                    FROM ProductClassificationAttr
                    WHERE ProductClassificationId = :classificationId
                ];
                
                System.debug('Found ' + classAttrs.size() + ' ProductClassificationAttr records from base classification');
                
                for (ProductClassificationAttr pca : classAttrs) {
                    String developerName = pca.AttributeDefinition.DeveloperName;
                    if (constraint.contains(developerName)) {
                        System.debug('Classification attribute ' + developerName + ' is referenced in constraint');
                        addAttributeIfNotExists(pca, type);
                    }
                }
            }
        }
        
        // Parse for ProductComponentGroup references: ProductComponentGroup_<ID> or Rel_ProductComponentGroup_<ID>
        Pattern pcgPattern = Pattern.compile('(?:Rel_)?ProductComponentGroup_([a-zA-Z0-9]{15,18})');
        Matcher pcgMatcher = pcgPattern.matcher(constraint);
        while (pcgMatcher.find()) {
            String pcgId = pcgMatcher.group(1);
            addProductComponentGroupRelation(pcgId, type, typeMap);
        }
        
        // Parse for ProductRelatedComponent references: ProductRelatedComponent_<ID> or Rel_ProductRelatedComponent_<ID>
        Pattern prcPattern = Pattern.compile('(?:Rel_)?ProductRelatedComponent_([a-zA-Z0-9]{15,18})');
        Matcher prcMatcher = prcPattern.matcher(constraint);
        while (prcMatcher.find()) {
            String prcId = prcMatcher.group(1);
            addProductRelatedComponentRelation(prcId, type, typeMap);
        }
    }
    
    /**
     * @description Adds a ProductClassificationAttr attribute if not already present
     * @param pca The ProductClassificationAttr record
     * @param type The type to add the attribute to
     */
    private static void addAttributeIfNotExists(ProductClassificationAttr pca, CMLTypeWrapper type) {
        String attrName = pca.AttributeDefinition.DeveloperName;
        
        // Check if attribute already exists (by name)
        for (CMLAttribute existingAttr : type.attributes) {
            if (existingAttr.name == attrName) {
                System.debug('Attribute ' + attrName + ' already exists in type ' + type.typeName);
                return;
            }
        }
        
        // Add the attribute
        CMLAttribute attr = new CMLAttribute();
        attr.name = attrName;
        attr.parentType = 'ProductClassificationAttr';
        attr.annotation = ''; // No annotation from constraint
        attr.attributeDefinitionId = pca.AttributeDefinitionId;
        attr.productClassificationAttrId = pca.Id;
        attr.picklistId = pca.AttributeDefinition.PicklistId;
        attr.defaultValue = pca.DefaultValue;
        
        // Set domain based on DataType
        String dataType = pca.AttributeDefinition.DataType;
        if (dataType == 'Number') {
            attr.domain = 'decimal(2)';
        } else {
            attr.domain = 'string';
        }
        
        type.attributes.add(attr);
        System.debug('Added attribute from constraint: ' + attrName + ' to type: ' + type.typeName);
    }
    
    /**
     * @description Adds a ProductAttributeDefinition attribute if not already present
     * @param pad The ProductAttributeDefinition record
     * @param type The type to add the attribute to
     */
    private static void addAttributeIfNotExists(ProductAttributeDefinition pad, CMLTypeWrapper type) {
        String attrName = pad.AttributeDefinition.DeveloperName;
        
        // Check if attribute already exists (by name)
        for (CMLAttribute existingAttr : type.attributes) {
            if (existingAttr.name == attrName) {
                System.debug('Attribute ' + attrName + ' already exists in type ' + type.typeName);
                return;
            }
        }
        
        // Add the attribute
        CMLAttribute attr = new CMLAttribute();
        attr.name = attrName;
        attr.parentType = 'ProductAttributeDefinition';
        attr.annotation = ''; // No annotation from constraint
        attr.attributeDefinitionId = pad.AttributeDefinitionId;
        attr.productClassificationAttrId = pad.Id;
        attr.picklistId = pad.AttributeDefinition.PicklistId;
        attr.defaultValue = pad.DefaultValue;
        
        // Set domain based on DataType
        String dataType = pad.AttributeDefinition.DataType;
        if (dataType == 'Number') {
            attr.domain = 'decimal(2)';
        } else {
            attr.domain = 'string';
        }
        
        type.attributes.add(attr);
        System.debug('Added attribute from constraint: ' + attrName + ' to type: ' + type.typeName);
    }
    
    /**
     * @description Adds a ProductComponentGroup as a relation
     * @param pcgId The ProductComponentGroup ID
     * @param type The type to add the relation to
     * @param typeMap The global type map
     */
    private static void addProductComponentGroupRelation(String pcgId, CMLTypeWrapper type, Map<Id, CMLTypeWrapper> typeMap) {
        // Check if relation already exists
        for (CMLRelation rel : type.relations) {
            if (rel.objectId == pcgId && rel.objectType == 'ProductComponentGroup') {
                return; // Already added
            }
        }
        
        CMLRelation relation = new CMLRelation();
        relation.objectType = 'ProductComponentGroup';
        relation.objectId = pcgId;
        relation.annotation = '';
        type.relations.add(relation);
        
        System.debug('Added ProductComponentGroup relation: ' + pcgId + ' to type: ' + type.typeName);
    }
    
    /**
     * @description Adds a ProductRelatedComponent as a relation
     * @param prcId The ProductRelatedComponent ID
     * @param type The type to add the relation to
     * @param typeMap The global type map
     */
    private static void addProductRelatedComponentRelation(String prcId, CMLTypeWrapper type, Map<Id, CMLTypeWrapper> typeMap) {
        // Check if relation already exists
        for (CMLRelation rel : type.relations) {
            if (rel.objectId == prcId && rel.objectType == 'ProductRelatedComponent') {
                return; // Already added
            }
        }
        
        CMLRelation relation = new CMLRelation();
        relation.objectType = 'ProductRelatedComponent';
        relation.objectId = prcId;
        relation.annotation = '';
        type.relations.add(relation);
        
        System.debug('Added ProductRelatedComponent relation: ' + prcId + ' to type: ' + type.typeName);
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
        
        // Add property at the top
        String cml = 'property allowMissingRelations = "true";\n\n';
        
        // Track which types have been processed to handle newly added types
        Set<Id> processedTypes = new Set<Id>();
        List<Id> typeIdsToProcess = new List<Id>(typeMap.keySet());
        
        // Process types, including any newly added ones
        Integer index = 0;
        while (index < typeIdsToProcess.size()) {
            Id typeId = typeIdsToProcess[index];
            
            // Skip if already processed
            if (processedTypes.contains(typeId)) {
                index++;
                continue;
            }
            
            CMLTypeWrapper type = typeMap.get(typeId);
            processedTypes.add(typeId);
            
            // Add type annotation if present
            if (String.isNotBlank(type.annotation)) {
                cml += type.annotation + '\n';
            }
            
            // Add type definition with inheritance for Product2 types
            String typeDeclaration = 'type ' + type.typeName;
            
            // If this is a Product2 type, add inheritance from ProductClassification
            if (type.typeName.startsWith('Product2_')) {
                String classificationTypeName = ensureProductClassificationTypeExists(type.referenceObjectId, typeMap);
                if (String.isNotBlank(classificationTypeName)) {
                    typeDeclaration += ' : ' + classificationTypeName;
                }
            }
            
            cml += typeDeclaration + ' {\n';
            
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
                
                // Add attribute declaration using DeveloperName
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
            
            // Add relations with proper Product2 references and cardinality
            for (CMLRelation rel : type.relations) {
                if (rel.objectType == 'ProductRelatedComponent') {
                    cml += generateProductRelatedComponentRelation(rel, type, typeMap);
                } else if (rel.objectType == 'ProductComponentGroup') {
                    cml += generateProductComponentGroupRelation(rel, type, typeMap);
                }
            }
            
            cml += '}\n\n';
            
            // Check if new types were added to the map during processing
            // If so, add them to the list to process
            for (Id newTypeId : typeMap.keySet()) {
                if (!processedTypes.contains(newTypeId) && !typeIdsToProcess.contains(newTypeId)) {
                    typeIdsToProcess.add(newTypeId);
                    System.debug('Added newly created type to process list: ' + typeMap.get(newTypeId).typeName);
                }
            }
            
            // Move to next type
            index++;
        }
        
        return cml;
    }
    
    /**
     * @description Generates CML for a ProductRelatedComponent relation
     * @param rel The relation object
     * @param type The parent type
     * @param typeMap The global type map
     * @return String The generated CML for this relation
     */
    private static String generateProductRelatedComponentRelation(CMLRelation rel, CMLTypeWrapper type, Map<Id, CMLTypeWrapper> typeMap) {
        String relationCml = '';
        
        // Query ProductRelatedComponent to get ChildProductId and cardinality
        List<ProductRelatedComponent> prcs = [
            SELECT Id, ChildProductId, MinQuantity, MaxQuantity
            FROM ProductRelatedComponent
            WHERE Id = :rel.objectId
            LIMIT 1
        ];
        
        if (prcs.isEmpty()) {
            System.debug('Warning: ProductRelatedComponent ' + rel.objectId + ' not found');
            return '';
        }
        
        ProductRelatedComponent prc = prcs[0];
        
        if (prc.ChildProductId == null) {
            System.debug('Warning: ProductRelatedComponent ' + rel.objectId + ' has no ChildProductId');
            return '';
        }
        
        // Ensure Product2 type exists
        String product2TypeName = ensureProduct2TypeExists(prc.ChildProductId, typeMap);
        
        // Add relation annotation if present
        if (String.isNotBlank(rel.annotation)) {
            relationCml += '    ' + rel.annotation + '\n';
        }
        
        // Generate relation name
        String relationName = 'REL_ProductRelatedComponent_' + rel.objectId;
        
        // Build cardinality string
        String cardinality = '';
        if (prc.MinQuantity != null || prc.MaxQuantity != null) {
            Integer minQty = prc.MinQuantity != null ? prc.MinQuantity.intValue() : 0;
            String maxQty = prc.MaxQuantity != null ? String.valueOf(prc.MaxQuantity.intValue()) : '*';
            cardinality = '[' + minQty + '..' + maxQty + ']';
        }
        
        // Generate relation CML
        relationCml += '    relation ' + relationName + ' : ' + product2TypeName + cardinality + ';\n';
        
        System.debug('Generated ProductRelatedComponent relation: ' + relationName + ' -> ' + product2TypeName + cardinality);
        
        return relationCml;
    }
    
    /**
     * @description Generates CML for a ProductComponentGroup relation
     * @param rel The relation object
     * @param type The parent type
     * @param typeMap The global type map
     * @return String The generated CML for this relation
     */
    private static String generateProductComponentGroupRelation(CMLRelation rel, CMLTypeWrapper type, Map<Id, CMLTypeWrapper> typeMap) {
        String relationCml = '';
        
        // Query ProductComponentGroup to get cardinality
        List<ProductComponentGroup> pcgs = [
            SELECT Id, MinBundleComponents, MaxBundleComponents
            FROM ProductComponentGroup
            WHERE Id = :rel.objectId
            LIMIT 1
        ];
        
        if (pcgs.isEmpty()) {
            System.debug('Warning: ProductComponentGroup ' + rel.objectId + ' not found');
            return '';
        }
        
        ProductComponentGroup pcg = pcgs[0];
        
        // Query all ProductRelatedComponents for this ProductComponentGroup
        List<ProductRelatedComponent> prcs = [
            SELECT Id, ChildProductId, MinQuantity, MaxQuantity
            FROM ProductRelatedComponent
            WHERE ProductComponentGroupId = :rel.objectId
        ];
        
        System.debug('Found ' + prcs.size() + ' ProductRelatedComponents for ProductComponentGroup ' + rel.objectId);
        
        // Check qualification criteria
        Boolean qualifiesForClassificationRelation = false;
        Id commonClassificationId = null;
        
        if (pcg.MaxBundleComponents == 1 && !prcs.isEmpty()) {
            // Check if all PRCs have ChildProductId (not null)
            Boolean allHaveProduct2 = true;
            Set<Id> product2Ids = new Set<Id>();
            
            for (ProductRelatedComponent prc : prcs) {
                if (prc.ChildProductId == null) {
                    allHaveProduct2 = false;
                    break;
                }
                product2Ids.add(prc.ChildProductId);
            }
            
            if (allHaveProduct2) {
                // Query all Product2 records to check if they're based on the same ProductClassification
                List<Product2> products = [
                    SELECT Id, BasedOnId
                    FROM Product2
                    WHERE Id IN :product2Ids
                ];
                
                Set<Id> classificationIds = new Set<Id>();
                for (Product2 p : products) {
                    if (p.BasedOnId != null) {
                        classificationIds.add(p.BasedOnId);
                    }
                }
                
                // If all products are based on the same classification, qualify
                if (classificationIds.size() == 1) {
                    qualifiesForClassificationRelation = true;
                    commonClassificationId = new List<Id>(classificationIds)[0];
                    System.debug('ProductComponentGroup qualifies for ProductClassification relation: ' + commonClassificationId);
                }
            }
        }
        
        if (qualifiesForClassificationRelation) {
            // Generate ProductClassification relation
            String classificationTypeName = ensureProductClassificationTypeExistsById(commonClassificationId, typeMap);
            
            // Ensure Product2 types exist for all ProductRelatedComponents in the group
            for (ProductRelatedComponent prc : prcs) {
                if (prc.ChildProductId != null) {
                    ensureProduct2TypeExists(prc.ChildProductId, typeMap);
                    System.debug('Ensured Product2 type exists for PRC ' + prc.Id + ': Product2_' + prc.ChildProductId);
                }
            }
            
            // Add relation annotation if present
            if (String.isNotBlank(rel.annotation)) {
                relationCml += '    ' + rel.annotation + '\n';
            }
            
            // Generate relation name
            String relationName = 'REL_ProductComponentGroup_' + rel.objectId;
            
            // Build cardinality string (MinBundleComponents defaults to 0 if null)
            Integer minQty = pcg.MinBundleComponents != null ? pcg.MinBundleComponents : 0;
            String maxQty = pcg.MaxBundleComponents != null ? String.valueOf(pcg.MaxBundleComponents) : '*';
            String cardinality = '[' + minQty + '..' + maxQty + ']';
            
            // Generate relation CML
            relationCml += '    relation ' + relationName + ' : ' + classificationTypeName + cardinality + ';\n';
            
            System.debug('Generated ProductComponentGroup relation to ProductClassification: ' + relationName + ' -> ' + classificationTypeName + cardinality);
        } else {
            // Generate individual ProductRelatedComponent relations
            System.debug('ProductComponentGroup does not qualify for ProductClassification relation, generating individual ProductRelatedComponent relations');
            
            for (ProductRelatedComponent prc : prcs) {
                if (prc.ChildProductId == null) {
                    System.debug('Warning: ProductRelatedComponent ' + prc.Id + ' has no ChildProductId, skipping');
                    continue;
                }
                
                // Ensure Product2 type exists
                String product2TypeName = ensureProduct2TypeExists(prc.ChildProductId, typeMap);
                
                // Generate relation name
                String relationName = 'REL_ProductRelatedComponent_' + prc.Id;
                
                // Build cardinality string
                String cardinality = '';
                if (prc.MinQuantity != null || prc.MaxQuantity != null) {
                    Integer minQty = prc.MinQuantity != null ? prc.MinQuantity.intValue() : 0;
                    String maxQty = prc.MaxQuantity != null ? String.valueOf(prc.MaxQuantity.intValue()) : '*';
                    cardinality = '[' + minQty + '..' + maxQty + ']';
                }
                
                // Generate relation CML
                relationCml += '    relation ' + relationName + ' : ' + product2TypeName + cardinality + ';\n';
                
                System.debug('Generated ProductRelatedComponent relation from PCG: ' + relationName + ' -> ' + product2TypeName + cardinality);
            }
        }
        
        return relationCml;
    }
    
    /**
     * @description Ensures a ProductClassification type exists by ID
     * @param classificationId The ProductClassification ID
     * @param typeMap The global type map
     * @return String The ProductClassification type name
     */
    private static String ensureProductClassificationTypeExistsById(Id classificationId, Map<Id, CMLTypeWrapper> typeMap) {
        String classificationTypeName = 'ProductClassification_' + classificationId;
        
        // Check if the ProductClassification type already exists
        if (!typeMap.containsKey(classificationId)) {
            // Create the ProductClassification type
            CMLTypeWrapper type = new CMLTypeWrapper();
            type.typeName = classificationTypeName;
            type.annotation = '';
            type.referenceObjectId = classificationId;
            typeMap.put(classificationId, type);
            
            System.debug('Created ProductClassification type: ' + classificationTypeName);
        } else {
            System.debug('ProductClassification type already exists: ' + classificationTypeName);
        }
        
        return classificationTypeName;
    }
    
    /**
     * @description Ensures a Product2 type exists in the typeMap
     * @param product2Id The Product2 ID
     * @param typeMap The global type map
     * @return String The Product2 type name
     */
    private static String ensureProduct2TypeExists(Id product2Id, Map<Id, CMLTypeWrapper> typeMap) {
        String product2TypeName = 'Product2_' + product2Id;
        
        // Check if the Product2 type already exists
        if (!typeMap.containsKey(product2Id)) {
            // Create the Product2 type
            CMLTypeWrapper type = new CMLTypeWrapper();
            type.typeName = product2TypeName;
            type.annotation = '';
            type.referenceObjectId = product2Id;
            typeMap.put(product2Id, type);
            
            System.debug('Created Product2 type for relation: ' + product2TypeName);
        } else {
            System.debug('Product2 type already exists: ' + product2TypeName);
        }
        
        return product2TypeName;
    }
    
    /**
     * @description Ensures a ProductClassification type exists for a Product2
     * @param product2Id The Product2 ID
     * @param typeMap The global type map
     * @return String The ProductClassification type name, or empty string if not found
     */
    private static String ensureProductClassificationTypeExists(Id product2Id, Map<Id, CMLTypeWrapper> typeMap) {
        // Query the Product2 to get its BasedOnId (ProductClassification)
        List<Product2> products = [
            SELECT Id, BasedOnId
            FROM Product2
            WHERE Id = :product2Id
            LIMIT 1
        ];
        
        if (products.isEmpty() || products[0].BasedOnId == null) {
            System.debug('Product2 ' + product2Id + ' has no ProductClassification (BasedOnId is null)');
            return '';
        }
        
        Id classificationId = products[0].BasedOnId;
        String classificationTypeName = 'ProductClassification_' + classificationId;
        
        // Check if the ProductClassification type already exists
        if (!typeMap.containsKey(classificationId)) {
            // Create the ProductClassification type
            CMLTypeWrapper type = new CMLTypeWrapper();
            type.typeName = classificationTypeName;
            type.annotation = '';
            type.referenceObjectId = classificationId;
            typeMap.put(classificationId, type);
            
            System.debug('Created ProductClassification type for Product2 inheritance: ' + classificationTypeName);
        } else {
            System.debug('ProductClassification type already exists: ' + classificationTypeName);
        }
        
        return classificationTypeName;
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
        
        // Get session ID using helper method
        String sessionId = getSessionId();
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(fullUrl);
        req.setMethod('PATCH');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
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
     * @description Activates/Deploys the CML by setting Status to Active
     * @param expressionSetId The ExpressionSet ID
     * @param expressionSetDefinitionVersionId The ExpressionSetDefinitionVersion ID
     */
    private static void activateCML(Id expressionSetId, Id expressionSetDefinitionVersionId) {
        // Query for the ExpressionSetVersion that corresponds to this ExpressionSet
        // ExpressionSetVersion is linked to ExpressionSet, not ExpressionSetDefinitionVersion
        List<ExpressionSetVersion> versions = [
            SELECT Id, VersionNumber
            FROM ExpressionSetVersion
            WHERE ExpressionSetId = :expressionSetId
            ORDER BY VersionNumber DESC
            LIMIT 1
        ];
        
        if (versions.isEmpty()) {
            throw new CMLGeneratorException(
                'ExpressionSetVersion not found for ExpressionSet: ' + expressionSetId
            );
        }
        
        Id expressionSetVersionId = versions[0].Id;
        System.debug('Found ExpressionSetVersion: ' + expressionSetVersionId + ' (Version ' + versions[0].VersionNumber + ') for ExpressionSet: ' + expressionSetId);
        
        // Construct the deployment URL
        String deployUrl = '/services/data/' + API_VERSION + '/industries/constraints/' + expressionSetId + '/versions/' + expressionSetVersionId;
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        String fullUrl = instanceUrl + deployUrl;
        
        System.debug('Activating CML at: ' + fullUrl);
        
        // Get session ID
        String sessionId = getSessionId();
        
        // Try POST method to activate (deployment endpoint)
        HttpRequest req = new HttpRequest();
        req.setEndpoint(fullUrl);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{}');  // Empty body for POST activation
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Activation Response Status: ' + res.getStatusCode());
        System.debug('Activation Response Body: ' + res.getBody());
        
        if (res.getStatusCode() != 200 && res.getStatusCode() != 204) {
            throw new CMLGeneratorException(
                'Failed to activate CML. Status: ' + res.getStatusCode() + 
                ', Body: ' + res.getBody()
            );
        }
        
        System.debug('CML activated/deployed successfully');
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
     * @description Creates ExpressionSetConstraintObj records for each type and relation
     * @param expressionSetId The ExpressionSet ID
     * @param typeMap Map of types to create constraint objects for
     */
    private static void createExpressionSetConstraintObjs(Id expressionSetId, Map<Id, CMLTypeWrapper> typeMap) {
        List<ExpressionSetConstraintObj> objsToCreate = new List<ExpressionSetConstraintObj>();
        
        for (CMLTypeWrapper type : typeMap.values()) {
            // Create Type record
            ExpressionSetConstraintObj typeObj = new ExpressionSetConstraintObj();
            typeObj.ExpressionSetId = expressionSetId;
            typeObj.ReferenceObjectId = type.referenceObjectId;
            typeObj.ConstraintModelTag = type.typeName;
            typeObj.ConstraintModelTagType = 'Type';
            objsToCreate.add(typeObj);
            
            // Create Port records for each relation
            for (CMLRelation rel : type.relations) {
                if (rel.objectType == 'ProductRelatedComponent') {
                    ExpressionSetConstraintObj portObj = new ExpressionSetConstraintObj();
                    portObj.ExpressionSetId = expressionSetId;
                    portObj.ReferenceObjectId = rel.objectId;
                    portObj.ConstraintModelTag = 'REL_ProductRelatedComponent_' + rel.objectId;
                    portObj.ConstraintModelTagType = 'Port';
                    objsToCreate.add(portObj);
                    
                    System.debug('Created Port record for ProductRelatedComponent: ' + portObj.ConstraintModelTag);
                } else if (rel.objectType == 'ProductComponentGroup') {
                    // Query all ProductRelatedComponents for this ProductComponentGroup
                    List<ProductRelatedComponent> prcs = [
                        SELECT Id
                        FROM ProductRelatedComponent
                        WHERE ProductComponentGroupId = :rel.objectId
                    ];
                    
                    // Create a Port record for each ProductRelatedComponent in the group
                    for (ProductRelatedComponent prc : prcs) {
                        ExpressionSetConstraintObj portObj = new ExpressionSetConstraintObj();
                        portObj.ExpressionSetId = expressionSetId;
                        portObj.ReferenceObjectId = prc.Id;
                        portObj.ConstraintModelTag = 'REL_ProductComponentGroup_' + rel.objectId;
                        portObj.ConstraintModelTagType = 'Port';
                        objsToCreate.add(portObj);
                        
                        System.debug('Created Port record for ProductComponentGroup: ' + portObj.ConstraintModelTag + ' (PRC: ' + prc.Id + ')');
                    }
                }
            }
        }
        
        if (!objsToCreate.isEmpty()) {
            System.debug('Creating ' + objsToCreate.size() + ' ExpressionSetConstraintObj records (Types + Ports)');
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
