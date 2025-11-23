#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Loads configuration from local file or Azure Blob Storage.

.DESCRIPTION
    Attempts to load configuration from local path first (for development).
    If local file doesn't exist, downloads from Azure Blob Storage.
    Returns parsed JSON object. Idempotent - same config produces same result.

.PARAMETER BaseUrl
    Azure Blob Storage base URL (e.g., https://account.blob.core.windows.net/container)

.PARAMETER LocalPath
    Local file system path to check first

.PARAMETER FileName
    Name of configuration file (used for Azure download if local not found)

.EXAMPLE
    $config = & "$PSScriptRoot/Get-ConfigFromAzure.ps1" -BaseUrl "https://..." -LocalPath "./config.json" -FileName "config.json"

.OUTPUTS
    PSCustomObject parsed from JSON configuration file
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,
    
    [Parameter(Mandatory)]
    [string]$LocalPath,
    
    [Parameter(Mandatory)]
    [string]$FileName
)

$ErrorActionPreference = 'Stop'

# Check local path first
if (Test-Path $LocalPath) {
    Write-Host "Loading configuration from local file..." -ForegroundColor Cyan
    return Get-Content $LocalPath -Raw | ConvertFrom-Json
}

# Download from Azure
Write-Host "Downloading configuration from Azure..." -ForegroundColor Cyan
$tempConfig = Join-Path ([System.IO.Path]::GetTempPath()) $FileName

# Download using Get-FileFromAzure script
$downloadScript = Join-Path $PSScriptRoot "Get-FileFromAzure.ps1"
$success = & $downloadScript -BaseUrl $BaseUrl -FileName $FileName -DestinationPath $tempConfig

if ($success) {
    return Get-Content $tempConfig -Raw | ConvertFrom-Json
}
else {
    throw "Failed to load configuration file"
}
