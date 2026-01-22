#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs software from a profile.

.DESCRIPTION
    Downloads a profile from Azure and installs all software packages
    for the current platform using winget (Windows) or brew (macOS).

.PARAMETER Name
    Name of the profile to install

.PARAMETER WhatIf
    Show what would be installed without actually installing

.EXAMPLE
    Install-Profile -Name "default"
    Install-Profile -Name "my-workstation" -WhatIf

.OUTPUTS
    None
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Name
)

$ErrorActionPreference = 'Stop'

$AzureBaseUrl = "https://stprofilewus3.blob.core.windows.net/profile-config"
$cacheBuster = "v=$(Get-Date -Format 'yyyyMMddHHmmss')"

# Get platform info
$coreScriptsDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Core"
$platformScript = Join-Path $coreScriptsDir "Get-PlatformInfo.ps1"
$platform = & $platformScript

# Check for local profile first
$profilesDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "profiles"
$localProfilePath = Join-Path $profilesDir "$Name.json"

# Download profile from Azure
Write-Host "Downloading profile '$Name' from Azure..." -ForegroundColor Cyan
try {
    $profileUrl = "$AzureBaseUrl/profiles/$Name.json?$cacheBuster"
    $response = Invoke-WebRequest -Uri $profileUrl -UseBasicParsing -ErrorAction Stop
    $azureProfile = $response.Content | ConvertFrom-Json
    $azureContent = $response.Content
}
catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        throw "Profile '$Name' not found in Azure"
    }
    throw "Could not fetch profile: $($_.Exception.Message)"
}

# Compare with local and publish if different
if (Test-Path $localProfilePath) {
    $localContent = Get-Content -Path $localProfilePath -Raw
    $localProfile = $localContent | ConvertFrom-Json
    
    # Compare JSON (normalize by re-serializing)
    $azureNormalized = $azureProfile | ConvertTo-Json -Depth 10 -Compress
    $localNormalized = $localProfile | ConvertTo-Json -Depth 10 -Compress
    
    if ($azureNormalized -ne $localNormalized) {
        Write-Host "  Local profile differs from Azure - publishing..." -ForegroundColor Yellow
        $publishScript = Join-Path $PSScriptRoot "Publish-Profile.ps1"
        & $publishScript -Name $Name
        
        # Use local profile for installation
        $profile = $localProfile
    }
    else {
        $profile = $azureProfile
    }
}
else {
    $profile = $azureProfile
}

Write-Host "Profile: $($profile.name)" -ForegroundColor Green
if ($profile.description) {
    Write-Host "Description: $($profile.description)" -ForegroundColor Gray
}
Write-Host ""

# Get installer script paths
$installScriptsDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Install"

if ($platform.IsWindows) {
    $packages = $profile.software.windows
    
    if (-not $packages -or $packages.Count -eq 0) {
        Write-Host "No Windows packages in this profile" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Installing $($packages.Count) Windows packages..." -ForegroundColor Cyan
    Write-Host ""
    
    # Initialize winget (triggers license acceptance)
    Write-Host "Initializing winget..." -ForegroundColor Gray
    $null = winget list --source winget 2>&1 | Out-Null
    
    $installerScript = Join-Path $installScriptsDir "Install-WithWinGet.ps1"
    
    foreach ($packageId in $packages) {
        if ($WhatIf) {
            Write-Host "  Would install: $packageId" -ForegroundColor Yellow
        }
        else {
            $null = & $installerScript -PackageId $packageId
        }
    }
}
elseif ($platform.IsMacOS) {
    $formulae = $profile.software.macos.formulae
    $casks = $profile.software.macos.casks
    
    $totalCount = ($formulae.Count + $casks.Count)
    if ($totalCount -eq 0) {
        Write-Host "No macOS packages in this profile" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Installing $totalCount macOS packages..." -ForegroundColor Cyan
    Write-Host ""
    
    $installerScript = Join-Path $installScriptsDir "Install-WithBrew.ps1"
    
    foreach ($formula in $formulae) {
        if ($WhatIf) {
            Write-Host "  Would install formula: $formula" -ForegroundColor Yellow
        }
        else {
            $null = & $installerScript -PackageId $formula -Type "formula"
        }
    }
    
    foreach ($cask in $casks) {
        if ($WhatIf) {
            Write-Host "  Would install cask: $cask" -ForegroundColor Yellow
        }
        else {
            $null = & $installerScript -PackageId $cask -Type "cask"
        }
    }
}

Write-Host ""
Write-Host "Profile installation complete!" -ForegroundColor Green
