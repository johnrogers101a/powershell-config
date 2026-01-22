#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Gets details of a specific software profile.

.DESCRIPTION
    Downloads a profile JSON from Azure Blob Storage and displays
    the software list for the current platform.

.PARAMETER Name
    Name of the profile to retrieve

.PARAMETER Raw
    Returns raw JSON output instead of formatted display

.EXAMPLE
    Get-Profile -Name "default"
    Get-Profile -Name "my-workstation" -Raw

.OUTPUTS
    PSCustomObject with profile data, or JSON string if -Raw
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,
    
    [Parameter()]
    [switch]$Raw
)

$ErrorActionPreference = 'Stop'

$AzureBaseUrl = "https://stprofilewus3.blob.core.windows.net/profile-config"
$cacheBuster = "v=$(Get-Date -Format 'yyyyMMddHHmmss')"

# Get platform info
$coreScriptsDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Core"
$platformScript = Join-Path $coreScriptsDir "Get-PlatformInfo.ps1"
$platform = & $platformScript

try {
    $profileUrl = "$AzureBaseUrl/profiles/$Name.json?$cacheBuster"
    $response = Invoke-WebRequest -Uri $profileUrl -UseBasicParsing -ErrorAction Stop
    $profile = $response.Content | ConvertFrom-Json
}
catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        throw "Profile '$Name' not found"
    }
    throw "Could not fetch profile: $($_.Exception.Message)"
}

if ($Raw) {
    return $response.Content
}

Write-Host ""
Write-Host "Profile: " -NoNewline -ForegroundColor Cyan
Write-Host $profile.name -ForegroundColor White
if ($profile.description) {
    Write-Host "Description: " -NoNewline -ForegroundColor Cyan
    Write-Host $profile.description -ForegroundColor Gray
}
Write-Host "Created: " -NoNewline -ForegroundColor Cyan
Write-Host $profile.createdAt -ForegroundColor Gray
Write-Host "Updated: " -NoNewline -ForegroundColor Cyan
Write-Host $profile.updatedAt -ForegroundColor Gray
Write-Host ""

if ($platform.IsWindows) {
    Write-Host "Windows Packages ($($profile.software.windows.Count)):" -ForegroundColor Green
    foreach ($pkg in $profile.software.windows) {
        Write-Host "  $pkg" -ForegroundColor White
    }
}
elseif ($platform.IsMacOS) {
    Write-Host "Homebrew Formulae ($($profile.software.macos.formulae.Count)):" -ForegroundColor Green
    foreach ($pkg in $profile.software.macos.formulae) {
        Write-Host "  $pkg" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Homebrew Casks ($($profile.software.macos.casks.Count)):" -ForegroundColor Green
    foreach ($pkg in $profile.software.macos.casks) {
        Write-Host "  $pkg" -ForegroundColor White
    }
}

Write-Host ""

return $profile
