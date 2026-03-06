#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs OS updates for the current platform.

.DESCRIPTION
    OS dispatcher for system and application updates.
    Windows: Uses PSWindowsUpdate for OS updates and winget for app upgrades.
    macOS: Uses softwareupdate --all --install.
    Linux: Logs informational skip — updates are managed by rpm-ostree and Flatpak on
           immutable distros like Bazzite; automated updates are not appropriate here.

.PARAMETER Platform
    Platform object with OS, IsWindows, IsMacOS, IsLinux properties.

.EXAMPLE
    & "$PSScriptRoot/Install-OsUpdates.ps1" -Platform $platform
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Platform
)

$ErrorActionPreference = 'Stop'

if ($Platform.IsWindows) {
    # Check for Administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Warning "Administrator privileges are required to install Windows Updates."
        Write-Warning "Skipping Windows Update installation."
    }
    else {
        Write-Host "Checking for Windows Updates..." -ForegroundColor Cyan
        try {
            if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                Write-Host "Installing PSWindowsUpdate module..." -ForegroundColor Gray
                Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop
            }
            Import-Module PSWindowsUpdate -ErrorAction Stop
            Write-Host "Installing available Windows Updates (this may take a while)..." -ForegroundColor Yellow
            Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot -Verbose
            Write-Host "✓ Windows Updates installed" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to install Windows Updates: $_" -ForegroundColor Red
        }
    }

    # App updates via winget
    Write-Host ""
    Write-Host "Checking for App/Store updates..." -ForegroundColor Cyan
    try {
        winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ App updates completed" -ForegroundColor Green
        }
        elseif ($LASTEXITCODE -eq -1978335189) {
            Write-Host "✓ No app updates available" -ForegroundColor Green
        }
        else {
            Write-Host "Note: Some app updates may have failed or required interaction (Exit code: $LASTEXITCODE)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "✗ Failed to run app updates: $_" -ForegroundColor Red
    }
}
elseif ($Platform.IsMacOS) {
    Write-Host "Checking for macOS software updates..." -ForegroundColor Cyan
    try {
        softwareupdate --all --install --force 2>&1 | Out-Null
        Write-Host "✓ macOS updates completed" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to run macOS updates: $_" -ForegroundColor Red
    }
}
elseif ($Platform.IsLinux) {
    Write-Host "Skipping automated OS updates on Linux." -ForegroundColor Yellow
    Write-Host "  On Bazzite/Silverblue: use 'rpm-ostree upgrade' or update via the system UI." -ForegroundColor Gray
    Write-Host "  Flatpak apps: run 'flatpak update' to update installed apps." -ForegroundColor Gray
}
