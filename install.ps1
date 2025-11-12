#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs PowerShell profile configuration files to the user's profile directory.

.DESCRIPTION
    This script installs required software (PowerShell, Git, Oh My Posh) and copies 
    the PowerShell profile files and modules to the appropriate locations. 
    Works on Windows, macOS, and Linux. Configuration is driven by install-config.json.

.EXAMPLE
    ./install.ps1
    Installs the software and profile files to the default PowerShell profile location.
#>

[CmdletBinding()]
param()

#region Configuration
$AzureBaseUrl = "https://stprofilewus3.blob.core.windows.net/profile-config"
$ConfigFileName = "install-config.json"
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
#endregion

#region Platform Detection
class PlatformInfo {
    [string]$OS
    [bool]$IsWindows
    [bool]$IsMacOS

    PlatformInfo() {
        $this.IsWindows = (-not (Test-Path variable:global:IsWindows)) -or $global:IsWindows
        $this.IsMacOS = (Test-Path variable:global:IsMacOS) -and $global:IsMacOS
        
        if ($this.IsWindows) {
            $this.OS = "windows"
        }
        elseif ($this.IsMacOS) {
            $this.OS = "macos"
        }
        else {
            throw "Unsupported operating system. This installer only supports Windows and macOS."
        }
    }
}
#endregion

#region File Operations
class FileManager {
    [string]$AzureBaseUrl

    FileManager([string]$baseUrl) {
        $this.AzureBaseUrl = $baseUrl
    }

