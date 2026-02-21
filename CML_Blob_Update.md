## How the BLOB is Accessed

Based on the code (specifically lines 88-130), here's what I found:

### __Reading the BLOB:__

1. __Query the ExpressionSetDefinitionVersion__ - The `ConstraintModel` field contains a URL path to the BLOB:

   ```sql
   SELECT ConstraintModel, DeveloperName, VersionNumber, ...
   FROM ExpressionSetDefinitionVersion
   WHERE ExpressionSetDefinition.DeveloperName = 'YourName'
   ```

2. __The ConstraintModel field returns a URL path__ like `/services/data/vXX.0/sobjects/ExpressionSetDefinitionVersion/{Id}/ConstraintModel`

3. __Download the BLOB via REST API__ (lines 88-130):

   - Get an access token from Salesforce CLI or OAuth
   - Make a GET request to: `{instanceUrl} + {ConstraintModel URL path}`
   - The response body contains the raw BLOB data
   - Save it as a `.ffxblob` file

### __Updating the BLOB:__

To update the BLOB programmatically, you would:

1. __Use the REST API PATCH/POST method__ to the same endpoint
2. __Send the binary data__ in the request body with proper headers
3. __The endpoint pattern is__: `{instanceUrl}/services/data/v{version}/sobjects/ExpressionSetDefinitionVersion/{recordId}/ConstraintModel`

## Key Code Snippet from the Utility

```python
# Line 88-130: The download_constraint_model_blobs function
blob_url = row.get("ConstraintModel", "")  # e.g., "/services/data/v62.0/sobjects/..."
full_url = instance_url + blob_url
resp = requests.get(full_url, headers={"Authorization": f"Bearer {access_token}"})
if resp.status_code == 200:
    with open(file_path, "wb") as out_file:
        out_file.write(resp.content)  # Binary BLOB data
```
