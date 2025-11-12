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
    Set-Location -Path $DefaultPath
}
