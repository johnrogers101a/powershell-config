#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets the system time zone based on profile configuration.

.DESCRIPTION
    Sets the time zone to the value specified in the profile.
    Requires Administrator privileges to change time zone.
    Skips if no timezone specified or already set correctly.

.PARAMETER TimeZone
    The time zone ID to set (e.g., "Pacific Standard Time")

.EXAMPLE
    & "$PSScriptRoot/Set-TimeZone.ps1" -TimeZone "Pacific Standard Time"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TimeZone
)

$ErrorActionPreference = 'Stop'

# Skip if no timezone specified
if (-not $TimeZone) {
    Write-Host "No timezone specified in profile, skipping" -ForegroundColor Gray
    return
}

try {
    $current = Get-TimeZone
    
    # Skip if already set correctly
    if ($current.Id -eq $TimeZone) {
        Write-Host "✓ Time zone already set to $TimeZone" -ForegroundColor Green
        return
    }
    
    Write-Host "Setting time zone to $TimeZone..." -ForegroundColor Cyan
    
    # Check for Administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Warning "Administrator privileges required to change time zone (current: $($current.Id))"
        return
    }

    Set-TimeZone -Name $TimeZone
    Write-Host "✓ Time zone updated to $TimeZone" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to set time zone: $_" -ForegroundColor Red
}
