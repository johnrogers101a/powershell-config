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

# Download Visual Studio 2026 Enterprise bootstrapper from Azure Storage
# Pre-uploaded installer to avoid Microsoft's problematic aka.ms redirects
$azureBaseUrl = "https://stprofilewus3.blob.core.windows.net/profile-config"
$vsBootstrapperUrl = "$azureBaseUrl/VisualStudioSetup.exe"
$cacheBuster = "?v=$(Get-Date -Format 'yyyyMMddHHmmss')"
$vsBootstrapperUrl += $cacheBuster
$desktopPath = [Environment]::GetFolderPath('Desktop')
$vsBootstrapperPath = Join-Path $desktopPath "vs_enterprise_installer.exe"

try {
    # Remove existing installer if present
    if (Test-Path $vsBootstrapperPath) {
        Write-Host "  Removing existing installer..." -ForegroundColor Cyan
        Remove-Item $vsBootstrapperPath -Force -ErrorAction Stop
    }
    
    Write-Host "  Downloading Visual Studio 2026 Enterprise installer from Azure..." -ForegroundColor Cyan
    
    try {
        # Download from Azure Blob Storage (no redirect issues)
        Invoke-WebRequest -Uri $vsBootstrapperUrl `
            -OutFile $vsBootstrapperPath `
            -UserAgent "PowerShell" `
            -ErrorAction Stop
        
        # Validate the download
        if (-not (Test-Path $vsBootstrapperPath)) {
            throw "Download failed: Installer file not found at $vsBootstrapperPath"
        }
        
        $fileInfo = Get-Item $vsBootstrapperPath
        $fileSize = $fileInfo.Length
        
        Write-Host "  Downloaded $([math]::Round($fileSize/1MB, 2)) MB" -ForegroundColor Cyan
        
        # Check if file is a valid executable (MZ header)
        $bytes = [System.IO.File]::ReadAllBytes($vsBootstrapperPath)
        if ($bytes.Length -lt 2 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
            throw "Downloaded file is not a valid executable (missing MZ header)"
        }
        
        Write-Host "  ✓ Installer downloaded and verified successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  Download failed: $_" -ForegroundColor Red
        throw "Failed to download Visual Studio installer from Azure Storage"
    }
    
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
    
    # Install base product first, then workloads
    Write-Host ""
    Write-Host "  Phase 1: Installing Visual Studio 2026 Enterprise base..." -ForegroundColor Cyan
    $baseInstallStart = Get-Date
    
    $baseInstallArgs = @(
        "--quiet"
        "--norestart"
        "--wait"
        "--nocache"
    )
    
    $baseProcess = Start-Process -FilePath $vsBootstrapperPath -ArgumentList $baseInstallArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop
    $baseInstallEnd = Get-Date
    $baseInstallDuration = ($baseInstallEnd - $baseInstallStart).TotalSeconds
    
    if ($baseProcess.ExitCode -eq 0 -or $baseProcess.ExitCode -eq 3010) {
        Write-Host "  ✓ Base installation completed in $([math]::Round($baseInstallDuration, 1)) seconds" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ Base installation failed (Exit code: $($baseProcess.ExitCode))" -ForegroundColor Red
        throw "Base installation failed"
    }
    
    # Install workloads one by one with progress reporting
    Write-Host ""
    Write-Host "  Phase 2: Installing workloads..." -ForegroundColor Cyan
    $workloadNumber = 0
    $totalWorkloads = $workloads.Count
    
    foreach ($workload in $workloads) {
        $workloadNumber++
        $workloadName = $workload -replace '^Microsoft\.VisualStudio\.Workload\.', ''
        
        Write-Host "  [$workloadNumber/$totalWorkloads] Installing $workloadName..." -ForegroundColor Yellow
        $workloadStart = Get-Date
        
        $workloadArgs = @(
            "modify"
            "--installPath"
            "C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
            "--quiet"
            "--norestart"
            "--wait"
            "--add"
            $workload
        )
        
        $workloadProcess = Start-Process -FilePath $vsBootstrapperPath -ArgumentList $workloadArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop
        $workloadEnd = Get-Date
        $workloadDuration = ($workloadEnd - $workloadStart).TotalSeconds
        
        if ($workloadProcess.ExitCode -eq 0 -or $workloadProcess.ExitCode -eq 3010) {
            Write-Host "    ✓ $workloadName completed in $([math]::Round($workloadDuration, 1)) seconds" -ForegroundColor Green
        }
        else {
            Write-Host "    ✗ $workloadName failed (Exit code: $($workloadProcess.ExitCode))" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "  ✓ Visual Studio 2026 Enterprise installation completed" -ForegroundColor Green
    if ($baseProcess.ExitCode -eq 3010) {
        Write-Host "  Note: A restart may be required to complete the installation" -ForegroundColor Yellow
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
