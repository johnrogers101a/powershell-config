#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs a package using Flatpak package manager.

.DESCRIPTION
    Installs a Flatpak application by ID from the Flathub remote.
    Checks if already installed (idempotent). Returns bool indicating success.

.PARAMETER PackageId
    The Flatpak application ID (e.g., "com.visualstudio.code", "com.google.Chrome")

.EXAMPLE
    & "$PSScriptRoot/Install-WithFlatpak.ps1" -PackageId "com.visualstudio.code"

.OUTPUTS
    Boolean indicating installation success
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PackageId
)

$ErrorActionPreference = 'Stop'

# Check if flatpak is available
if (-not (Get-Command flatpak -ErrorAction SilentlyContinue)) {
    Write-Host "  Error: flatpak is not available" -ForegroundColor Red
    return $false
}

# Check if already installed
Write-Host "Checking $PackageId..." -ForegroundColor Gray
$installed = flatpak list --app --columns=application 2>&1 | Where-Object { $_ -eq $PackageId }
if ($installed) {
    Write-Host "  ✓ $PackageId is already installed" -ForegroundColor Green
    return $true
}

# Ensure flathub remote is added
$remotes = flatpak remotes --columns=name 2>&1
if ($remotes -notcontains "flathub") {
    Write-Host "  Adding Flathub remote..." -ForegroundColor Gray
    flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>&1 | Out-Null
}

# Install package
Write-Host "  Installing $PackageId..." -ForegroundColor Yellow
$output = flatpak install --noninteractive --assumeyes flathub $PackageId 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ $PackageId installed successfully" -ForegroundColor Green
    return $true
}
else {
    Write-Host "  ✗ Failed to install $PackageId" -ForegroundColor Red
    if ($output) {
        Write-Host "  Output: $($output | Select-Object -First 3 | Out-String)" -ForegroundColor Gray
    }
    return $false
}
