#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configures the terminal application for the current platform.

.DESCRIPTION
    OS dispatcher for terminal configuration.
    Windows: Sets PowerShell 7 as default profile in Windows Terminal and configures font.
    Linux/macOS: Terminal config is user-specific — logs an informational skip message.

.PARAMETER Platform
    Platform object with OS, IsWindows, IsMacOS, IsLinux properties.

.EXAMPLE
    & "$PSScriptRoot/Configure-Terminal.ps1" -Platform $platform
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Platform
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "Configuring terminal..." -ForegroundColor Cyan

if ($Platform.IsWindows) {
    # Delegate to existing Windows Terminal configuration logic
    $wtScript = Join-Path $PSScriptRoot "Configure-WindowsTerminal.ps1"
    & $wtScript
}
elseif ($Platform.IsMacOS) {
    Write-Host "  Terminal configuration is not automated on macOS." -ForegroundColor Yellow
    Write-Host "  Tip: Configure your terminal to use 'MesloLGM Nerd Font Mono'" -ForegroundColor Gray
}
elseif ($Platform.IsLinux) {
    Write-Host "  Terminal configuration is not automated on Linux." -ForegroundColor Yellow
    Write-Host "  Tip: Configure your terminal to use 'MesloLGM Nerd Font Mono'" -ForegroundColor Gray
}
