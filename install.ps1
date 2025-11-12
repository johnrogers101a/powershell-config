#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs PowerShell profile configuration files to the user's profile directory.

.DESCRIPTION
    This script downloads all required files to a temporary directory, loads the 
    installation modules, and executes the installation process. Works on Windows 
    and macOS. Configuration is driven by install-config.json.

.EXAMPLE
    ./install.ps1
    Downloads and installs the software and profile files to the default PowerShell profile location.
#>

[CmdletBinding()]
param()

#region Configuration
$AzureBaseUrl = "https://stprofilewus3.blob.core.windows.net/profile-config"
$TempDir = Join-Path $env:TEMP "powershell-profile-setup-$(Get-Date -Format 'yyyyMMddHHmmss')"

$FilesToDownload = @(
    "install-config.json"
    "Modules/ProfileSetup/PlatformInfo.psm1"
    "Modules/ProfileSetup/FileManager.psm1"
    "Modules/ProfileSetup/PackageManager.psm1"
    "Modules/ProfileSetup/SoftwareInstaller.psm1"
    "Modules/ProfileSetup/ProfileInstallerClass.psm1"
    "Modules/ProfileSetup/Installer.psm1"
)
#endregion

#region Download Files
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PowerShell Profile Setup - Bootstrap" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Creating temporary directory..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
Write-Host "  Location: $TempDir" -ForegroundColor Yellow

Write-Host ""
Write-Host "Downloading installation files..." -ForegroundColor Cyan

foreach ($file in $FilesToDownload) {
    $url = "$AzureBaseUrl/$file"
    $destination = Join-Path $TempDir $file
    $destinationDir = Split-Path -Parent $destination
    
    # Create subdirectories if needed
    if (-not (Test-Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }
    
    Write-Host "  Downloading $file..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
    }
    catch {
        Write-Host "  ✗ Failed to download $file" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }
}

Write-Host "  ✓ All files downloaded successfully" -ForegroundColor Green
#endregion

#region Load and Execute
Write-Host ""
Write-Host "Loading installation module..." -ForegroundColor Cyan
Write-Host "  [Bootstrap v3.0 - Force Module Reload]" -ForegroundColor Magenta

try {
    # Remove any cached versions of the modules first
    $modulePath = Join-Path $TempDir "Modules/ProfileSetup"
    $moduleFiles = Get-ChildItem -Path $modulePath -Filter "*.psm1" | Select-Object -ExpandProperty BaseName
    
    $removedCount = 0
    foreach ($mod in $moduleFiles) {
        if (Get-Module -Name $mod) {
            Remove-Module -Name $mod -Force -ErrorAction SilentlyContinue
            $removedCount++
        }
    }
    
    if ($removedCount -gt 0) {
        Write-Host "  Cleared $removedCount cached module(s)" -ForegroundColor Yellow
    } else {
        Write-Host "  No cached modules found (clean state)" -ForegroundColor Gray
    }
    
    # Import the main installer module with force reload
    $installerModule = Join-Path $TempDir "Modules/ProfileSetup/Installer.psm1"
    Import-Module $installerModule -Force -ErrorAction Stop
    
    Write-Host "  ✓ Module loaded successfully" -ForegroundColor Green
    
    # Execute the installation
    Invoke-Install -AzureBaseUrl $AzureBaseUrl -TempDirectory $TempDir
}
catch {
    Write-Host ""
    Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}
finally {
    # Cleanup temporary directory
    Write-Host ""
    Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Cleanup complete" -ForegroundColor Green
}
#endregion
