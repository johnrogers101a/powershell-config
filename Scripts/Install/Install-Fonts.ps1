#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs configured fonts using oh-my-posh CLI.

.DESCRIPTION
    Checks if oh-my-posh is available, then installs fonts from configuration.
    Idempotent - font installation command is safe to run multiple times.

.PARAMETER Config
    Configuration object with fonts array containing name and installCommand

.EXAMPLE
    & "$PSScriptRoot/Install-Fonts.ps1" -Config $config

.OUTPUTS
    None (prints status to console)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Config
)

$ErrorActionPreference = 'Continue'  # Don't stop on font errors

# Check if oh-my-posh is available
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Write-Host "Skipping font installation (oh-my-posh not available)" -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "Installing fonts..." -ForegroundColor Green

foreach ($font in $Config.fonts) {
    Write-Host "  Installing $($font.name)..." -ForegroundColor Cyan
    
    $installCmd = $font.installCommand -split ' '
    & $installCmd[0] @($installCmd[1..($installCmd.Length - 1)]) 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ $($font.name) installed successfully" -ForegroundColor Green
    }
    else {
        Write-Host "  Note: Font may already be installed or installation skipped" -ForegroundColor Yellow
    }
}
