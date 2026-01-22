#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs required software based on platform and profile.

.DESCRIPTION
    Reads software list from profile for current platform.
    Delegates to platform-specific installer scripts (Install-WithWinGet or Install-WithBrew).
    Idempotent - skips already installed packages.

.PARAMETER Platform
    Platform object with OS, IsWindows, IsMacOS properties

.PARAMETER Profile
    Profile object with software.windows and software.macos properties

.PARAMETER ScriptsRoot
    Root path to Scripts directory

.EXAMPLE
    & "$PSScriptRoot/Install-Software.ps1" -Platform $platform -Profile $profile -ScriptsRoot $scriptsRoot

.OUTPUTS
    None (prints status to console)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Platform,
    
    [Parameter(Mandatory)]
    [PSCustomObject]$Profile,
    
    [Parameter(Mandatory)]
    [string]$ScriptsRoot
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "Installing software from profile '$($Profile.name)'..." -ForegroundColor Green
Write-Host ""

if ($Platform.IsWindows) {
    $packages = $Profile.software.windows
    
    if (-not $packages -or $packages.Count -eq 0) {
        Write-Host "No Windows packages in profile" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Windows packages to install: $($packages.Count)" -ForegroundColor Cyan
    Write-Host ""
    
    # Initialize winget (triggers license acceptance)
    Write-Host "Initializing winget..." -ForegroundColor Gray
    $null = winget list --source winget 2>&1 | Out-Null
    Write-Host ""
    
    $installerScript = Join-Path $ScriptsRoot "Install/Install-WithWinGet.ps1"
    
    foreach ($packageId in $packages) {
        $null = & $installerScript -PackageId $packageId
    }
}
elseif ($Platform.IsMacOS) {
    $formulae = $Profile.software.macos.formulae
    $casks = $Profile.software.macos.casks
    
    $totalCount = 0
    if ($formulae) { $totalCount += $formulae.Count }
    if ($casks) { $totalCount += $casks.Count }
    
    if ($totalCount -eq 0) {
        Write-Host "No macOS packages in profile" -ForegroundColor Yellow
        return
    }
    
    Write-Host "macOS packages to install: $totalCount (formulae: $($formulae.Count), casks: $($casks.Count))" -ForegroundColor Cyan
    Write-Host ""
    
    $installerScript = Join-Path $ScriptsRoot "Install/Install-WithBrew.ps1"
    
    foreach ($formula in $formulae) {
        $null = & $installerScript -PackageId $formula -Type "formula"
    }
    
    foreach ($cask in $casks) {
        $null = & $installerScript -PackageId $cask -Type "cask"
    }
}
else {
    Write-Host "Unsupported platform: $($Platform.OS)" -ForegroundColor Yellow
}

Write-Host ""
