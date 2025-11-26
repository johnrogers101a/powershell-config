#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Uploads all repository files to Azure Blob Storage.

.DESCRIPTION
    Recursively uploads all files in the repository to Azure Blob Storage,
    preserving directory structure. Skips .git directory and README.md.
    Requires Azure CLI (az) to be installed and authenticated.
    
    Idempotent - overwrites existing files to ensure latest versions.

.PARAMETER ExcludePatterns
    Array of patterns to exclude from upload (default: .git, README.md)

.EXAMPLE
    ./upload.ps1
    Uploads all repository files to the configured Azure storage account.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$ExcludePatterns = @('.git', 'README.md')
)

$ErrorActionPreference = 'Stop'

# Disable SSL verification for Azure CLI to handle corporate proxies
$env:AZURE_CLI_DISABLE_CONNECTION_VERIFICATION = 1

# Azure Storage configuration
$StorageAccount = "stprofilewus3"
$ContainerName = "profile-config"
$SubscriptionId = "230b4919-042f-4736-baaf-16091a325dd3" # 4JS

Write-Host ""
Write-Host "Azure Blob Storage Upload Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Storage Account: " -NoNewline
Write-Host $StorageAccount -ForegroundColor Yellow
Write-Host "Container: " -NoNewline
Write-Host $ContainerName -ForegroundColor Yellow
Write-Host "Subscription: " -NoNewline
Write-Host $SubscriptionId -ForegroundColor Yellow
Write-Host ""

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Azure CLI (az) is not installed." -ForegroundColor Red
    Write-Host "Please install it from: https://aka.ms/install-az" -ForegroundColor Yellow
    exit 1
}

# Check if logged in to Azure
Write-Host "Checking Azure authentication..." -ForegroundColor Cyan
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Error: Not logged in to Azure." -ForegroundColor Red
    Write-Host "Please run: az login" -ForegroundColor Yellow
    exit 1
}

Write-Host "  ✓ Authenticated as: " -NoNewline -ForegroundColor Green
Write-Host $account.user.name -ForegroundColor White
Write-Host ""

# Set the correct subscription
Write-Host "Setting Azure subscription context..." -ForegroundColor Cyan
try {
    az account set --subscription $SubscriptionId
    Write-Host "  ✓ Subscription set to 4JS ($SubscriptionId)" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed to set subscription: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Check if storage account exists and is accessible
Write-Host "Checking access to storage account '$StorageAccount'..." -ForegroundColor Cyan
$storageId = az storage account show --name $StorageAccount --query id --output tsv 2>$null

if (-not $storageId) {
    Write-Host "Error: Storage account '$StorageAccount' not found in current subscriptions." -ForegroundColor Red
    Write-Host "Current user: $($account.user.name)" -ForegroundColor Yellow
    Write-Host "Please login to the account/tenant that owns this storage account." -ForegroundColor Yellow
    Write-Host "Command: az login" -ForegroundColor White
    exit 1
}

Write-Host "  ✓ Storage account found" -ForegroundColor Green
Write-Host ""

# Get script directory (repository root)
$RepoRoot = $PSScriptRoot

# Get all files recursively, excluding specified patterns
Write-Host "Scanning repository for files..." -ForegroundColor Cyan
$allFiles = Get-ChildItem -Path $RepoRoot -File -Recurse | Where-Object {
    $relativePath = $_.FullName.Substring($RepoRoot.Length + 1)
    $shouldExclude = $false
    
    foreach ($pattern in $ExcludePatterns) {
        if ($relativePath -like "*$pattern*" -or $_.Name -eq $pattern) {
            $shouldExclude = $true
            break
        }
    }
    
    -not $shouldExclude
}

$totalFiles = $allFiles.Count
Write-Host "  Found $totalFiles files to upload" -ForegroundColor Yellow
Write-Host ""

# Upload each file
$uploadedCount = 0
$failedCount = 0

Write-Host "Uploading files..." -ForegroundColor Green
foreach ($file in $allFiles) {
    # Get relative path for blob name
    $relativePath = $file.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
    
    Write-Host "  Uploading $relativePath..." -ForegroundColor Cyan
    
    try {
        az storage blob upload `
            --account-name $StorageAccount `
            --container-name $ContainerName `
            --name $relativePath `
            --file $file.FullName `
            --overwrite `
            --auth-mode key `
            --only-show-errors | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI exited with code $LASTEXITCODE"
        }
        
        Write-Host "    ✓ Uploaded successfully" -ForegroundColor Green
        $uploadedCount++
    }
    catch {
        Write-Host "    ✗ Failed to upload: $_" -ForegroundColor Red
        $failedCount++
    }
}

Write-Host ""
Write-Host "Upload Summary:" -ForegroundColor Cyan
Write-Host "  Total files: $totalFiles" -ForegroundColor White
Write-Host "  Uploaded: " -NoNewline
Write-Host $uploadedCount -ForegroundColor Green
Write-Host "  Failed: " -NoNewline
Write-Host $failedCount -ForegroundColor $(if ($failedCount -gt 0) { "Red" } else { "Green" })
Write-Host ""
Write-Host "Files are now available at:" -ForegroundColor Cyan
Write-Host "https://$StorageAccount.blob.core.windows.net/$ContainerName/" -ForegroundColor White
Write-Host ""

# Verify container is public
Write-Host "Verifying container public access..." -ForegroundColor Cyan
$publicAccess = az storage container show `
    --account-name $StorageAccount `
    --name $ContainerName `
    --query "properties.publicAccess" `
    --output tsv `
    --auth-mode key 2>$null

if ($publicAccess -eq "blob") {
    Write-Host "  ✓ Container has public blob access enabled" -ForegroundColor Green
}
elseif ($publicAccess -eq "container") {
    Write-Host "  ✓ Container has public container access enabled" -ForegroundColor Green
}
else {
    Write-Host "  ⚠ Warning: Container does not have public access enabled" -ForegroundColor Yellow
    Write-Host "  Run this command to enable it:" -ForegroundColor Yellow
    Write-Host "  az storage container set-permission --name $ContainerName --account-name $StorageAccount --public-access blob" -ForegroundColor White
}

Write-Host ""

# Exit with appropriate code
exit $(if ($failedCount -eq 0) { 0 } else { 1 })
