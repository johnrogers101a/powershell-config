#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets the system time zone to Pacific Standard Time if requested.

.DESCRIPTION
    Checks current time zone. If not Pacific, asks user to update it.
    Requires Administrator privileges to change time zone.

.EXAMPLE
    & "$PSScriptRoot/Set-TimeZone.ps1"
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$targetTimeZoneId = "Pacific Standard Time"

try {
    $current = Get-TimeZone
    
    if ($current.Id -eq $targetTimeZoneId) {
        Write-Host "✓ Time zone is already set to $targetTimeZoneId" -ForegroundColor Green
        return
    }

    Write-Host "Current time zone: $($current.Id)" -ForegroundColor Gray
    $response = Read-Host "Do you want to set the time zone to $targetTimeZoneId? (y/n)"

    if ($response -eq 'y') {
        # Check for Administrator privileges
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Warning "Administrator privileges are required to change the time zone."
            return
        }

        Set-TimeZone -Id $targetTimeZoneId
        Write-Host "✓ Time zone updated to $targetTimeZoneId" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Failed to check/set time zone: $_" -ForegroundColor Red
}
