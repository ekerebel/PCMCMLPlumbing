/**
 * Controller for CML Backup and Restore functionality
 * Handles creating backups of CMLSnippet__c records and restoring from backups
 */
public with sharing class CMLBackupController {
    
    /**
     * Get all backup records
     * @return List of CMLBackup__c records with relevant fields
     */
    @AuraEnabled(cacheable=true)
    public static List<CMLBackup__c> getBackups() {
        try {
            return [
                SELECT Id, Name, BackupName__c, CreatedDate, CreatedBy.Name
                FROM CMLBackup__c
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving backups: ' + e.getMessage());
        }
    }
    
    /**
     * Get count of backup records
     * @return Integer count of backups
     */
    @AuraEnabled(cacheable=true)
    public static Integer getBackupCount() {
        try {
            return [SELECT COUNT() FROM CMLBackup__c];
        } catch (Exception e) {
            return 0;
        }
    }
    
    /**
     * Create a backup of all CMLSnippet__c records
     * @param backupName User-provided name for the backup
     * @return Id of the created backup record
     */
    @AuraEnabled
    public static String createBackup(String backupName) {
        try {
            // Get all field names for CMLSnippet__c dynamically
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.CMLSnippet__c.fields.getMap();
            List<String> fieldNames = new List<String>();
            
            // Exclude system fields that shouldn't be backed up
            Set<String> excludedFields = new Set<String>{
                'Id', 'SystemModstamp', 'LastModifiedById', 'LastModifiedDate', 
                'CreatedById', 'CreatedDate', 'IsDeleted', 'LastViewedDate', 
                'LastReferencedDate'
            };
            
            for (String fieldName : fieldMap.keySet()) {
                Schema.SObjectField field = fieldMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                
                // Include field if it's createable or it's the Name field
                if ((fieldDescribe.isCreateable() || fieldName.equalsIgnoreCase('Name')) 
                    && !excludedFields.contains(fieldName)) {
                    fieldNames.add(fieldName);
                }
            }
            
            // Build dynamic SOQL query
            String soql = 'SELECT ' + String.join(fieldNames, ', ') + ' FROM CMLSnippet__c ORDER BY Name';
            List<CMLSnippet__c> snippets = Database.query(soql);
            
            // Generate CSV content
            String csvContent = generateCSV(snippets, fieldNames);
            
            // Create backup record
            CMLBackup__c backup = new CMLBackup__c(
                BackupName__c = backupName
            );
            insert backup;
            
            // Create ContentVersion (file) and link to backup record
            ContentVersion cv = new ContentVersion(
                Title = backupName + '.csv',
                PathOnClient = backupName + '.csv',
                VersionData = Blob.valueOf(csvContent),
                FirstPublishLocationId = backup.Id,
                IsMajorVersion = true
            );
            insert cv;
            
            return backup.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating backup: ' + e.getMessage());
        }
    }
    
    /**
     * Delete a backup record
     * @param backupId Id of the backup record to delete
     */
    @AuraEnabled
    public static void deleteBackup(String backupId) {
        try {
            CMLBackup__c backup = [SELECT Id FROM CMLBackup__c WHERE Id = :backupId LIMIT 1];
            delete backup;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting backup: ' + e.getMessage());
        }
    }
    
    /**
     * Restore CMLSnippet__c records from a backup
     * @param backupId Id of the backup record to restore from
     * @return Number of records restored
     */
    @AuraEnabled
    public static Integer restoreBackup(String backupId) {
        try {
            // Get the CSV file from the backup record
            List<ContentDocumentLink> cdLinks = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :backupId 
                LIMIT 1
            ];
            
            if (cdLinks.isEmpty()) {
                throw new AuraHandledException('No backup file found for this backup record.');
            }
            
            // Get the latest version of the content
            List<ContentVersion> cvList = [
                SELECT VersionData 
                FROM ContentVersion 
                WHERE ContentDocumentId = :cdLinks[0].ContentDocumentId 
                AND IsLatest = true 
                LIMIT 1
            ];
            
            if (cvList.isEmpty()) {
                throw new AuraHandledException('Backup file content not found.');
            }
            
            // Parse CSV content
            String csvContent = cvList[0].VersionData.toString();
            List<CMLSnippet__c> snippetsToRestore = parseCSV(csvContent);
            
            // Delete all existing CMLSnippet__c records
            List<CMLSnippet__c> existingSnippets = [SELECT Id FROM CMLSnippet__c];
            if (!existingSnippets.isEmpty()) {
                delete existingSnippets;
            }
            
            // Insert restored records
            if (!snippetsToRestore.isEmpty()) {
                insert snippetsToRestore;
            }
            
            return snippetsToRestore.size();
        } catch (Exception e) {
            throw new AuraHandledException('Error restoring backup: ' + e.getMessage());
        }
    }
    
    /**
     * Generate CSV content from list of CMLSnippet__c records
     * @param snippets List of CMLSnippet__c records
     * @param fieldNames List of field names to include
     * @return CSV string
     */
    private static String generateCSV(List<CMLSnippet__c> snippets, List<String> fieldNames) {
        String csv = '';
        
        // Add header row
        csv += String.join(fieldNames, ',') + '\n';
        
        // Add data rows
        for (CMLSnippet__c snippet : snippets) {
            List<String> values = new List<String>();
            for (String fieldName : fieldNames) {
                Object value = snippet.get(fieldName);
                String stringValue = value != null ? String.valueOf(value) : '';
                
                // Escape quotes and wrap in quotes if contains comma or quote
                if (stringValue.contains(',') || stringValue.contains('"') || stringValue.contains('\n')) {
                    stringValue = '"' + stringValue.replace('"', '""') + '"';
                }
                values.add(stringValue);
            }
            csv += String.join(values, ',') + '\n';
        }
        
        return csv;
    }
    
    /**
     * Parse CSV content and create CMLSnippet__c records
     * @param csvContent CSV string content
     * @return List of CMLSnippet__c records
     */
    private static List<CMLSnippet__c> parseCSV(String csvContent) {
        List<CMLSnippet__c> snippets = new List<CMLSnippet__c>();
        
        // Split into lines
        List<String> lines = csvContent.split('\n');
        if (lines.isEmpty()) {
            return snippets;
        }
        
        // Parse header to get field names
        List<String> headers = parseCSVLine(lines[0]);
        
        // Get field describe info for type conversion
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.CMLSnippet__c.fields.getMap();
        
        // Parse data rows
        for (Integer i = 1; i < lines.size(); i++) {
            if (String.isBlank(lines[i])) {
                continue;
            }
            
            List<String> values = parseCSVLine(lines[i]);
            if (values.size() != headers.size()) {
                continue; // Skip malformed rows
            }
            
            CMLSnippet__c snippet = new CMLSnippet__c();
            for (Integer j = 0; j < headers.size(); j++) {
                String fieldName = headers[j];
                String value = values[j];
                
                // Skip Name field as it's auto-number
                if (fieldName.equalsIgnoreCase('Name')) {
                    continue;
                }
                
                // Set field value with proper type conversion
                if (String.isNotBlank(value) && fieldMap.containsKey(fieldName.toLowerCase())) {
                    Schema.SObjectField field = fieldMap.get(fieldName.toLowerCase());
                    Schema.DisplayType fieldType = field.getDescribe().getType();
                    
                    try {
                        if (fieldType == Schema.DisplayType.Boolean) {
                            snippet.put(fieldName, Boolean.valueOf(value));
                        } else if (fieldType == Schema.DisplayType.Integer) {
                            snippet.put(fieldName, Integer.valueOf(value));
                        } else if (fieldType == Schema.DisplayType.Double || fieldType == Schema.DisplayType.Currency || fieldType == Schema.DisplayType.Percent) {
                            snippet.put(fieldName, Decimal.valueOf(value));
                        } else if (fieldType == Schema.DisplayType.Date) {
                            snippet.put(fieldName, Date.valueOf(value));
                        } else if (fieldType == Schema.DisplayType.DateTime) {
                            snippet.put(fieldName, DateTime.valueOf(value));
                        } else {
                            snippet.put(fieldName, value);
                        }
                    } catch (Exception e) {
                        // If conversion fails, skip this field
                        System.debug('Error converting field ' + fieldName + ': ' + e.getMessage());
                    }
                }
            }
            snippets.add(snippet);
        }
        
        return snippets;
    }
    
    /**
     * Parse a single CSV line handling quoted values
     * @param line CSV line to parse
     * @return List of values
     */
    private static List<String> parseCSVLine(String line) {
        List<String> values = new List<String>();
        String currentValue = '';
        Boolean inQuotes = false;
        
        for (Integer i = 0; i < line.length(); i++) {
            String c = line.substring(i, i + 1);
            
            if (c == '"') {
                // Check for escaped quote
                if (inQuotes && i + 1 < line.length() && line.substring(i + 1, i + 2) == '"') {
                    currentValue += '"';
                    i++; // Skip next quote
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (c == ',' && !inQuotes) {
                values.add(currentValue);
                currentValue = '';
            } else {
                currentValue += c;
            }
        }
        
        // Add last value
        values.add(currentValue);
        
        return values;
    }
}
