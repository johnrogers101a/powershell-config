#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs required software based on platform and configuration.

.DESCRIPTION
    Reads software list from configuration for current platform.
    Delegates to platform-specific installer scripts (Install-WithWinGet or Install-WithBrew).
    Idempotent - skips already installed packages.

.PARAMETER Platform
    Platform object with OS, IsWindows, IsMacOS properties

.PARAMETER Config
    Configuration object with software.windows and software.macos arrays

.PARAMETER ScriptsRoot
    Root path to Scripts directory

.EXAMPLE
    & "$PSScriptRoot/Install-Software.ps1" -Platform $platform -Config $config -ScriptsRoot $scriptsRoot

.OUTPUTS
    None (prints status to console)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Platform,
    
    [Parameter(Mandatory)]
    [PSCustomObject]$Config,
    
    [Parameter(Mandatory)]
    [string]$ScriptsRoot
)

$ErrorActionPreference = 'Stop'

# Get software list for current platform
$softwareList = $Config.software.($Platform.OS)

if (-not $softwareList) {
    Write-Host "No software configuration found for $($Platform.OS)" -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "Checking required software..." -ForegroundColor Green
Write-Host ""

# Get list of installed software once
$installedSoftware = @{}
if ($Platform.IsWindows) {
    # We will check each package individually in Install-WithWinGet.ps1
    # because parsing 'winget list' output is fragile due to variable column widths and spaces in names.
    Write-Host "Using direct package checks for Windows..." -ForegroundColor Cyan
} else {
    Write-Host "Getting installed software list (brew)..." -ForegroundColor Cyan
    $brewList = brew list 2>$null
    foreach ($pkg in $brewList) {
        $installedSoftware[$pkg.Trim()] = $true
    }
    Write-Host "  Found $($installedSoftware.Count) installed packages" -ForegroundColor Green
}

Write-Host ""

# Select appropriate installer script
$installerScript = if ($Platform.IsWindows) {
    Join-Path $ScriptsRoot "Install/Install-WithWinGet.ps1"
} else {
    Join-Path $ScriptsRoot "Install/Install-WithBrew.ps1"
}

# Install each package
foreach ($package in $softwareList) {
    $null = & $installerScript -Package $package -InstalledSoftware $installedSoftware
}
