#!/bin/bash

# CML Backup Feature Deployment Script
# This script deploys all components for the CML Backup feature

echo "=========================================="
echo "CML Backup Feature Deployment"
echo "=========================================="
echo ""

# Step 1: Deploy CMLBackup__c Object
echo "Step 1: Deploying CMLBackup__c object..."
sfdx project deploy start -d force-app/main/default/objects/CMLBackup__c/CMLBackup__c.object-meta.xml
if [ $? -ne 0 ]; then
    echo "Error deploying CMLBackup__c object"
    exit 1
fi
echo "✓ CMLBackup__c object deployed"
echo ""

# Step 2: Deploy BackupName__c Field
echo "Step 2: Deploying BackupName__c field..."
sfdx project deploy start -d force-app/main/default/objects/CMLBackup__c/fields/BackupName__c.field-meta.xml
if [ $? -ne 0 ]; then
    echo "Error deploying BackupName__c field"
    exit 1
fi
echo "✓ BackupName__c field deployed"
echo ""

# Step 3: Deploy CMLBackup Layout
echo "Step 3: Deploying CMLBackup layout..."
sfdx project deploy start -d "force-app/main/default/layouts/CMLBackup__c-CML Backup Layout.layout-meta.xml"
if [ $? -ne 0 ]; then
    echo "Error deploying CMLBackup layout"
    exit 1
fi
echo "✓ CMLBackup layout deployed"
echo ""

# Step 4: Deploy Apex Controller
echo "Step 4: Deploying CMLBackupController..."
sfdx project deploy start -d force-app/main/default/classes/CMLBackupController.cls,force-app/main/default/classes/CMLBackupController.cls-meta.xml
if [ $? -ne 0 ]; then
    echo "Error deploying CMLBackupController"
    exit 1
fi
echo "✓ CMLBackupController deployed"
echo ""

# Step 5: Deploy cmlBackupTile LWC
echo "Step 5: Deploying cmlBackupTile component..."
sfdx project deploy start -d force-app/main/default/lwc/cmlBackupTile
if [ $? -ne 0 ]; then
    echo "Error deploying cmlBackupTile"
    exit 1
fi
echo "✓ cmlBackupTile component deployed"
echo ""

# Step 6: Deploy cmlBackupManager LWC
echo "Step 6: Deploying cmlBackupManager component..."
sfdx project deploy start -d force-app/main/default/lwc/cmlBackupManager
if [ $? -ne 0 ]; then
    echo "Error deploying cmlBackupManager"
    exit 1
fi
echo "✓ cmlBackupManager component deployed"
echo ""

# Step 7: Deploy CML Backup Page
echo "Step 7: Deploying CML Backup Page..."
sfdx project deploy start -d force-app/main/default/flexipages/CML_Backup_Page.flexipage-meta.xml
if [ $? -ne 0 ]; then
    echo "Error deploying CML Backup Page"
    exit 1
fi
echo "✓ CML Backup Page deployed"
echo ""

# Step 8: Deploy CML Backup Tab
echo "Step 8: Deploying CML Backup Tab..."
sfdx project deploy start -d force-app/main/default/tabs/CML_Backup.tab-meta.xml
if [ $? -ne 0 ]; then
    echo "Error deploying CML Backup Tab"
    exit 1
fi
echo "✓ CML Backup Tab deployed"
echo ""

# Step 9: Deploy Updated Permission Set
echo "Step 9: Deploying updated permission set..."
sfdx project deploy start -d force-app/main/default/permissionsets/CMLSnippet_Access.permissionset-meta.xml
if [ $? -ne 0 ]; then
    echo "Error deploying permission set"
    exit 1
fi
echo "✓ Permission set deployed"
echo ""

# Step 10: Assign Permission Set
echo "Step 10: Assigning permission set to current user..."
sfdx org assign permset -n CMLSnippet_Access
if [ $? -ne 0 ]; then
    echo "Warning: Could not assign permission set automatically"
    echo "Please assign 'CML Snippet Access' permission set manually"
else
    echo "✓ Permission set assigned"
fi
echo ""

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Navigate to your Product Catalog Management App"
echo "2. Edit the app home page in Lightning App Builder"
echo "3. Add the 'CML Backup Tile' component to the page"
echo "4. Save and activate the page"
echo "5. Click the tile to access the CML Backup management page"
echo ""
echo "For detailed instructions, see CML_BACKUP_GUIDE.md"
echo ""
