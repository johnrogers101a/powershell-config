#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Removes a software profile from Azure Blob Storage.

.DESCRIPTION
    Deletes a profile JSON from Azure and updates the profiles-index.json.
    Requires Azure CLI authentication.

.PARAMETER Name
    Name of the profile to remove

.PARAMETER Force
    Skip confirmation prompt

.EXAMPLE
    Remove-Profile -Name "old-profile"
    Remove-Profile -Name "old-profile" -Force

.OUTPUTS
    None
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,
    
    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Prevent deleting default profile
if ($Name -eq "default") {
    throw "Cannot remove the 'default' profile"
}

$StorageAccount = "stprofilewus3"
$ContainerName = "profile-config"

# Check Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is not installed. Please install it from: https://aka.ms/install-az"
}

# Check authentication
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    throw "Not logged in to Azure. Please run: az login"
}

# Confirm deletion
if (-not $Force) {
    Write-Host "Are you sure you want to delete profile '$Name'? " -NoNewline -ForegroundColor Yellow
    Write-Host "(y/N): " -NoNewline
    $response = Read-Host
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Cancelled" -ForegroundColor Gray
        return
    }
}

Write-Host "Removing profile '$Name'..." -ForegroundColor Cyan

# Delete the profile blob
$blobName = "profiles/$Name.json"
$result = az storage blob delete `
    --account-name $StorageAccount `
    --container-name $ContainerName `
    --name $blobName `
    --auth-mode key `
    --only-show-errors 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not delete blob (may not exist): $result"
}
else {
    Write-Host "  Deleted $blobName" -ForegroundColor Green
}

# Update profiles-index.json
Write-Host "Updating profiles index..." -ForegroundColor Cyan

$indexBlobName = "profiles/profiles-index.json"
$tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "profiles-index-$(Get-Date -Format 'yyyyMMddHHmmss').json"

# Download current index
$null = az storage blob download `
    --account-name $StorageAccount `
    --container-name $ContainerName `
    --name $indexBlobName `
    --file $tempFile `
    --auth-mode key `
    --only-show-errors 2>&1

if (Test-Path $tempFile) {
    $index = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
    
    # Remove the profile entry
    $index.profiles = @($index.profiles | Where-Object { $_.name -ne $Name })
    
    # Upload updated index
    $index | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Encoding UTF8
    
    $null = az storage blob upload `
        --account-name $StorageAccount `
        --container-name $ContainerName `
        --name $indexBlobName `
        --file $tempFile `
        --overwrite `
        --auth-mode key `
        --only-show-errors 2>&1
    
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    Write-Host "  Updated profiles index" -ForegroundColor Green
}

Write-Host ""
Write-Host "Profile '$Name' removed successfully" -ForegroundColor Green
