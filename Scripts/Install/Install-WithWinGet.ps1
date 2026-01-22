#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs a package using Windows Package Manager (winget).

.DESCRIPTION
    Installs a package by ID using winget. Checks if already installed (idempotent).
    Uses standard install command for all packages.

.PARAMETER PackageId
    The winget package ID (e.g., "Git.Git", "Microsoft.VisualStudioCode")

.EXAMPLE
    & "$PSScriptRoot/Install-WithWinGet.ps1" -PackageId "Git.Git"

.OUTPUTS
    Boolean indicating installation success
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PackageId
)

$ErrorActionPreference = 'Stop'

# Check if winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  Error: winget is not available" -ForegroundColor Red
    Write-Host "  Install App Installer from Microsoft Store" -ForegroundColor Yellow
    return $false
}

# Check if package is installed using winget list --id
Write-Host "Checking $PackageId..." -ForegroundColor Gray
$check = winget list --id $PackageId --exact --source winget 2>&1
if ($LASTEXITCODE -eq 0 -and $check -notmatch "No installed package") {
    Write-Host "  ✓ $PackageId is already installed" -ForegroundColor Green
    return $true
}

# Install package using standard command
Write-Host "  Installing $PackageId..." -ForegroundColor Yellow
$output = winget install -e --id $PackageId --silent --accept-package-agreements --accept-source-agreements --source winget 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "  ✓ $PackageId installed successfully" -ForegroundColor Green
    return $true
}
else {
    Write-Host "  ✗ Failed to install $PackageId (Exit code: $exitCode)" -ForegroundColor Red
    if ($output) {
        $outputStr = $output | Out-String
        if ($outputStr -match "already installed") {
            Write-Host "  ✓ $PackageId is already installed" -ForegroundColor Green
            return $true
        }
        Write-Host "  Output: $($output | Select-Object -First 3 | Out-String)" -ForegroundColor Gray
    }
    return $false
}
