#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets the system time zone based on profile configuration.

.DESCRIPTION
    OS dispatcher for timezone configuration. Accepts IANA timezone names
    (e.g. "America/Los_Angeles") on all platforms. On Windows, maps IANA names
    to Windows timezone IDs for backward compatibility with existing profiles.

.PARAMETER Platform
    Platform object with OS, IsWindows, IsMacOS, IsLinux properties.

.PARAMETER TimeZone
    IANA timezone name (e.g. "America/Los_Angeles") or Windows timezone ID
    (e.g. "Pacific Standard Time") — Windows IDs are accepted on Windows only.

.EXAMPLE
    & "$PSScriptRoot/Set-TimeZone.ps1" -Platform $platform -TimeZone "America/Los_Angeles"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Platform,

    [Parameter()]
    [string]$TimeZone
)

$ErrorActionPreference = 'Stop'

if (-not $TimeZone) {
    Write-Host "No timezone specified in profile, skipping" -ForegroundColor Gray
    return
}

# IANA → Windows timezone mapping table (for backward compat on Windows)
$ianaToWindows = @{
    "America/Los_Angeles"    = "Pacific Standard Time"
    "America/Denver"         = "Mountain Standard Time"
    "America/Chicago"        = "Central Standard Time"
    "America/New_York"       = "Eastern Standard Time"
    "America/Anchorage"      = "Alaskan Standard Time"
    "Pacific/Honolulu"       = "Hawaiian Standard Time"
    "Europe/London"          = "GMT Standard Time"
    "Europe/Paris"           = "W. Europe Standard Time"
    "Europe/Berlin"          = "W. Europe Standard Time"
    "Europe/Helsinki"        = "FLE Standard Time"
    "Asia/Kolkata"           = "India Standard Time"
    "Asia/Tokyo"             = "Tokyo Standard Time"
    "Asia/Shanghai"          = "China Standard Time"
    "Asia/Singapore"         = "Singapore Standard Time"
    "Australia/Sydney"       = "AUS Eastern Standard Time"
    "Australia/Perth"        = "W. Australia Standard Time"
    "UTC"                    = "UTC"
}

if ($Platform.IsWindows) {
    # Resolve IANA name to Windows name if needed
    $windowsZone = $TimeZone
    if ($ianaToWindows.ContainsKey($TimeZone)) {
        $windowsZone = $ianaToWindows[$TimeZone]
    }

    try {
        $current = Get-TimeZone
        if ($current.Id -eq $windowsZone) {
            Write-Host "✓ Time zone already set to $windowsZone" -ForegroundColor Green
            return
        }

        Write-Host "Setting time zone to $windowsZone..." -ForegroundColor Cyan

        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Write-Warning "Administrator privileges required to change time zone (current: $($current.Id))"
            return
        }

        Set-TimeZone -Name $windowsZone
        Write-Host "✓ Time zone updated to $windowsZone" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to set time zone: $_" -ForegroundColor Red
    }
}
elseif ($Platform.IsMacOS) {
    try {
        Write-Host "Setting time zone to $TimeZone..." -ForegroundColor Cyan
        sudo systemsetup -settimezone $TimeZone 2>&1 | Out-Null
        Write-Host "✓ Time zone updated to $TimeZone" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to set time zone: $_" -ForegroundColor Red
    }
}
elseif ($Platform.IsLinux) {
    try {
        # Resolve Windows-style name to IANA if needed (profile migration support)
        $ianaZone = $TimeZone
        $windowsToIana = @{}
        $ianaToWindows.GetEnumerator() | ForEach-Object { $windowsToIana[$_.Value] = $_.Key }
        if ($windowsToIana.ContainsKey($TimeZone)) {
            $ianaZone = $windowsToIana[$TimeZone]
            Write-Host "  Mapped '$TimeZone' → '$ianaZone'" -ForegroundColor Gray
        }

        Write-Host "Setting time zone to $ianaZone..." -ForegroundColor Cyan
        timedatectl set-timezone $ianaZone 2>&1 | Out-Null
        Write-Host "✓ Time zone updated to $ianaZone" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to set time zone: $_" -ForegroundColor Red
    }
}

