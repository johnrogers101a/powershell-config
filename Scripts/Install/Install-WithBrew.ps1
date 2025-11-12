#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs a package using Homebrew package manager.

.DESCRIPTION
    Checks if package is already installed using pre-fetched list (idempotent).
    Installs package if not present. Updates environment variables for current session.
    Returns success status.

.PARAMETER Package
    Package configuration object with properties: name, installArgs, command, packageId

.PARAMETER InstalledSoftware
    Hashtable of already installed software (packageId -> $true)

.EXAMPLE
    $package = @{ name = "Git"; installArgs = @("install", "git"); command = "git"; packageId = "git" }
    $success = & "$PSScriptRoot/Install-WithBrew.ps1" -Package $package -InstalledSoftware $installed

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

# Check if brew is available
if (-not (Get-Command brew -ErrorAction SilentlyContinue)) {
    Write-Host "  Error: brew is not available" -ForegroundColor Red
    Write-Host "  Install Homebrew: https://brew.sh" -ForegroundColor Yellow
    return $false
}

# Check if package is already installed using pre-fetched list (idempotency)
if ($InstalledSoftware.ContainsKey($Package.packageId)) {
    Write-Host "✓ $($Package.name) is already installed" -ForegroundColor Green
    return $true
}

# Install package
Write-Host "Installing $($Package.name) via Homebrew..." -ForegroundColor Yellow
& brew @($Package.installArgs) 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ $($Package.name) installed successfully" -ForegroundColor Green
    
    # Update PATH for current session
    if (Test-Path "/opt/homebrew/bin/brew") {
        $env:PATH = "/opt/homebrew/bin:$env:PATH"
        & /opt/homebrew/bin/brew shellenv | Invoke-Expression
    }
    elseif (Test-Path "/usr/local/bin/brew") {
        $env:PATH = "/usr/local/bin:$env:PATH"
        & /usr/local/bin/brew shellenv | Invoke-Expression
    }
    
    return $true
}
else {
    Write-Host "  ✗ Failed to install $($Package.name)" -ForegroundColor Red
    return $false
}
