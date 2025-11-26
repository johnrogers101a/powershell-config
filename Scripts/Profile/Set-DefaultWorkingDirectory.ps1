#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets working directory to a default path if currently in home directory.

.DESCRIPTION
    Checks if current location is $HOME. If so, navigates to default path.
    Idempotent - safe to run multiple times (no effect if already elsewhere).

.PARAMETER DefaultPath
    Path to navigate to (default: ~/code)

.EXAMPLE
    & "$PSScriptRoot/Set-DefaultWorkingDirectory.ps1"
    & "$PSScriptRoot/Set-DefaultWorkingDirectory.ps1" -DefaultPath "~/projects"

.OUTPUTS
    None (changes current location)
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$DefaultPath = '~/code'
)

$ErrorActionPreference = 'Stop'

if ((Get-Location).Path -eq $HOME) {
    # Resolve the full path to ensure consistency
    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DefaultPath)
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $resolvedPath)) {
        Write-Host "Creating default working directory: $resolvedPath" -ForegroundColor Gray
        New-Item -ItemType Directory -Path $resolvedPath -Force | Out-Null
    }
    
    if (Test-Path $resolvedPath) {
        Set-Location -Path $resolvedPath
    }
}
