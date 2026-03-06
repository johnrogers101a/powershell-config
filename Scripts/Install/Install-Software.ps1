#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs required software based on platform and profile.

.DESCRIPTION
    Reads the flat software[] array from the profile. Each entry declares per-OS installer
    mappings. The correct installer for the current OS is selected and delegated to the
    appropriate installer script (winget, brew, brew-cask, flatpak, script).
    If an entry has no installer for the current OS, it is skipped with a log message.
    Idempotent — installer scripts check before installing.

.PARAMETER Platform
    Platform object with OS, IsWindows, IsMacOS, IsLinux properties

.PARAMETER Profile
    Profile object with a flat software[] array (new schema)

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

$software = $Profile.software

if (-not $software -or $software.Count -eq 0) {
    Write-Host "No software defined in profile" -ForegroundColor Yellow
    return
}

# ── Homebrew path setup (Linux / macOS) ──────────────────────────────────────
if ($Platform.IsLinux -or $Platform.IsMacOS) {
    $brewPaths = @(
        "/home/linuxbrew/.linuxbrew/bin/brew",   # Linuxbrew
        "/opt/homebrew/bin/brew",                 # macOS Apple Silicon
        "/usr/local/bin/brew"                     # macOS Intel
    )
    $brewBin = $brewPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $brewBin) {
        Write-Host "Homebrew not found — installing..." -ForegroundColor Yellow
        bash -c '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        $brewBin = $brewPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    }

    if ($brewBin) {
        $brewDir = Split-Path $brewBin
        if ($env:PATH -notlike "*$brewDir*") {
            $env:PATH = "${brewDir}:$env:PATH"
        }
    }
    else {
        Write-Host "✗ Homebrew could not be located after install attempt." -ForegroundColor Red
    }
}

# ── WinGet initialization (Windows only) ────────────────────────────────────
if ($Platform.IsWindows) {
    Write-Host "Initializing winget..." -ForegroundColor Gray
    $null = winget list --source winget 2>&1
    Write-Host ""
}

# ── Installer script paths ───────────────────────────────────────────────────
$winGetScript  = Join-Path $ScriptsRoot "Install/Install-WithWinGet.ps1"
$brewScript    = Join-Path $ScriptsRoot "Install/Install-WithBrew.ps1"
$flatpakScript = Join-Path $ScriptsRoot "Install/Install-WithFlatpak.ps1"

# ── Install each package ─────────────────────────────────────────────────────
$osKey = $Platform.OS  # "windows", "macos", or "linux"

foreach ($entry in $software) {
    $id          = $entry.id
    $description = $entry.description

    # Look up installer for current OS
    $installer = $entry.installers.$osKey

    if (-not $installer) {
        Write-Host "Skipping '$id' — not configured for $osKey" -ForegroundColor DarkGray
        continue
    }

    Write-Host "[$id] $description" -ForegroundColor White

    $success = $false

    switch ($installer.manager) {
        "winget" {
            $success = & $winGetScript -PackageId $installer.id
        }
        "brew" {
            $success = & $brewScript -PackageId $installer.id -Type "formula"
        }
        "brew-cask" {
            $success = & $brewScript -PackageId $installer.id -Type "cask"
        }
        "flatpak" {
            $success = & $flatpakScript -PackageId $installer.id
        }
        "script" {
            Write-Host "  Running install script from $($installer.url) ..." -ForegroundColor Yellow
            try {
                if ($Platform.IsWindows) {
                    $tmp = [System.IO.Path]::GetTempFileName() + ".ps1"
                    Invoke-WebRequest -Uri $installer.url -OutFile $tmp -UseBasicParsing -ErrorAction Stop
                    & $tmp
                    Remove-Item $tmp -ErrorAction SilentlyContinue
                }
                else {
                    bash -c "curl -fsSL '$($installer.url)' | bash"
                }
                $success = ($LASTEXITCODE -eq 0)
                if ($success) {
                    Write-Host "  ✓ Script completed successfully" -ForegroundColor Green
                }
                else {
                    Write-Host "  ✗ Script exited with code $LASTEXITCODE" -ForegroundColor Red
                }
            }
            catch {
                Write-Host "  ✗ Script failed: $_" -ForegroundColor Red
                $success = $false
            }
        }
        default {
            Write-Host "  ✗ Unknown manager '$($installer.manager)' for '$id'" -ForegroundColor Red
        }
    }

    # Run postInstall command if present and install succeeded (or package was already present)
    if ($installer.postInstall) {
        Write-Host "  Post-install: $($installer.postInstall)" -ForegroundColor Gray
        try {
            $parts = $installer.postInstall -split '\s+', 2
            if ($parts.Count -eq 1) {
                & $parts[0]
            }
            else {
                $argString = $parts[1]
                if ($Platform.IsWindows) {
                    & $parts[0] ($argString -split '\s+')
                }
                else {
                    bash -c "$($installer.postInstall)"
                }
            }
        }
        catch {
            Write-Host "  Note: post-install step had an issue: $_" -ForegroundColor Yellow
        }
    }

    Write-Host ""
}

