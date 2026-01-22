#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Publishes a software profile to Azure Blob Storage.

.DESCRIPTION
    Uploads a profile JSON to Azure and updates the profiles-index.json.
    Requires Azure CLI authentication.

.PARAMETER Name
    Name of the profile to publish

.PARAMETER ProfilesPath
    Path to local profiles directory (default: profiles/ in repo root)

.EXAMPLE
    Publish-Profile -Name "my-workstation"

.OUTPUTS
    None
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,
    
    [Parameter()]
    [string]$ProfilesPath
)

$ErrorActionPreference = 'Stop'

$StorageAccount = "stprofilewus3"
$ContainerName = "profile-config"

# Determine profiles path
if (-not $ProfilesPath) {
    $ProfilesPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "profiles"
}

$profileFile = Join-Path $ProfilesPath "$Name.json"

if (-not (Test-Path $profileFile)) {
    throw "Profile '$Name' not found at $profileFile. Use New-Profile to create it first."
}

# Check Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is not installed. Please install it from: https://aka.ms/install-az"
}

# Check authentication
Write-Host "Checking Azure authentication..." -ForegroundColor Cyan
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    throw "Not logged in to Azure. Please run: az login"
}
Write-Host "  Authenticated as: $($account.user.name)" -ForegroundColor Green

# Load profile to get metadata
$profile = Get-Content -Path $profileFile -Raw | ConvertFrom-Json

# Upload profile
Write-Host ""
Write-Host "Uploading profile '$Name'..." -ForegroundColor Cyan
$blobName = "profiles/$Name.json"

$result = az storage blob upload `
    --account-name $StorageAccount `
    --container-name $ContainerName `
    --name $blobName `
    --file $profileFile `
    --overwrite `
    --auth-mode key `
    --only-show-errors 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "Failed to upload profile: $result"
}
Write-Host "  ✓ Uploaded $blobName" -ForegroundColor Green

# Update profiles-index.json
Write-Host ""
Write-Host "Updating profiles index..." -ForegroundColor Cyan

$indexBlobName = "profiles/profiles-index.json"
$tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "profiles-index-$(Get-Date -Format 'yyyyMMddHHmmss').json"

# Download current index (or create new one)
$null = az storage blob download `
    --account-name $StorageAccount `
    --container-name $ContainerName `
    --name $indexBlobName `
    --file $tempFile `
    --auth-mode key `
    --only-show-errors 2>&1

if (Test-Path $tempFile) {
    $index = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
}
else {
    $index = @{ profiles = @() }
}

# Ensure profiles is an array
if (-not $index.profiles) {
    $index.profiles = @()
}

# Update or add profile entry
$existingIndex = -1
for ($i = 0; $i -lt $index.profiles.Count; $i++) {
    if ($index.profiles[$i].name -eq $Name) {
        $existingIndex = $i
        break
    }
}

$profileEntry = @{
    name = $profile.name
    description = $profile.description
    updatedAt = $profile.updatedAt
}

if ($existingIndex -ge 0) {
    $index.profiles[$existingIndex] = $profileEntry
}
else {
    $index.profiles = @($index.profiles) + $profileEntry
}

# Upload updated index
$index | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Encoding UTF8

$result = az storage blob upload `
    --account-name $StorageAccount `
    --container-name $ContainerName `
    --name $indexBlobName `
    --file $tempFile `
    --overwrite `
    --auth-mode key `
    --only-show-errors 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "Failed to upload index: $result"
}

Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
Write-Host "  ✓ Updated profiles index" -ForegroundColor Green

Write-Host ""
Write-Host "Profile '$Name' published successfully!" -ForegroundColor Green
Write-Host "URL: https://$StorageAccount.blob.core.windows.net/$ContainerName/profiles/$Name.json" -ForegroundColor Gray
