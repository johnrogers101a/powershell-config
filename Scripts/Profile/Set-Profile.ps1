#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates an existing software profile.

.DESCRIPTION
    Updates a profile with new software list from current system or updates metadata.
    Requires the profile to exist locally in the profiles directory.

.PARAMETER Name
    Name of the profile to update

.PARAMETER Description
    New description for the profile

.PARAMETER FromCurrentSoftware
    Replace software list with currently installed software

.PARAMETER ProfilesPath
    Path to profiles directory (default: profiles/ in repo root)

.EXAMPLE
    Set-Profile -Name "my-workstation" -FromCurrentSoftware
    Set-Profile -Name "my-workstation" -Description "Updated description"

.OUTPUTS
    Path to updated profile JSON file
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,
    
    [Parameter()]
    [string]$Description,
    
    [Parameter()]
    [switch]$FromCurrentSoftware,
    
    [Parameter()]
    [string]$ProfilesPath
)

$ErrorActionPreference = 'Stop'

# Determine profiles path
if (-not $ProfilesPath) {
    $ProfilesPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "profiles"
}

$profileFile = Join-Path $ProfilesPath "$Name.json"

if (-not (Test-Path $profileFile)) {
    throw "Profile '$Name' not found at $profileFile. Use New-Profile to create it first."
}

# Load existing profile
$profile = Get-Content -Path $profileFile -Raw | ConvertFrom-Json

# Update description if provided
if ($Description) {
    $profile.description = $Description
}

# Update software if requested
if ($FromCurrentSoftware) {
    # Get platform info
    $coreScriptsDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Core"
    $platformScript = Join-Path $coreScriptsDir "Get-PlatformInfo.ps1"
    $platform = & $platformScript
    
    # Get currently installed software
    $getSoftwareScript = Join-Path $PSScriptRoot "Get-Software.ps1"
    $installedSoftware = & $getSoftwareScript
    
    if (-not $installedSoftware -or $installedSoftware.Count -eq 0) {
        throw "No user-installed software found"
    }
    
    if ($platform.IsWindows) {
        $profile.software.windows = @($installedSoftware | ForEach-Object { $_.Id })
    }
    elseif ($platform.IsMacOS) {
        $formulae = @()
        $casks = @()
        
        foreach ($pkg in $installedSoftware) {
            if ($pkg.Id -match '\(cask\)$') {
                $casks += ($pkg.Id -replace ' \(cask\)$', '')
            }
            else {
                $formulae += $pkg.Id
            }
        }
        
        $profile.software.macos.formulae = $formulae
        $profile.software.macos.casks = $casks
    }
}

# Update timestamp
$profile.updatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Write updated profile
$profile | ConvertTo-Json -Depth 10 | Set-Content -Path $profileFile -Encoding UTF8

Write-Host "Profile updated: " -NoNewline -ForegroundColor Green
Write-Host $profileFile -ForegroundColor White
Write-Host ""
Write-Host "Next: Run " -NoNewline -ForegroundColor Gray
Write-Host "Publish-Profile -Name '$Name'" -NoNewline -ForegroundColor Yellow
Write-Host " to upload changes to Azure" -ForegroundColor Gray

return $profileFile