    [bool] DownloadFile([string]$fileName, [string]$destinationPath) {
        Write-Host "  Downloading $fileName..." -ForegroundColor Cyan
        try {
            $url = "$($this.AzureBaseUrl)/$fileName"
            
            # Ensure the directory exists
            $parentDir = Split-Path -Parent $destinationPath
            if ($parentDir -and -not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            
            Invoke-WebRequest -Uri $url -OutFile $destinationPath -ErrorAction Stop
            Write-Host "    Downloaded successfully" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "    Failed to download: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    [void] BackupFile([string]$filePath) {
        if (Test-Path $filePath) {
            $backupPath = "$filePath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Write-Host "  Backing up existing $(Split-Path -Leaf $filePath)..." -ForegroundColor Yellow
            Copy-Item -Path $filePath -Destination $backupPath -Force
        }
    }

    [PSCustomObject] LoadConfiguration([string]$configPath, [string]$configFileName) {
        if (Test-Path $configPath) {
            Write-Host "Loading configuration from local file..." -ForegroundColor Cyan
            return Get-Content $configPath -Raw | ConvertFrom-Json
        }
        else {
            Write-Host "Downloading configuration from Azure..." -ForegroundColor Cyan
            $tempConfig = Join-Path $env:TEMP $configFileName
            if ($this.DownloadFile($configFileName, $tempConfig)) {
                return Get-Content $tempConfig -Raw | ConvertFrom-Json
            }
            else {
                throw "Failed to load configuration file"
            }
        }
    }
}
#endregion

#region Package Manager Operations
class PackageManagerBase {
    [string]$Name
    
    PackageManagerBase([string]$name) {
        $this.Name = $name
    }

    [bool] IsAvailable() {
        return $null -ne (Get-Command $this.Name -ErrorAction SilentlyContinue)
    }

    [bool] Install([PSCustomObject]$package) {
        throw "Install method must be implemented by derived class"
    }

    [bool] IsPackageInstalled([string]$command) {
        return $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    }
}

class WinGetManager : PackageManagerBase {
    WinGetManager() : base("winget") {}

    [bool] Install([PSCustomObject]$package) {
        Write-Host "  Installing $($package.name) via winget..." -ForegroundColor Cyan
        $args = $package.installArgs -join " "
        $result = winget install $package.installArgs 2>&1
        return $LASTEXITCODE -eq 0
    }
}

class BrewManager : PackageManagerBase {
    BrewManager() : base("brew") {}

    [bool] Install([PSCustomObject]$package) {
        Write-Host "  Installing $($package.name) via Homebrew..." -ForegroundColor Cyan
        $result = & brew @($package.installArgs) 2>&1
        return $LASTEXITCODE -eq 0
    }

    [void] UpdateEnvironment() {
        # Update PATH for current session
        if (Test-Path "/opt/homebrew/bin/brew") {
            $env:PATH = "/opt/homebrew/bin:$env:PATH"
            & /opt/homebrew/bin/brew shellenv | Invoke-Expression
        }
        elseif (Test-Path "/usr/local/bin/brew") {
            $env:PATH = "/usr/local/bin:$env:PATH"
            & /usr/local/bin/brew shellenv | Invoke-Expression
        }
    }
}
#endregion

#region Software Installer
class SoftwareInstaller {
    [PlatformInfo]$Platform
    [PackageManagerBase]$PackageManager
    [PSCustomObject]$Config

    SoftwareInstaller([PlatformInfo]$platform, [PSCustomObject]$config) {
        $this.Platform = $platform
        $this.Config = $config
        $this.PackageManager = $this.InitializePackageManager()
    }

    [PackageManagerBase] InitializePackageManager() {
        if ($this.Platform.IsWindows) {
            return [WinGetManager]::new()
        }
        elseif ($this.Platform.IsMacOS) {
            return [BrewManager]::new()
        }
        return $null
    }

    [void] InstallSoftware() {
        $softwareList = $this.Config.software.($this.Platform.OS)
        
        if (-not $softwareList) {
            Write-Host "No software configuration found for $($this.Platform.OS)" -ForegroundColor Yellow
            return
        }

        Write-Host ""
        Write-Host "Checking required software..." -ForegroundColor Green
        Write-Host ""

        foreach ($package in $softwareList) {
            # Check if already installed (idempotency)
            if ($this.PackageManager.IsPackageInstalled($package.command)) {
                Write-Host "✓ $($package.name) is already installed" -ForegroundColor Green
                continue
            }

            Write-Host "Installing $($package.name)..." -ForegroundColor Yellow

            # Check if package manager is available
            if (-not $this.PackageManager.IsAvailable()) {
                Write-Host "  Error: $($this.PackageManager.Name) is not available" -ForegroundColor Red
                if ($this.PackageManager.Name -eq "brew") {
                    Write-Host "  Install Homebrew: https://brew.sh" -ForegroundColor Yellow
                }
                continue
            }

            # Install the package
            $success = $this.PackageManager.Install($package)
            
            if ($success) {
                Write-Host "  ✓ $($package.name) installed successfully" -ForegroundColor Green
                
                # Update environment if using Homebrew
                if ($this.PackageManager -is [BrewManager]) {
                    $this.PackageManager.UpdateEnvironment()
                }
            }
            else {
                Write-Host "  ✗ Failed to install $($package.name)" -ForegroundColor Red
            }
        }
    }

    [void] InstallFonts() {
        # Check if oh-my-posh is available
        if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
            Write-Host "Skipping font installation (oh-my-posh not available)" -ForegroundColor Yellow
            return
        }

        Write-Host ""
        Write-Host "Installing fonts..." -ForegroundColor Green
        
        foreach ($font in $this.Config.fonts) {
            Write-Host "  Installing $($font.name)..." -ForegroundColor Cyan
            $installCmd = $font.installCommand -split ' '
            & $installCmd[0] @($installCmd[1..($installCmd.Length - 1)]) 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ $($font.name) installed successfully" -ForegroundColor Green
            }
            else {
                Write-Host "  Note: Font may already be installed or installation skipped" -ForegroundColor Yellow
            }
        }
    }
}
#endregion

#region Profile Installer
class ProfileInstaller {
    [string]$ProfileDir
    [string]$ModulesDir
    [FileManager]$FileManager
    [PSCustomObject]$Config

    ProfileInstaller([FileManager]$fileManager, [PSCustomObject]$config) {
        $this.ProfileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
        $this.ModulesDir = Join-Path $this.ProfileDir "Modules"
        $this.FileManager = $fileManager
        $this.Config = $config
    }

