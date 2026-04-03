# CML Backup Feature Guide

## Overview
The **CML Backup** feature provides a comprehensive backup and restore solution for CMLSnippet__c records. It allows users to create snapshots of all CML Snippets and restore them when needed, ensuring data safety and enabling easy rollback capabilities.

## Features

### 1. Backup Creation
- Create named backups of all CMLSnippet__c records
- All fields are automatically included in the backup
- Backups are stored as CSV files attached to CMLBackup__c records
- Default backup name includes timestamp: "Backup YYYY-MM-DD HH:MM"

### 2. Backup Management
- View all available backups in a sortable data table
- See backup name, number, creation date, and creator
- Navigate between backups easily

### 3. Restore Functionality
- Restore any backup with a single click
- Confirmation dialog prevents accidental restores
- All current CMLSnippet__c records are replaced with backed-up data
- Success message shows count of restored records

## Components Created

### Custom Objects
- **CMLBackup__c** - Stores backup metadata
  - Name (Auto-number): BACKUP-{00000}
  - BackupName__c (Text): User-friendly backup name
  - CreatedDate (Standard): When backup was created

### Apex Classes
- **CMLBackupController.cls** - Handles all backup/restore operations
  - `getBackups()` - Retrieves all backup records
  - `getBackupCount()` - Returns count of backups
  - `createBackup(String backupName)` - Creates new backup
  - `restoreBackup(String backupId)` - Restores from backup

### Lightning Web Components
- **cmlBackupTile** - Clickable tile for app home page
  - Shows backup count
  - Navigates to CML Backup management page
  
- **cmlBackupManager** - Full backup management interface
  - Create backup button with modal
  - Backup list with restore actions
  - Confirmation dialogs

### Lightning Pages
- **CML_Backup_Page** - Dedicated page for backup management

## Deployment

### Quick Deploy (Recommended)
Use the provided deployment script:
```bash
chmod +x deploy-cml-backup.sh
./deploy-cml-backup.sh
```

### Manual Deployment
If you prefer to deploy manually:

1. **Deploy CMLBackup__c Object**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/objects/CMLBackup__c/CMLBackup__c.object-meta.xml
   ```

2. **Deploy BackupName__c Field**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/objects/CMLBackup__c/fields/BackupName__c.field-meta.xml
   ```

3. **Deploy Layout**
   ```bash
   sfdx force:source:deploy -p "force-app/main/default/layouts/CMLBackup__c-CML Backup Layout.layout-meta.xml"
   ```

4. **Deploy Apex Controller**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/classes/CMLBackupController.cls,force-app/main/default/classes/CMLBackupController.cls-meta.xml
   ```

5. **Deploy LWC Components**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/lwc/cmlBackupTile
   sfdx force:source:deploy -p force-app/main/default/lwc/cmlBackupManager
   ```

6. **Deploy Lightning Page**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/flexipages/CML_Backup_Page.flexipage-meta.xml
   ```

7. **Deploy Permission Set**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/permissionsets/CMLSnippet_Access.permissionset-meta.xml
   ```

8. **Assign Permission Set**
   ```bash
   sfdx force:user:permset:assign -n CMLSnippet_Access
   ```

## Setup Instructions

### Adding the Tile to Your App

1. Navigate to your **Product Catalog Management App**
2. Click the **gear icon** and select **Edit Page**
3. In the Lightning App Builder:
   - Find **CML Backup Tile** in the component list
   - Drag it onto your app home page (next to the CML Deployment tile)
4. **Save** the page
5. Click **Activate** and assign to your app
6. Click **Save** again

### Accessing the Backup Page

After adding the tile:
1. Click on the **CML Backup** tile
2. You'll be navigated to the CML Backup management page
3. The page will show the backup creation button and list of existing backups

## Usage

### Creating a Backup

1. Navigate to the CML Backup page (click the tile)
2. Click **"Create a Backup"** button
3. A modal will appear with a default name: "Backup YYYY-MM-DD HH:MM"
4. Edit the name if desired
5. Click **"Create Backup"**
6. Wait for the success message
7. The new backup will appear in the list

**What Gets Backed Up:**
- All CMLSnippet__c records
- All field values (except system fields like Id, CreatedDate, etc.)
- Data is stored as CSV file attached to the backup record

### Restoring a Backup

1. Navigate to the CML Backup page
2. Find the backup you want to restore in the list
3. Click the **"Restore"** button in the Actions column
4. Read the confirmation dialog carefully:
   - ⚠️ **Warning:** This action cannot be undone
   - All current CML Snippet records will be deleted
   - They will be replaced with the backed-up data
5. Click **"Confirm Restore"** to proceed, or **"Cancel"** to abort
6. Wait for the restore to complete
7. Success message will show how many records were restored

### Viewing Backup Details

