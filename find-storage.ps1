$ErrorActionPreference = 'Stop'
$env:AZURE_CLI_DISABLE_CONNECTION_VERIFICATION = 1
$StorageAccount = "stprofilewus3"

Write-Host "Searching for storage account '$StorageAccount'..."

$subs = az account list --query "[?state=='Enabled'].{id:id, name:name}" --output json | ConvertFrom-Json

foreach ($sub in $subs) {
    Write-Host "Checking subscription: $($sub.name) ($($sub.id))..." -NoNewline
    try {
        az account set --subscription $sub.id 2>$null
        $account = az storage account show --name $StorageAccount --query id --output tsv 2>$null
        if ($account) {
            Write-Host " FOUND!" -ForegroundColor Green
            Write-Host "Storage account found in subscription: $($sub.name)" -ForegroundColor Green
            Write-Host "Subscription ID: $($sub.id)" -ForegroundColor Green
            exit 0
        } else {
            Write-Host " Not found." -ForegroundColor Gray
        }
    } catch {
        Write-Host " Error checking." -ForegroundColor Red
    }
}

Write-Host "Storage account not found in any enabled subscription." -ForegroundColor Red
