#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs Visual Studio 2026 Enterprise on Windows with all workloads.

.DESCRIPTION
    Checks if Visual Studio is already installed (idempotent).
    Downloads bootstrapper using BITS transfer to Desktop for reliability.
    Installs silently with comprehensive workload selection.
    Windows only - returns early on other platforms.

.PARAMETER Platform
    Platform object with IsWindows property

.EXAMPLE
    & "$PSScriptRoot/Install-VisualStudio.ps1" -Platform $platform

.OUTPUTS
    None (prints status to console)
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

# Check if Visual Studio is already installed (idempotency)
Write-Host "Checking for Visual Studio installation..." -ForegroundColor Cyan
$vsCheck = winget list --id Microsoft.VisualStudio.2022.Enterprise 2>$null
if ($LASTEXITCODE -eq 0 -and $vsCheck -match "Microsoft.VisualStudio.2022.Enterprise") {
    Write-Host "✓ Visual Studio is already installed" -ForegroundColor Green
    return
}

Write-Host ""
Write-Host "Installing Visual Studio 2026 Enterprise..." -ForegroundColor Yellow
Write-Host "  This may take several minutes..." -ForegroundColor Cyan

# Download Visual Studio 2026 bootstrapper to Desktop
$vsBootstrapperUrl = "https://aka.ms/vs/18/release/vs_enterprise.exe"
$desktopPath = [Environment]::GetFolderPath('Desktop')
$vsBootstrapperPath = Join-Path $desktopPath "vs_enterprise_installer.exe"

try {
    # Remove existing installer if present
    if (Test-Path $vsBootstrapperPath) {
        Write-Host "  Removing existing installer..." -ForegroundColor Cyan
        Remove-Item $vsBootstrapperPath -Force -ErrorAction Stop
    }
    
    Write-Host "  Downloading Visual Studio installer..." -ForegroundColor Cyan
    Write-Host "  URL: $vsBootstrapperUrl" -ForegroundColor Gray
    Write-Host "  Destination: $vsBootstrapperPath" -ForegroundColor Gray
    
    # Use Start-BitsTransfer for most reliable download on Windows
    try {
        Import-Module BitsTransfer -ErrorAction Stop
        Start-BitsTransfer -Source $vsBootstrapperUrl -Destination $vsBootstrapperPath -Description "Visual Studio Installer" -ErrorAction Stop
        Write-Host "  ✓ Downloaded using BITS transfer" -ForegroundColor Green
    }
    catch {
        Write-Host "  BITS transfer unavailable, trying Invoke-WebRequest..." -ForegroundColor Yellow
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $vsBootstrapperUrl -OutFile $vsBootstrapperPath -UseBasicParsing -ErrorAction Stop
        Write-Host "  ✓ Downloaded using Invoke-WebRequest" -ForegroundColor Green
    }
    
    # Verify download
    if (-not (Test-Path $vsBootstrapperPath)) {
        throw "Download failed: Installer file not found at $vsBootstrapperPath"
    }
    
    $fileInfo = Get-Item $vsBootstrapperPath
    $fileSize = $fileInfo.Length
    
    if ($fileSize -lt 1MB) {
        throw "Download failed: File size too small ($fileSize bytes) - expected at least 1 MB"
    }
    
    # Verify file is a valid PE executable
    $bytes = [System.IO.File]::ReadAllBytes($vsBootstrapperPath)
    if ($bytes.Length -lt 2 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
        throw "Downloaded file is not a valid executable (MZ header missing)"
    }
    
    Write-Host "  ✓ File size: $([math]::Round($fileSize/1MB, 2)) MB" -ForegroundColor Green
    Write-Host "  ✓ File integrity verified (valid PE executable)" -ForegroundColor Green
    
    # Define all workloads
    $workloads = @(
        "Microsoft.VisualStudio.Workload.ManagedDesktop"
        "Microsoft.VisualStudio.Workload.NetWeb"
        "Microsoft.VisualStudio.Workload.Azure"
        "Microsoft.VisualStudio.Workload.Data"
        "Microsoft.VisualStudio.Workload.Python"
        "Microsoft.VisualStudio.Workload.Node"
        "Microsoft.VisualStudio.Workload.Universal"
        "Microsoft.VisualStudio.Workload.NativeDesktop"
        "Microsoft.VisualStudio.Workload.NativeMobile"
        "Microsoft.VisualStudio.Workload.ManagedGame"
        "Microsoft.VisualStudio.Workload.NativeGame"
        "Microsoft.VisualStudio.Workload.VisualStudioExtension"
        "Microsoft.VisualStudio.Workload.Office"
        "Microsoft.VisualStudio.Workload.NetCrossPlat"
    )
    
    # Build install arguments
    $installArgs = @(
        "--quiet"
        "--norestart"
        "--wait"
        "--nocache"
    )
    
    foreach ($workload in $workloads) {
        $installArgs += "--add"
        $installArgs += $workload
    }
    
    Write-Host "  Installing Visual Studio with all workloads..." -ForegroundColor Cyan
    Write-Host "  (This will run silently in the background)" -ForegroundColor Yellow
    
    # Run installer
    $process = Start-Process -FilePath $vsBootstrapperPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop
    
    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
        Write-Host "  ✓ Visual Studio installed successfully" -ForegroundColor Green
        if ($process.ExitCode -eq 3010) {
            Write-Host "  Note: A restart may be required to complete the installation" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  ✗ Visual Studio installation failed (Exit code: $($process.ExitCode))" -ForegroundColor Red
        Write-Host "  Common exit codes: -1 (error), -2147205120 (admin required), 740 (elevation required)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ✗ Failed to install Visual Studio: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Installer location: $vsBootstrapperPath" -ForegroundColor Yellow
    Write-Host "  You can try running the installer manually if needed" -ForegroundColor Yellow
}
finally {
    # Clean up installer
    if (Test-Path $vsBootstrapperPath) {
        Write-Host "  Cleaning up installer..." -ForegroundColor Cyan
        Start-Sleep -Seconds 1
        Remove-Item $vsBootstrapperPath -Force -ErrorAction SilentlyContinue
    }
}