1. Click on any backup name in the list
2. You'll see the backup record detail page
3. The **Files** related list shows the attached CSV file
4. You can download the CSV to view the backed-up data

## Data Model

### Fields Included in Backup
The backup automatically includes all createable fields from CMLSnippet__c:
- Name (auto-number, not restored - new numbers generated)
- CML__c
- Label__c
- Object__c
- Type__c
- ParentProduct2__c
- ParentProductClassification__c
- ParentProductClassificationAttr__c
- ParentProductComponentGroup__c
- ParentProductRelComponentOverride__c
- ParentProductAttributeDefinition__c

### Fields Excluded from Backup
System fields that are auto-generated:
- Id (new Ids generated on restore)
- CreatedDate
- CreatedById
- LastModifiedDate
- LastModifiedById
- SystemModstamp

## Best Practices

### When to Create Backups

1. **Before Major Changes**
   - Before bulk updates to CML Snippets
   - Before deploying new CML generation logic
   - Before testing new constraint rules

2. **Regular Intervals**
   - Daily backups for active development
   - Weekly backups for stable environments
   - Before each production deployment

3. **Before Restore Operations**
   - Always create a backup before restoring an older backup
   - This allows you to rollback if the restore doesn't work as expected

### Backup Naming Conventions

Use descriptive names that include:
- Date/time (included by default)
- Purpose: "Before Product Update", "Pre-Migration", etc.
- Environment: "Dev Backup", "UAT Snapshot", etc.

Examples:
- "Backup 2026-03-10 11:00 - Before Product Catalog Update"
- "Pre-Migration Snapshot 2026-03-10"
- "Working State - All Tests Passing"

### Managing Backups

- Delete old backups that are no longer needed
- Keep at least one backup from each major milestone
- Document what each backup contains in the backup name
- Test restore functionality periodically to ensure backups are valid

## Troubleshooting

### Backup Creation Fails

**Error:** "Error creating backup: [message]"

**Solutions:**
- Check that you have create permissions on CMLBackup__c
- Verify that CMLSnippet__c records exist
- Check governor limits if you have many records
- Review debug logs for detailed error messages

### Restore Fails

**Error:** "Error restoring backup: [message]"

**Solutions:**
- Verify the backup file exists and is attached
- Check that you have delete permissions on CMLSnippet__c
- Ensure you have create permissions on CMLSnippet__c
- Check for validation rules that might prevent record creation
- Review required fields on CMLSnippet__c

### Tile Not Appearing

**Solutions:**
- Verify deployment was successful
- Check that you have the CML Snippet Access permission set assigned
- Refresh your browser
- Clear browser cache
- Verify the component is added to the app page in Lightning App Builder

### Navigation Not Working

**Error:** Clicking tile doesn't navigate to backup page

**Solutions:**
- Verify CML_Backup_Page flexipage is deployed
- Check that the page is activated
- Ensure the page API name is exactly "CML_Backup_Page"
- Try navigating directly via Setup > Lightning Pages

## Technical Notes

### CSV Format
- Header row contains field API names
- Values are comma-separated
- Quotes are escaped as double-quotes ("")
- Fields containing commas or quotes are wrapped in quotes

### Governor Limits
- Backup creation queries all CMLSnippet__c records
- Large datasets may approach SOQL query limits
- Restore operation deletes all records then inserts new ones
- Consider batch processing for very large datasets (>10,000 records)

### File Storage
- CSV files are stored as ContentVersion records
- Files are linked to CMLBackup__c via ContentDocumentLink
- Files count against your org's file storage limits
- Each backup creates one CSV file

## Security

### Permissions Required
Users need the following permissions (included in CML Snippet Access permission set):
- Read, Create, Edit, Delete on CMLBackup__c
- Read, Create, Edit, Delete on CMLSnippet__c
- Access to CML_Backup_Page
- Read access to ContentVersion and ContentDocumentLink

### Data Access
- Backups respect sharing rules
- Users can only restore backups they can read
- Restored records are owned by the user performing the restore
- Consider data security when sharing backup files

## Future Enhancements

Potential improvements for future versions:
1. Scheduled automatic backups
2. Backup comparison tool
3. Selective restore (restore specific records)
4. Backup to external storage (AWS S3, etc.)
5. Backup versioning and diff view
6. Email notifications on backup/restore
7. Backup retention policies
8. Incremental backups

## Support

For issues or questions:
1. Check this guide first
2. Review debug logs in Developer Console
3. Check the deployment script output
4. Verify all components are deployed correctly
5. Test in a sandbox environment first

## Related Documentation

- [CML Generator Setup Guide](CML_GENERATOR_SETUP_GUIDE.md)
- [Constraint Studio Guide](CONSTRAINT_STUDIO_GUIDE.md)
- [CML Implementation Status](CML_IMPLEMENTATION_STATUS.md)
