#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs a PowerShell module if not present and forces reload.

.DESCRIPTION
    Removes module if already loaded to ensure fresh import.
    Installs from PSGallery if not available. Forces import to get latest version.
    Idempotent - safe to run multiple times.

.PARAMETER ModuleName
    Name of module to install (e.g., "Terminal-Icons", "posh-git")

.EXAMPLE
    & "$PSScriptRoot/Install-ModuleIfMissing.ps1" -ModuleName "Terminal-Icons"

.OUTPUTS
    None (prints status to console)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ModuleName
)

$ErrorActionPreference = 'Stop'

# Remove module if already loaded to ensure fresh import
if (Get-Module -Name $ModuleName) {
    Remove-Module -Name $ModuleName -Force
}

# Install if not available
if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
    Write-Host "Installing $ModuleName..." -ForegroundColor Cyan
    Install-Module $ModuleName -Scope CurrentUser -Force
}

# Import with force to get latest version
Import-Module $ModuleName -Force
