#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs a package using Windows Package Manager (winget).

.DESCRIPTION
    Checks if package is already installed using pre-fetched list (idempotent).
    Installs package if not present. Returns success status.

.PARAMETER Package
    Package configuration object with properties: name, packageId, installArgs, command

.PARAMETER InstalledSoftware
    Hashtable of already installed software (packageId -> $true)

.EXAMPLE
    $package = @{ name = "Git"; packageId = "Git.Git"; installArgs = @("-e", "--id", "Git.Git"); command = "git" }
    $success = & "$PSScriptRoot/Install-WithWinGet.ps1" -Package $package -InstalledSoftware $installed

.OUTPUTS
    Boolean indicating installation success
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Package,
    
    [Parameter(Mandatory)]
    [hashtable]$InstalledSoftware
)

$ErrorActionPreference = 'Stop'

# Check if winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  Error: winget is not available" -ForegroundColor Red
    Write-Host "  Install App Installer from Microsoft Store" -ForegroundColor Yellow
    return $false
}

# Check if package is already installed using pre-fetched list (idempotency)
if ($InstalledSoftware.ContainsKey($Package.packageId)) {
    Write-Host "✓ $($Package.name) is already installed" -ForegroundColor Green
    return $true
}

# Install package
Write-Host "Installing $($Package.name) via winget..." -ForegroundColor Yellow
$output = & winget @($Package.installArgs) 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "  ✓ $($Package.name) installed successfully" -ForegroundColor Green
    return $true
}
else {
    Write-Host "  ✗ Failed to install $($Package.name) (Exit code: $exitCode)" -ForegroundColor Red
    Write-Host "  Command: winget $($Package.installArgs -join ' ')" -ForegroundColor Gray
    if ($output) {
        Write-Host "  Output: $($output | Select-Object -First 3 | Out-String)" -ForegroundColor Gray
    }
    return $false
}
