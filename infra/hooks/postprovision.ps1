#!/usr/bin/env pwsh

azd env get-values > .env

# Retrieve the internalId of the Cognitive Services account
$INTERNAL_ID = az cognitiveservices account show `
    --name $env:AZURE_OPENAI_NAME `
    -g $env:AZURE_RESOURCE_GROUP `
    --query "properties.internalId" -o tsv

# Construct the URL
$COGNITIVE_SERVICE_URL = "https://oai.azure.com/portal/${INTERNAL_ID}?tenantid=${env:AZURE_TENANT_ID}"

Write-Host "--- ✅ | 1. Post-provisioning - env configured ---"

# Setup to run notebooks
Write-Host 'Installing dependencies from "src/api/requirements.txt"'
python -m pip install -r src/api/requirements.txt *> $null
python -m pip install ipython ipykernel *> $null
ipython kernel install --name=python3 --user *> $null
jupyter kernelspec list *> $null
Write-Host "--- ✅ | 2. Post-provisioning - ready execute notebooks ---"

Write-Host "Populating data ...."
jupyter nbconvert --execute --to python --ExecutePreprocessor.timeout=-1 data/create-azure-search.ipynb *> $null

Write-Host "--- ✅ | 3. Post-provisioning - populated data ---"
