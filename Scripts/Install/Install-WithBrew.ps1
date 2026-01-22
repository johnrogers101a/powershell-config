#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs a package using Homebrew package manager.

.DESCRIPTION
    Installs a formula or cask by ID using brew. Checks if already installed (idempotent).
    Updates environment variables for current session.

.PARAMETER PackageId
    The Homebrew package ID (e.g., "git", "visual-studio-code")

.PARAMETER Type
    Package type: "formula" or "cask" (default: "formula")

.EXAMPLE
    & "$PSScriptRoot/Install-WithBrew.ps1" -PackageId "git" -Type "formula"
    & "$PSScriptRoot/Install-WithBrew.ps1" -PackageId "visual-studio-code" -Type "cask"

.OUTPUTS
    Boolean indicating installation success
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PackageId,
    
    [Parameter()]
    [ValidateSet("formula", "cask")]
    [string]$Type = "formula"
)

$ErrorActionPreference = 'Stop'

# Check if brew is available
if (-not (Get-Command brew -ErrorAction SilentlyContinue)) {
    Write-Host "  Error: brew is not available" -ForegroundColor Red
    Write-Host "  Install Homebrew: https://brew.sh" -ForegroundColor Yellow
    return $false
}

# Check if package is already installed
Write-Host "Checking $PackageId..." -ForegroundColor Gray
if ($Type -eq "cask") {
    $check = brew list --cask $PackageId 2>&1
}
else {
    $check = brew list $PackageId 2>&1
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ $PackageId is already installed" -ForegroundColor Green
    return $true
}

# Install package
Write-Host "  Installing $PackageId ($Type)..." -ForegroundColor Yellow
if ($Type -eq "cask") {
    $output = brew install --cask $PackageId 2>&1
}
else {
    $output = brew install $PackageId 2>&1
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ $PackageId installed successfully" -ForegroundColor Green
    
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
    Write-Host "  ✗ Failed to install $PackageId" -ForegroundColor Red
    if ($output) {
        Write-Host "  Output: $($output | Select-Object -First 3 | Out-String)" -ForegroundColor Gray
    }
    return $false
}
