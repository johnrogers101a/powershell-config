#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs PowerShell profile files and scripts to user profile directory.

.DESCRIPTION
    Creates profile directory if needed. Downloads and installs all profile files,
    script files, and the omp.json theme configuration. Overwrites existing files
    (no backups - idempotent approach). Uses Get-FileFromAzure for downloads.

.PARAMETER BaseUrl
    Azure Blob Storage base URL

.PARAMETER Config
    Configuration object with profileFiles and scriptFiles arrays

.PARAMETER ScriptsRoot
    Path to Scripts directory for sourcing Get-FileFromAzure

.EXAMPLE
    & "$PSScriptRoot/Install-ProfileFiles.ps1" -BaseUrl $baseUrl -Config $config -ScriptsRoot $scriptsRoot

.OUTPUTS
    None (prints status to console)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BaseUrl,
    
    [Parameter(Mandatory)]
    [PSCustomObject]$Config,
    
    [Parameter(Mandatory)]
    [string]$ScriptsRoot
)

$ErrorActionPreference = 'Stop'

$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts

Write-Host ""
Write-Host "Installing profile configuration..." -ForegroundColor Green
Write-Host "Target Directory: " -NoNewline
Write-Host $profileDir -ForegroundColor Yellow
Write-Host ""

# Create profile directory if it doesn't exist
if (-not (Test-Path $profileDir)) {
    Write-Host "Creating profile directory..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Get download script
$downloadScript = Join-Path $ScriptsRoot "Utils/Get-FileFromAzure.ps1"

# Install profile files (overwrite existing)
Write-Host "Installing profile files..." -ForegroundColor Cyan
foreach ($file in $Config.profileFiles) {
    $destPath = Join-Path $profileDir $file
    
    # Remove existing file if present
    if (Test-Path $destPath) {
        Remove-Item $destPath -Force -ErrorAction SilentlyContinue
    }
    
    $success = & $downloadScript -BaseUrl $BaseUrl -FileName $file -DestinationPath $destPath
    if (-not $success) {
        Write-Host "  Error: Failed to install $file" -ForegroundColor Red
    }
}

# Install script files
Write-Host ""
Write-Host "Installing scripts..." -ForegroundColor Cyan
foreach ($scriptPath in $Config.scriptFiles) {
    $destPath = Join-Path $profileDir $scriptPath
    $success = & $downloadScript -BaseUrl $BaseUrl -FileName $scriptPath -DestinationPath $destPath
    if (-not $success) {
        Write-Host "  Error: Failed to install $scriptPath" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "✓ Profile installation complete" -ForegroundColor Green
