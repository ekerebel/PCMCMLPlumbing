#!/bin/bash

echo "========================================="
echo "Deploying Constraint Studio Component"
echo "========================================="
echo ""

# Step 1: Deploy the Label__c field
echo "Step 1: Deploying Label__c field..."
sfdx force:source:deploy -p force-app/main/default/objects/CMLSnippet__c/fields/Label__c.field-meta.xml
if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy Label__c field"
    exit 1
fi
echo "✅ Label__c field deployed successfully"
echo ""

# Step 2: Deploy the updated permission set
echo "Step 2: Deploying updated permission set..."
sfdx force:source:deploy -p force-app/main/default/permissionsets/CMLSnippet_Access.permissionset-meta.xml
if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy permission set"
    exit 1
fi
echo "✅ Permission set deployed successfully"
echo ""

# Step 3: Deploy the Apex controller
echo "Step 3: Deploying Apex controller..."
sfdx force:source:deploy -p force-app/main/default/classes/ConstraintStudioController.cls,force-app/main/default/classes/ConstraintStudioController.cls-meta.xml
if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy Apex controller"
    exit 1
fi
echo "✅ Apex controller deployed successfully"
echo ""

# Step 4: Deploy the LWC component
echo "Step 4: Deploying LWC component..."
sfdx force:source:deploy -p force-app/main/default/lwc/constraintStudio
if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy LWC component"
    exit 1
fi
echo "✅ LWC component deployed successfully"
echo ""

# Step 5: Deploy the updated layout
echo "Step 5: Deploying updated CMLSnippet layout..."
sfdx force:source:deploy -p "force-app/main/default/layouts/CMLSnippet__c-CML Snippet Layout.layout-meta.xml"
if [ $? -ne 0 ]; then
    echo "❌ Failed to deploy layout"
    exit 1
fi
echo "✅ Layout deployed successfully"
echo ""

echo "========================================="
echo "✅ All components deployed successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Assign the 'CML Snippet Access' permission set to your user"
echo "2. Navigate to a Product2 or ProductClassification record"
echo "3. Edit the page and add the 'Constraint Studio' component"
echo ""
