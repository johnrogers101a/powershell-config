#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs a package using Windows Package Manager (winget).

.DESCRIPTION
    Checks if package is already installed using winget list (idempotent).
    Installs package if not present. Returns success status.

.PARAMETER Package
    Package configuration object with properties: name, packageId, installArgs, command

.EXAMPLE
    $package = @{ name = "Git"; packageId = "Git.Git"; installArgs = @("-e", "--id", "Git.Git"); command = "git" }
    $success = & "$PSScriptRoot/Install-WithWinGet.ps1" -Package $package

.OUTPUTS
    Boolean indicating installation success
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Package
)

$ErrorActionPreference = 'Stop'

# Check if winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  Error: winget is not available" -ForegroundColor Red
    Write-Host "  Install App Installer from Microsoft Store" -ForegroundColor Yellow
    return $false
}

# Check if package is already installed (idempotency)
try {
    $null = winget list --id $Package.packageId --exact --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ $($Package.name) is already installed" -ForegroundColor Green
        return $true
    }
}
catch {
    # If winget check fails, try command check as fallback
    if (Get-Command $Package.command -ErrorAction SilentlyContinue) {
        Write-Host "✓ $($Package.name) is already installed" -ForegroundColor Green
        return $true
    }
}

# Install package
Write-Host "Installing $($Package.name) via winget..." -ForegroundColor Yellow
winget install $Package.installArgs 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ $($Package.name) installed successfully" -ForegroundColor Green
    return $true
}
else {
    Write-Host "  ✗ Failed to install $($Package.name)" -ForegroundColor Red
    return $false
}
