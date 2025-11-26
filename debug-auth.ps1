$ErrorActionPreference = 'Stop'
$env:AZURE_CLI_DISABLE_CONNECTION_VERIFICATION = 1
$StorageAccount = "stprofilewus3"
$SubscriptionId = "230b4919-042f-4736-baaf-16091a325dd3" # 4JS

Write-Host "Setting subscription to $SubscriptionId..."
az account set --subscription $SubscriptionId

Write-Host "Testing key retrieval..."
try {
    $keys = az storage account keys list --account-name $StorageAccount --output json | ConvertFrom-Json
    if ($keys) {
        Write-Host "Successfully retrieved keys." -ForegroundColor Green
    } else {
        Write-Host "Failed to retrieve keys (empty result)." -ForegroundColor Red
    }
} catch {
    Write-Host "Failed to retrieve keys: $_" -ForegroundColor Red
}

