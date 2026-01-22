#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs PowerShell profile configuration files to the user's profile directory.

.DESCRIPTION
    Script-based installer using individual PowerShell scripts instead of modules.
    Downloads required installation scripts, executes setup, and installs profile.
    Works on Windows and macOS. Configuration driven by install-config.json.
    Software packages defined in profile JSON files (profiles/*.json).
    
    Architecture: SOLID, DRY, YAGNI, Idempotent
    - Each script has a single responsibility
    - Reusable scripts avoid duplication
    - No unnecessary complexity
    - Safe to run multiple times

.PARAMETER Profile
    Name of the software profile to install (default: from config's defaultProfile).
    Profiles are stored in profiles/<name>.json in Azure.

.PARAMETER No-Install
    When specified, skips software installation, Windows Updates, and Visual Studio installation.
    Only installs profile files, fonts, and terminal configuration.

.EXAMPLE
    ./install.ps1
    Downloads and installs software from default profile.

.EXAMPLE
    ./install.ps1 -Profile "dev-workstation"
    Installs software from the "dev-workstation" profile.

.EXAMPLE
    ./install.ps1 -No-Install
    Installs only profile files, fonts, and terminal configuration without software or updates.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Profile,
    
    [switch]${No-Install}
)

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
    
    # Load configuration
    $configScript = Join-Path $TempDir "Scripts/Utils/Get-ConfigFromAzure.ps1"
    $configPath = Join-Path $TempDir "install-config.json"
    $config = & $configScript -BaseUrl $AzureBaseUrl -LocalPath $configPath -FileName "install-config.json"
    
    # Determine profile name
    $profileName = if ($Profile) { $Profile } else { $config.defaultProfile }
    if (-not $profileName) { $profileName = "default" }
    
    Write-Host ""
    Write-Host "Platform: " -NoNewline
    Write-Host $platform.OS -ForegroundColor Yellow
    Write-Host "Profile: " -NoNewline
    Write-Host $profileName -ForegroundColor Yellow
    Write-Host "Installation Mode: " -NoNewline
    if (${No-Install}) {
        Write-Host "Profile-Only (skipping software and updates)" -ForegroundColor Yellow
    } else {
        Write-Host "Full Installation" -ForegroundColor Yellow
    }
    
    # Download and load profile
    Write-Host ""
    Write-Host "Downloading profile '$profileName'..." -ForegroundColor Cyan
    $profileUrl = "$AzureBaseUrl/profiles/$profileName.json?$cacheBuster"
    $profilePath = Join-Path $TempDir "profile.json"
    
    try {
        Invoke-WebRequest -Uri $profileUrl -OutFile $profilePath -ErrorAction Stop -UseBasicParsing
        $softwareProfile = Get-Content -Path $profilePath -Raw | ConvertFrom-Json
        Write-Host "  ✓ Profile loaded: $($softwareProfile.description)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to download profile '$profileName'" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        throw "Profile '$profileName' not found"
    }
    
    # Execute installation steps
    $scriptsRoot = Join-Path $TempDir "Scripts"
    
    # Initialize winget on Windows (triggers license acceptance before silent installs)
    if ($platform.IsWindows -and -not ${No-Install}) {
        Write-Host ""
        Write-Host "Initializing Windows Package Manager..." -ForegroundColor Cyan
        $null = winget list --source winget 2>&1 | Out-Null
        Write-Host "  ✓ winget ready" -ForegroundColor Green
    }
    
    # Install software (skip if -No-Install)
    if (${No-Install}) {
        Write-Host ""
        Write-Host "Skipping software installation (-No-Install specified)" -ForegroundColor Yellow
    } else {
        $installSoftwareScript = Join-Path $scriptsRoot "Install/Install-Software.ps1"
        & $installSoftwareScript -Platform $platform -Profile $softwareProfile -ScriptsRoot $scriptsRoot
    }
    
    # Install fonts (must be done before configuring terminal)
    $installFontsScript = Join-Path $scriptsRoot "Install/Install-Fonts.ps1"
    & $installFontsScript -Config $config

    if ($platform.IsWindows) {
        # Install Windows Updates and Store Updates (skip if -No-Install)
        if (${No-Install}) {
            Write-Host "Skipping Windows Updates (-No-Install specified)" -ForegroundColor Yellow
        } else {
            $installUpdatesScript = Join-Path $scriptsRoot "Install/Install-WindowsUpdates.ps1"
            & $installUpdatesScript
        }

        # Set Time Zone from profile
        $setTimeZoneScript = Join-Path $scriptsRoot "Install/Set-TimeZone.ps1"
        & $setTimeZoneScript -TimeZone $softwareProfile.timezone

        # Configure Windows Terminal
        $configureWTScript = Join-Path $scriptsRoot "Install/Configure-WindowsTerminal.ps1"
        & $configureWTScript
    }
    
    # Install profile files
    $installProfileScript = Join-Path $scriptsRoot "Profile/Install-ProfileFiles.ps1"
    & $installProfileScript -BaseUrl $AzureBaseUrl -Config $config -ScriptsRoot $scriptsRoot
    
    # Load profile
    Write-Host ""
    Write-Host "Running '. `$PROFILE'..." -ForegroundColor Cyan
    $profilePath = $global:PROFILE.CurrentUserAllHosts
    if ($profilePath -and (Test-Path $profilePath)) {
        . $profilePath
    }
    
    # Show footer
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Tip: " -NoNewline -ForegroundColor Cyan
    Write-Host "Configure your terminal to use the Meslo Nerd Font" -ForegroundColor White
}
catch {
    Write-Host ""
    Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}
finally {
    # Cleanup temporary directory
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
#endregion
