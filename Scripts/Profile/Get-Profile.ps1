#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Downloads a software profile from Azure for local editing.

.DESCRIPTION
    Downloads a profile JSON from Azure Blob Storage to the local profiles/
    directory and returns the path so you can edit it. Use Publish-Profile
    to upload changes back to Azure.

.PARAMETER Name
    Name of the profile to retrieve

.EXAMPLE
    Get-Profile -Name "default"
    # Returns: C:\path\to\profiles\default.json

.OUTPUTS
    String - path to the local profile file
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name
)

$ErrorActionPreference = 'Stop'

$AzureBaseUrl = "https://stprofilewus3.blob.core.windows.net/profile-config"
$cacheBuster = "v=$(Get-Date -Format 'yyyyMMddHHmmss')"

# Determine local profiles directory
$profilesDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "profiles"
$localPath = Join-Path $profilesDir "$Name.json"

# Ensure profiles directory exists
if (-not (Test-Path $profilesDir)) {
    New-Item -ItemType Directory -Path $profilesDir -Force | Out-Null
}

# Download from Azure
Write-Host "Downloading profile '$Name' from Azure..." -ForegroundColor Cyan
try {
    $profileUrl = "$AzureBaseUrl/profiles/$Name.json?$cacheBuster"
    $response = Invoke-WebRequest -Uri $profileUrl -UseBasicParsing -ErrorAction Stop
    $response.Content | Set-Content -Path $localPath -Encoding UTF8
}
catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        throw "Profile '$Name' not found in Azure"
    }
    throw "Could not fetch profile: $($_.Exception.Message)"
}

Write-Host "  ✓ Downloaded to: $localPath" -ForegroundColor Green
Write-Host ""

# Display profile contents
$profile = $response.Content | ConvertFrom-Json

# Add default timezone if missing
if (-not $profile.timezone) {
    $profile | Add-Member -NotePropertyName "timezone" -NotePropertyValue "Pacific Standard Time"
    $profile | ConvertTo-Json -Depth 10 | Set-Content -Path $localPath -Encoding UTF8
    Write-Host "  Added default timezone: Pacific Standard Time" -ForegroundColor Yellow
}

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
Write-Host "Timezone: " -NoNewline -ForegroundColor Cyan
Write-Host $profile.timezone -ForegroundColor Gray
Write-Host ""

# Get platform info for platform-specific display
$coreScriptsDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Core"
$platformScript = Join-Path $coreScriptsDir "Get-PlatformInfo.ps1"
$platform = & $platformScript

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
Write-Host "Edit the file, then run: " -NoNewline -ForegroundColor Gray
Write-Host "publish-profile $Name" -ForegroundColor Yellow
Write-Host ""

return $localPath
