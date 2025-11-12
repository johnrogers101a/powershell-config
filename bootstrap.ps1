#!/usr/bin/env powershell
<#
.SYNOPSIS
    Bootstrap script for PowerShell profile installation - works with PowerShell 5.1+

.DESCRIPTION
    Checks PowerShell version, installs PowerShell 7+ if needed (Windows only), 
    then executes the main installer. Designed to work on fresh Windows installs.

.EXAMPLE
    irm https://stprofilewus3.blob.core.windows.net/profile-config/bootstrap.ps1 | iex
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

#region Check PowerShell Version
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PowerShell Profile Bootstrap v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Current PowerShell version: " -NoNewline
Write-Host "$($PSVersionTable.PSVersion)" -ForegroundColor Yellow
Write-Host ""

# Check if we're already running PowerShell 7+
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "✓ PowerShell 7+ detected, proceeding with installation..." -ForegroundColor Green
    
    # Download and execute main installer with cache busting
    $cacheBuster = "v=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
    $installerUrl = "https://stprofilewus3.blob.core.windows.net/profile-config/install.ps1?$cacheBuster"
    
    Write-Host "Downloading main installer..." -ForegroundColor Cyan
    $installer = (New-Object System.Net.WebClient).DownloadString($installerUrl)
    
    Write-Host "Executing installer..." -ForegroundColor Cyan
    Write-Host ""
    Invoke-Expression $installer
    exit 0
}
#endregion

#region Install PowerShell 7+ on Windows
Write-Host "PowerShell 5.x detected. Installing PowerShell 7+ is recommended." -ForegroundColor Yellow
Write-Host ""

# Check if we're on Windows
if ($PSVersionTable.PSVersion.Major -eq 5 -and $null -eq $PSVersionTable.Platform) {
    Write-Host "Detected: Windows with PowerShell 5.x" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if winget is available
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Host "✗ winget not found. Please install App Installer from Microsoft Store." -ForegroundColor Red
        Write-Host "  After installing, run this script again." -ForegroundColor Yellow
        exit 1
    }
    
    # Check if pwsh is already installed
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) {
        Write-Host "✓ PowerShell 7+ is already installed" -ForegroundColor Green
    }
    else {
        Write-Host "Installing PowerShell 7+..." -ForegroundColor Yellow
        Write-Host "  This may take a moment..." -ForegroundColor Gray
        
        winget install --id Microsoft.PowerShell --exact --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ PowerShell 7+ installed successfully" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Failed to install PowerShell 7+" -ForegroundColor Red
            Write-Host "  Exit code: $LASTEXITCODE" -ForegroundColor Red
            exit 1
        }
    }
    
    Write-Host ""
    Write-Host "Launching installer in PowerShell 7+..." -ForegroundColor Cyan
    Write-Host ""
    
    # Launch pwsh with the main installer
    $cacheBuster = "v=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
    $installerUrl = "https://stprofilewus3.blob.core.windows.net/profile-config/install.ps1?$cacheBuster"
    
    $pwshCommand = "iex ((New-Object System.Net.WebClient).DownloadString('$installerUrl'))"
    
    # Start pwsh in a new process
    Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $pwshCommand -Wait -NoNewWindow
    
    Write-Host ""
    Write-Host "Installation complete!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Unsupported platform or PowerShell version" -ForegroundColor Red
    Write-Host "  This script requires Windows with PowerShell 5.1+ or PowerShell 7+" -ForegroundColor Yellow
    exit 1
}
#endregion
