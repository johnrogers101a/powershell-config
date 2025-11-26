#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs Windows Updates and updates all apps (including Store apps via winget).

.DESCRIPTION
    Uses PSWindowsUpdate module to install OS updates.
    Uses winget to upgrade all installed applications.
    Requires Administrator privileges for OS updates.

.EXAMPLE
    & "$PSScriptRoot/Install-WindowsUpdates.ps1"
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Warning "Administrator privileges are required to install Windows Updates."
    Write-Warning "Skipping Windows Update installation."
} else {
    Write-Host "Checking for Windows Updates..." -ForegroundColor Cyan

    try {
        # Install PSWindowsUpdate module if missing
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Host "Installing PSWindowsUpdate module..." -ForegroundColor Gray
            Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop
        }

        # Import module
        Import-Module PSWindowsUpdate -ErrorAction Stop

        # Install updates
        Write-Host "Installing available Windows Updates (this may take a while)..." -ForegroundColor Yellow
        # Install-WindowsUpdate is the command, Get-WindowsUpdate -Install is the alias/old way
        Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot -Verbose
        Write-Host "✓ Windows Updates installed" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to install Windows Updates: $_" -ForegroundColor Red
    }
}

# Store/App Updates via Winget
Write-Host ""
Write-Host "Checking for App/Store updates..." -ForegroundColor Cyan
try {
    # We use --include-unknown to try and catch everything
    # Note: This might fail if the msstore source is blocked/broken as seen previously, 
    # but we attempt it as requested.
    Write-Host "Running winget upgrade --all..." -ForegroundColor Gray
    winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ App updates completed" -ForegroundColor Green
    } elseif ($LASTEXITCODE -eq -1978335189) { # No applicable updates found
        Write-Host "✓ No app updates available" -ForegroundColor Green
    } else {
        Write-Host "Note: Some app updates may have failed or required interaction (Exit code: $LASTEXITCODE)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Failed to run app updates: $_" -ForegroundColor Red
}
