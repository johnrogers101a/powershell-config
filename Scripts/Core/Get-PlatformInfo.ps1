#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Detects platform information for cross-platform PowerShell scripts.

.DESCRIPTION
    Returns a platform information object containing OS type and boolean flags.
    Supports Windows and macOS. Throws error for unsupported platforms.
    Idempotent - always returns same result for same platform.

.EXAMPLE
    $platform = & "$PSScriptRoot/Scripts/Core/Get-PlatformInfo.ps1"
    if ($platform.IsWindows) { Write-Host "Running on Windows" }

.OUTPUTS
    PSCustomObject with properties: OS, IsWindows, IsMacOS
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Detect platform using built-in variables
$onWindows = (-not (Test-Path variable:global:IsWindows)) -or $global:IsWindows
$onMacOS = (Test-Path variable:global:IsMacOS) -and $global:IsMacOS

# Determine OS string
if ($onWindows) {
    $os = "windows"
}
elseif ($onMacOS) {
    $os = "macos"
}
else {
    throw "Unsupported operating system. This installer only supports Windows and macOS."
}

# Return platform info object
[PSCustomObject]@{
    OS        = $os
    IsWindows = $onWindows
    IsMacOS   = $onMacOS
}
