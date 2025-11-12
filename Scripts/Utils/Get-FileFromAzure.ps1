#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Downloads a file from Azure Blob Storage with cache-busting.

.DESCRIPTION
    Downloads a file from Azure Blob Storage to a local destination path.
    Uses cache-busting timestamp to ensure latest version is downloaded.
    Creates parent directories if they don't exist (idempotency).

.PARAMETER BaseUrl
    Azure Blob Storage base URL (e.g., https://account.blob.core.windows.net/container)

.PARAMETER FileName
    Relative path of file to download from Azure

.PARAMETER DestinationPath
    Local file system path where file should be saved

.EXAMPLE
    $success = & "$PSScriptRoot/Get-FileFromAzure.ps1" -BaseUrl "https://..." -FileName "config.json" -DestinationPath "C:\temp\config.json"

.OUTPUTS
    Boolean indicating success or failure
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,
    
    [Parameter(Mandatory)]
    [string]$FileName,
    
    [Parameter(Mandatory)]
    [string]$DestinationPath
)

$ErrorActionPreference = 'Stop'

Write-Host "  Downloading $FileName..." -ForegroundColor Cyan

try {
    # Add cache buster to URL
    $cacheBuster = "v=$(Get-Date -Format 'yyyyMMddHHmmss')"
    $url = "$BaseUrl/$FileName`?$cacheBuster"
    
    # Ensure parent directory exists
    $parentDir = Split-Path -Parent $DestinationPath
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    
    # Download file with no cache
    Invoke-WebRequest -Uri $url -OutFile $DestinationPath -ErrorAction Stop -UseBasicParsing
    
    Write-Host "    Downloaded successfully" -ForegroundColor Green
    return $true
}
catch {
    Write-Host "    Failed to download: $($_.Exception.Message)" -ForegroundColor Red
    return $false
}
