#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Uploads PowerShell profile configuration files to Azure Blob Storage.

.DESCRIPTION
    This script uploads all profile files and modules to Azure Blob Storage,
    replacing existing files. Requires Azure CLI (az) to be installed and authenticated.

.EXAMPLE
    ./upload-to-azure.ps1
    Uploads all files to the configured Azure storage account.
#>

[CmdletBinding()]
param()

# Azure Storage configuration
$StorageAccount = "stprofilewus3"
$ContainerName = "profile-config"

# Files to upload from root directory
$FilesToUpload = @(
    "install.ps1"
    "upload.ps1"
    "Microsoft.PowerShell_profile.ps1"
    "Microsoft.VSCode_profile.ps1"
    "omp.json"
)

# Module files to upload (with relative paths)
$ModuleFiles = @(
    "Modules/ProfileSetup/ProfileSetup.psm1"
)

Write-Host ""
Write-Host "Azure Blob Storage Upload Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Storage Account: " -NoNewline
Write-Host $StorageAccount -ForegroundColor Yellow
Write-Host "Container: " -NoNewline
Write-Host $ContainerName -ForegroundColor Yellow
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

# Get script directory
$ScriptDir = $PSScriptRoot

# Upload root files
Write-Host "Uploading profile files..." -ForegroundColor Green
foreach ($File in $FilesToUpload) {
    $FilePath = Join-Path $ScriptDir $File
    
    if (Test-Path $FilePath) {
        Write-Host "  Uploading $File..." -ForegroundColor Cyan
        
        try {
            az storage blob upload `
                --account-name $StorageAccount `
                --container-name $ContainerName `
                --name $File `
                --file $FilePath `
                --overwrite `
                --auth-mode login `
                --only-show-errors | Out-Null
            
            Write-Host "    ✓ Uploaded successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "    ✗ Failed to upload: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  Warning: $File not found, skipping" -ForegroundColor Yellow
    }
}

# Upload module files
Write-Host ""
Write-Host "Uploading modules..." -ForegroundColor Green
foreach ($ModulePath in $ModuleFiles) {
    $FilePath = Join-Path $ScriptDir $ModulePath
    
    if (Test-Path $FilePath) {
        Write-Host "  Uploading $ModulePath..." -ForegroundColor Cyan
        
        try {
            az storage blob upload `
                --account-name $StorageAccount `
                --container-name $ContainerName `
                --name $ModulePath `
                --file $FilePath `
                --overwrite `
                --auth-mode login `
                --only-show-errors | Out-Null
            
            Write-Host "    ✓ Uploaded successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "    ✗ Failed to upload: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  Warning: $ModulePath not found, skipping" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Upload complete!" -ForegroundColor Green
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
    --auth-mode login 2>$null

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