    [void] Install() {
        Write-Host ""
        Write-Host "Installing profile configuration..." -ForegroundColor Green
        Write-Host "Target Directory: " -NoNewline
        Write-Host $this.ProfileDir -ForegroundColor Yellow
        Write-Host ""

        # Create profile directory if it doesn't exist
        if (-not (Test-Path $this.ProfileDir)) {
            Write-Host "Creating profile directory..." -ForegroundColor Cyan
            New-Item -ItemType Directory -Path $this.ProfileDir -Force | Out-Null
        }

        # Install profile files
        Write-Host "Installing profile files..." -ForegroundColor Cyan
        foreach ($file in $this.Config.profileFiles) {
            $destPath = Join-Path $this.ProfileDir $file
            $this.FileManager.BackupFile($destPath)
            
            $success = $this.FileManager.DownloadFile($file, $destPath)
            if (-not $success) {
                Write-Host "  Error: Failed to install $file" -ForegroundColor Red
            }
        }

        # Install modules
        Write-Host ""
        Write-Host "Installing modules..." -ForegroundColor Cyan
        foreach ($modulePath in $this.Config.moduleFiles) {
            $destPath = Join-Path $this.ProfileDir $modulePath
            $success = $this.FileManager.DownloadFile($modulePath, $destPath)
            if (-not $success) {
                Write-Host "  Error: Failed to install $modulePath" -ForegroundColor Red
            }
        }
    }

    [void] LoadProfile() {
        Write-Host ""
        Write-Host "Loading profile..." -ForegroundColor Cyan
        try {
            . $global:PROFILE.CurrentUserAllHosts
            Write-Host "Profile loaded successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host "Note: Profile will be loaded when you start a new PowerShell session." -ForegroundColor Yellow
        }
    }
}
#endregion

#region Main Installation Orchestrator
class InstallationOrchestrator {
    [PlatformInfo]$Platform
    [FileManager]$FileManager
    [PSCustomObject]$Config
    [SoftwareInstaller]$SoftwareInstaller
    [ProfileInstaller]$ProfileInstaller

    InstallationOrchestrator([string]$azureBaseUrl, [string]$configPath, [string]$configFileName) {
        $this.Platform = [PlatformInfo]::new()
        $this.FileManager = [FileManager]::new($azureBaseUrl)
        $this.Config = $this.FileManager.LoadConfiguration($configPath, $configFileName)
        $this.SoftwareInstaller = [SoftwareInstaller]::new($this.Platform, $this.Config)
        $this.ProfileInstaller = [ProfileInstaller]::new($this.FileManager, $this.Config)
    }

    [void] Run() {
        $this.ShowHeader()
        $this.SoftwareInstaller.InstallSoftware()
        $this.SoftwareInstaller.InstallFonts()
        $this.ProfileInstaller.Install()
        $this.ProfileInstaller.LoadProfile()
        $this.ShowFooter()
    }

    [void] ShowHeader() {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "PowerShell Profile Configuration Installer" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Platform: " -NoNewline
        Write-Host $this.Platform.OS -ForegroundColor Yellow
        Write-Host "Installation Mode: " -NoNewline
        Write-Host "Cloud (Azure Blob Storage)" -ForegroundColor Yellow
    }

    [void] ShowFooter() {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Installation Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor Cyan
        Write-Host "  1. Restart your terminal or run: " -NoNewline
        Write-Host ". `$PROFILE" -ForegroundColor Yellow
        Write-Host "  2. Configure your terminal to use the Meslo Nerd Font" -ForegroundColor White
        Write-Host ""
    }
}
#endregion

#region Entry Point
try {
    $configPath = Join-Path $ScriptDir $ConfigFileName
    $orchestrator = [InstallationOrchestrator]::new($AzureBaseUrl, $configPath, $ConfigFileName)
    $orchestrator.Run()
}
catch {
    Write-Host ""
    Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}
#endregion
