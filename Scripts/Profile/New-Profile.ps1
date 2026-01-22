#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a new software profile from currently installed software.

.DESCRIPTION
    Captures user-installed software using Get-Software and creates a profile JSON file.
    Windows: Extracts winget package IDs
    macOS: Extracts brew formulae and casks

.PARAMETER Name
    Name of the profile (lowercase alphanumeric and hyphens only)

.PARAMETER Description
    Optional description of the profile

.PARAMETER OutputPath
    Output directory for the profile JSON (default: profiles/ in repo root)

.EXAMPLE
    New-Profile -Name "my-workstation" -Description "My dev setup"

.OUTPUTS
    Path to created profile JSON file
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9-]+$')]
    [string]$Name,
    
    [Parameter()]
    [string]$Description = "",
    
    [Parameter()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

# Validate name length
if ($Name.Length -gt 50) {
    throw "Profile name must be 50 characters or less"
}

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

# Build profile object
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$profile = @{
    name = $Name
    description = $Description
    createdAt = $timestamp
    updatedAt = $timestamp
    software = @{}
}

if ($platform.IsWindows) {
    # Windows: Extract IDs directly
    $profile.software.windows = @($installedSoftware | ForEach-Object { $_.Id })
    $profile.software.macos = @{
        formulae = @()
        casks = @()
    }
}
elseif ($platform.IsMacOS) {
    # macOS: Software already categorized by Get-Software
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
    
    $profile.software.windows = @()
    $profile.software.macos = @{
        formulae = $formulae
        casks = $casks
    }
}

# Determine output path
if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "profiles"
}

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$outputFile = Join-Path $OutputPath "$Name.json"

# Write profile JSON
$profile | ConvertTo-Json -Depth 10 | Set-Content -Path $outputFile -Encoding UTF8

Write-Host "Profile created: " -NoNewline -ForegroundColor Green
Write-Host $outputFile -ForegroundColor White
Write-Host ""
Write-Host "Software captured:" -ForegroundColor Cyan
if ($platform.IsWindows) {
    Write-Host "  Windows packages: $($profile.software.windows.Count)" -ForegroundColor White
}
else {
    Write-Host "  Formulae: $($profile.software.macos.formulae.Count)" -ForegroundColor White
    Write-Host "  Casks: $($profile.software.macos.casks.Count)" -ForegroundColor White
}
Write-Host ""
Write-Host "Next: Run " -NoNewline -ForegroundColor Gray
Write-Host "Publish-Profile -Name '$Name'" -NoNewline -ForegroundColor Yellow
Write-Host " to upload to Azure" -ForegroundColor Gray

return $outputFile
