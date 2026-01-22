#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists all available software profiles from Azure.

.DESCRIPTION
    Downloads profiles-index.json from Azure Blob Storage and displays
    available profiles with name, description, and last updated date.

.PARAMETER Raw
    Returns raw JSON output instead of formatted table

.EXAMPLE
    Get-Profiles
    Get-Profiles -Raw

.OUTPUTS
    PSCustomObject[] with profile metadata, or JSON string if -Raw
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Raw
)

$ErrorActionPreference = 'Stop'

$AzureBaseUrl = "https://stprofilewus3.blob.core.windows.net/profile-config"
$cacheBuster = "v=$(Get-Date -Format 'yyyyMMddHHmmss')"

try {
    $indexUrl = "$AzureBaseUrl/profiles/profiles-index.json?$cacheBuster"
    $response = Invoke-WebRequest -Uri $indexUrl -UseBasicParsing -ErrorAction Stop
    $index = $response.Content | ConvertFrom-Json
}
catch {
    Write-Warning "Could not fetch profiles index: $($_.Exception.Message)"
    return @()
}

if ($Raw) {
    return $response.Content
}

if (-not $index.profiles -or $index.profiles.Count -eq 0) {
    Write-Host "No profiles available" -ForegroundColor Yellow
    return @()
}

Write-Host ""
Write-Host "Available Profiles:" -ForegroundColor Cyan
Write-Host ""

foreach ($profile in $index.profiles) {
    Write-Host "  $($profile.name)" -ForegroundColor Green -NoNewline
    if ($profile.description) {
        Write-Host " - $($profile.description)" -ForegroundColor Gray
    }
    else {
        Write-Host ""
    }
    Write-Host "    Updated: $($profile.updatedAt)" -ForegroundColor DarkGray
}

Write-Host ""

return $index.profiles
