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
    Write-Host "Current time zone: $($current.Id)" -ForegroundColor Gray
    Write-Host "Do you want to set the time zone to pacific? (y/n): " -NoNewline
    $response = Read-Host

    if ($response -eq 'y') {
        # Check for Administrator privileges
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Warning "Administrator privileges are required to change the time zone."
            return
        }

        Set-TimeZone -Name "Pacific Standard Time"
        Write-Host "✓ Time zone updated to $targetTimeZoneId" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Failed to check/set time zone: $_" -ForegroundColor Red
}
