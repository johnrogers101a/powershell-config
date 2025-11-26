#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs Visual Studio 2026 Enterprise on Windows.

.DESCRIPTION
    Checks for existing Visual Studio installations.
    If VS 2022 is found, offers to upgrade to VS 2026 migrating workloads.
    If no VS is found, installs VS 2026 with default workloads.
    Uses winget for installation.

.PARAMETER Platform
    Platform object with IsWindows property

.EXAMPLE
    & "$PSScriptRoot/Install-VisualStudio.ps1" -Platform $platform
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Platform
)

$ErrorActionPreference = 'Stop'

# Skip if not Windows
if (-not $Platform.IsWindows) {
    return
}

# Helper to get vswhere path
function Get-VsWherePath {
    $path = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $path) { return $path }
    $path = "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $path) { return $path }
    return $null
}

# Helper to get installed workloads from VS 2022
function Get-InstalledWorkloads {
    $vswhere = Get-VsWherePath
    if (-not $vswhere) { return @() }
    
    try {
        # Target VS 2022 specifically
        $json = & $vswhere -products Microsoft.VisualStudio.Product.Enterprise -version "[17.0,18.0)" -format json | ConvertFrom-Json
        
        if ($json) {
            # Handle array (multiple instances) or single object
            $instance = if ($json -is [array]) { $json[0] } else { $json }
            
            if ($instance.workloads) {
                # Extract just the IDs
                return $instance.workloads | ForEach-Object { $_.id }
            }
        }
    } catch {
        Write-Warning "Failed to retrieve existing workloads: $_"
    }
    return @()
}

# Default workloads for fresh install
$defaultWorkloads = @(
    "Microsoft.VisualStudio.Workload.NetWeb",
    "Microsoft.VisualStudio.Workload.Azure",
    "Microsoft.VisualStudio.Workload.Node",
    "Microsoft.VisualStudio.Workload.ManagedDesktop",
    "Microsoft.VisualStudio.Workload.Universal"
)

# Check for VS 2026 (Microsoft.VisualStudio.Enterprise)
Write-Host "Checking for Visual Studio 2026..." -ForegroundColor Cyan
$vs2026 = winget list --id Microsoft.VisualStudio.Enterprise --exact 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Visual Studio 2026 is already installed" -ForegroundColor Green
    return
}

# Check for VS 2022 (Microsoft.VisualStudio.2022.Enterprise)
Write-Host "Checking for Visual Studio 2022..." -ForegroundColor Cyan
$vs2022 = winget list --id Microsoft.VisualStudio.2022.Enterprise --exact 2>$null
$vs2022Installed = ($LASTEXITCODE -eq 0)

$workloadsToInstall = $defaultWorkloads
$shouldInstall = $true

if ($vs2022Installed) {
    Write-Host "Found Visual Studio 2022." -ForegroundColor Yellow
    
    $response = Read-Host "Upgrade to Visual Studio 2026 and migrate workloads? (y/n)"
    if ($response -eq 'y') {
        # Capture workloads BEFORE uninstalling
        $migratedWorkloads = Get-InstalledWorkloads
        
        if ($migratedWorkloads.Count -eq 0) {
            Write-Warning "Could not detect existing workloads. Falling back to default profile workloads."
            $workloadsToInstall = $defaultWorkloads
        } else {
            Write-Host "Detected $($migratedWorkloads.Count) workloads to migrate." -ForegroundColor Cyan
            $workloadsToInstall = $migratedWorkloads
        }

        Write-Host "Uninstalling Visual Studio 2022..." -ForegroundColor Yellow
        winget uninstall --id Microsoft.VisualStudio.2022.Enterprise --silent --accept-source-agreements
        
    } else {
        $response = Read-Host "Install Visual Studio 2026 with NO workloads (base install)? (y/n)"
        if ($response -eq 'y') {
            $workloadsToInstall = @()
        } else {
            $shouldInstall = $false
        }
    }
}

if ($shouldInstall) {
    Write-Host "Installing Visual Studio 2026..." -ForegroundColor Cyan
    
    $installArgs = "--quiet --wait --norestart"
    foreach ($wl in $workloadsToInstall) {
        $installArgs += " --add $wl"
    }
    
    # Winget override requires the args to be passed as a single string
    winget install --id Microsoft.VisualStudio.Enterprise --silent --accept-package-agreements --accept-source-agreements --override "$installArgs"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Visual Studio 2026 installed successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Installation failed with exit code $LASTEXITCODE" -ForegroundColor Red
    }
}

