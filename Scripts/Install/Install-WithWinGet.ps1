#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs a package using Windows Package Manager (winget).

.DESCRIPTION
    Installs a package by ID using winget. Checks if already installed (idempotent).
    Special handling for VisualStudio2026 to include workloads.

.PARAMETER PackageId
    The winget package ID (e.g., "Git.Git", "Microsoft.VisualStudioCode")
    Or "VisualStudio2026" which maps to Microsoft.VisualStudio.Enterprise with workloads.

.EXAMPLE
    & "$PSScriptRoot/Install-WithWinGet.ps1" -PackageId "Git.Git"
    & "$PSScriptRoot/Install-WithWinGet.ps1" -PackageId "VisualStudio2026"

.OUTPUTS
    Boolean indicating installation success
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PackageId
)

$ErrorActionPreference = 'Stop'

# Check if winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  Error: winget is not available" -ForegroundColor Red
    Write-Host "  Install App Installer from Microsoft Store" -ForegroundColor Yellow
    return $false
}

# Handle special package aliases
$override = $null
if ($PackageId -eq "VisualStudio2026") {
    $PackageId = "Microsoft.VisualStudio.Enterprise"
    $workloads = @(
        "Microsoft.VisualStudio.Workload.NetWeb",
        "Microsoft.VisualStudio.Workload.Azure",
        "Microsoft.VisualStudio.Workload.Node",
        "Microsoft.VisualStudio.Workload.ManagedDesktop",
        "Microsoft.VisualStudio.Workload.Universal"
    )
    $override = "--passive --norestart"
    foreach ($wl in $workloads) {
        $override += " --add $wl"
    }
}

# Check if package is installed using winget list --id
Write-Host "Checking $PackageId..." -ForegroundColor Gray
$check = winget list --id $PackageId --exact --source winget 2>&1
if ($LASTEXITCODE -eq 0 -and $check -notmatch "No installed package") {
    Write-Host "  ✓ $PackageId is already installed" -ForegroundColor Green
    return $true
}

# Install package
Write-Host "  Installing $PackageId..." -ForegroundColor Yellow
if ($override) {
    # Don't use --silent when using --override (they conflict)
    $output = winget install -e --id $PackageId --accept-package-agreements --accept-source-agreements --source winget --override "$override" 2>&1
} else {
    $output = winget install -e --id $PackageId --silent --accept-package-agreements --accept-source-agreements --source winget 2>&1
}
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "  ✓ $PackageId installed successfully" -ForegroundColor Green
    return $true
}
else {
    Write-Host "  ✗ Failed to install $PackageId (Exit code: $exitCode)" -ForegroundColor Red
    if ($output) {
        $outputStr = $output | Out-String
        if ($outputStr -match "already installed") {
            Write-Host "  ✓ $PackageId is already installed" -ForegroundColor Green
            return $true
        }
        Write-Host "  Output: $($output | Select-Object -First 3 | Out-String)" -ForegroundColor Gray
    }
    return $false
}
