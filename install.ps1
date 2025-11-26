#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs PowerShell profile configuration files to the user's profile directory.

.DESCRIPTION
    Script-based installer using individual PowerShell scripts instead of modules.
    Downloads required installation scripts, executes setup, and installs profile.
    Works on Windows and macOS. Configuration driven by install-config.json.
    
    Architecture: SOLID, DRY, YAGNI, Idempotent
    - Each script has a single responsibility
    - Reusable scripts avoid duplication
    - No unnecessary complexity
    - Safe to run multiple times

.EXAMPLE
    ./install.ps1
    Downloads and installs software and profile files to default PowerShell profile location.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

#region Configuration
$AzureBaseUrl = "https://stprofilewus3.blob.core.windows.net/profile-config"
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "powershell-profile-setup-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Core installation scripts needed for bootstrap
$ScriptsToDownload = @(
    "install-config.json"
    "Scripts/Core/Get-PlatformInfo.ps1"
    "Scripts/Utils/Get-FileFromAzure.ps1"
    "Scripts/Utils/Get-ConfigFromAzure.ps1"
    "Scripts/Install/Install-WithWinGet.ps1"
    "Scripts/Install/Install-WithBrew.ps1"
    "Scripts/Install/Install-Software.ps1"
    "Scripts/Install/Install-WindowsUpdates.ps1"
    "Scripts/Install/Set-TimeZone.ps1"
    "Scripts/Install/Configure-WindowsTerminal.ps1"
    "Scripts/Install/Install-VisualStudio.ps1"
    "Scripts/Install/Install-Fonts.ps1"
    "Scripts/Profile/Install-ProfileFiles.ps1"
)
#endregion

#region Show Header
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PowerShell Profile Configuration Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
#endregion

#region Download Bootstrap Scripts
Write-Host "Creating temporary directory..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
Write-Host "  Location: $TempDir" -ForegroundColor Yellow

$cacheBuster = "v=$(Get-Date -Format 'yyyyMMddHHmmss')"

Write-Host ""
Write-Host "Downloading installation scripts..." -ForegroundColor Cyan
Write-Host "  Cache buster: $cacheBuster" -ForegroundColor Gray

foreach ($file in $ScriptsToDownload) {
    $url = "$AzureBaseUrl/$file`?$cacheBuster"
    $destination = Join-Path $TempDir $file
    $destinationDir = Split-Path -Parent $destination
    
    if (-not (Test-Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }
    
    Write-Host "  Downloading $file..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop -UseBasicParsing
    }
    catch {
        Write-Host "  ✗ Failed to download $file" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }
}

Write-Host "  ✓ All scripts downloaded successfully" -ForegroundColor Green
#endregion

#region Execute Installation
try {
    # Get platform info
    $platformScript = Join-Path $TempDir "Scripts/Core/Get-PlatformInfo.ps1"
    $platform = & $platformScript
    
    Write-Host ""
    Write-Host "Platform: " -NoNewline
    Write-Host $platform.OS -ForegroundColor Yellow
    Write-Host "Installation Mode: " -NoNewline
    Write-Host "Cloud (Azure Blob Storage)" -ForegroundColor Yellow
    
    # Load configuration
    $configScript = Join-Path $TempDir "Scripts/Utils/Get-ConfigFromAzure.ps1"
    $configPath = Join-Path $TempDir "install-config.json"
    $config = & $configScript -BaseUrl $AzureBaseUrl -LocalPath $configPath -FileName "install-config.json"
    
    # Execute installation steps
    $scriptsRoot = Join-Path $TempDir "Scripts"
    
    # Install software
    $installSoftwareScript = Join-Path $scriptsRoot "Install/Install-Software.ps1"
    & $installSoftwareScript -Platform $platform -Config $config -ScriptsRoot $scriptsRoot
    
    # Install fonts (must be done before configuring terminal)
    $installFontsScript = Join-Path $scriptsRoot "Install/Install-Fonts.ps1"
    & $installFontsScript -Config $config

    if ($platform.IsWindows) {
        # Install Windows Updates and Store Updates
        $installUpdatesScript = Join-Path $scriptsRoot "Install/Install-WindowsUpdates.ps1"
        & $installUpdatesScript

        # Set Time Zone
        $setTimeZoneScript = Join-Path $scriptsRoot "Install/Set-TimeZone.ps1"
        & $setTimeZoneScript

        # Configure Windows Terminal
        $configureWTScript = Join-Path $scriptsRoot "Install/Configure-WindowsTerminal.ps1"
        & $configureWTScript
    }

    # Install Visual Studio (Windows only)
    $installVSScript = Join-Path $scriptsRoot "Install/Install-VisualStudio.ps1"
    & $installVSScript -Platform $platform
    
    # Install profile files
    $installProfileScript = Join-Path $scriptsRoot "Profile/Install-ProfileFiles.ps1"
    & $installProfileScript -BaseUrl $AzureBaseUrl -Config $config -ScriptsRoot $scriptsRoot
    
    # Load profile
    Write-Host ""
    Write-Host "Loading profile..." -ForegroundColor Cyan
    try {
        . $global:PROFILE.CurrentUserAllHosts
        Write-Host "Profile loaded successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Note: Profile will be loaded when you start a new PowerShell session." -ForegroundColor Yellow
    }
    
    # Show footer
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Restart your terminal or run: " -NoNewline
    Write-Host ". `$PROFILE" -ForegroundColor Yellow
    Write-Host "  2. Configure your terminal to use the Meslo Nerd Font" -ForegroundColor White
    Write-Host ""
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
