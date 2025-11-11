#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs PowerShell profile configuration files to the user's profile directory.

.DESCRIPTION
    This script copies the PowerShell profile files and modules to the appropriate
    locations in the user's PowerShell profile directory. Works on Windows, macOS, and Linux.
    If files are not present locally, it will download them from Azure Blob Storage.

.EXAMPLE
    ./install.ps1
    Installs the profile files to the default PowerShell profile location.
#>

[CmdletBinding()]
param()

# Azure Blob Storage configuration
$AzureBaseUrl = "https://stprofilewus3.blob.core.windows.net/profile-config"

# Detect OS (works in both Windows PowerShell and PowerShell Core)
$IsWindowsOS = (-not (Test-Path variable:IsWindows)) -or $IsWindows
$IsMacOSPlatform = (Test-Path variable:IsMacOS) -and $IsMacOS
$IsLinuxPlatform = (Test-Path variable:IsLinux) -and $IsLinux

# Check if PowerShell Core (pwsh) needs to be installed
$pwshInstalled = Get-Command pwsh -ErrorAction SilentlyContinue

if (-not $pwshInstalled) {
    Write-Host "PowerShell Core not found. Installing..." -ForegroundColor Yellow
    Write-Host ""
    
    if ($IsMacOSPlatform) {
        # macOS - use Homebrew
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            Write-Host "Installing PowerShell via Homebrew..." -ForegroundColor Cyan
            brew install --cask powershell
            
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
        else {
            Write-Host "Error: Homebrew not found. Please install Homebrew first: https://brew.sh" -ForegroundColor Red
            exit 1
        }
    }
    elseif ($IsWindowsOS) {
        # Windows - use winget
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Installing PowerShell via winget..." -ForegroundColor Cyan
            winget install -e --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements
            
            # Refresh PATH for current session
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        }
        else {
            Write-Host "Error: winget not found. Please install PowerShell manually: https://aka.ms/powershell" -ForegroundColor Red
            exit 1
        }
    }
    elseif ($IsLinuxPlatform) {
        # Linux - detect distro and use appropriate package manager
        if (Test-Path "/etc/os-release") {
            $osInfo = Get-Content "/etc/os-release" | ConvertFrom-StringData
            $distroId = $osInfo.ID
            
            Write-Host "Installing PowerShell on $distroId..." -ForegroundColor Cyan
            
            if ($distroId -match "ubuntu|debian") {
                # Ubuntu/Debian
                $ubuntuCmd = 'sudo apt-get update && sudo apt-get install -y wget apt-transport-https software-properties-common && wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" && sudo dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb && sudo apt-get update && sudo apt-get install -y powershell'
                bash -c $ubuntuCmd
            }
            elseif ($distroId -match "fedora|rhel|centos") {
                # Fedora/RHEL/CentOS
                $fedoraCmd = 'sudo dnf install -y https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm && sudo dnf install -y powershell'
                bash -c $fedoraCmd
            }
            else {
                Write-Host "Error: Unsupported Linux distribution. Please install PowerShell manually: https://aka.ms/powershell" -ForegroundColor Red
                exit 1
            }
        }
    }
    
    Write-Host ""
    Write-Host "PowerShell installed successfully!" -ForegroundColor Green
    Write-Host ""
}

# Function to download file from Azure Blob Storage
function Get-FileFromAzure {
    param(
        [string]$FileName,
        [string]$DestinationPath
    )
    
    Write-Host "  Downloading $FileName..." -ForegroundColor Cyan
    try {
        $url = "$AzureBaseUrl/$FileName"
        
        # Ensure the directory exists
        $parentDir = Split-Path -Parent $DestinationPath
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        
        Invoke-WebRequest -Uri $url -OutFile $DestinationPath -ErrorAction Stop
        Write-Host "    Downloaded successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "    Failed to download: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Get the PowerShell profile directory (works across all platforms)
$ProfileDir = Split-Path -Parent $PROFILE.CurrentUserAllHosts
$ModulesDir = Join-Path $ProfileDir "Modules"

Write-Host ""
Write-Host "PowerShell Profile Configuration Installer" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation Mode: " -NoNewline
Write-Host "Cloud (Azure Blob Storage)" -ForegroundColor Yellow
Write-Host "Target Directory: " -NoNewline
Write-Host $ProfileDir -ForegroundColor Yellow
Write-Host ""

# Create profile directory if it doesn't exist
if (-not (Test-Path $ProfileDir)) {
    Write-Host "Creating profile directory..." -ForegroundColor Green
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

# Files to download
$FilesToDownload = @(
    "Microsoft.PowerShell_profile.ps1"
    "Microsoft.VSCode_profile.ps1"
    "omp.json"
)

# Download profile files
Write-Host "Downloading profile files..." -ForegroundColor Green
foreach ($File in $FilesToDownload) {
    $DestPath = Join-Path $ProfileDir $File
    
    # Backup existing file if it exists
    if (Test-Path $DestPath) {
        $BackupPath = "$DestPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Write-Host "  Backing up existing $File..." -ForegroundColor Yellow
        Copy-Item -Path $DestPath -Destination $BackupPath -Force
    }
    
    # Download from Azure
    $success = Get-FileFromAzure -FileName $File -DestinationPath $DestPath
    if (-not $success) {
        Write-Host "  Error: Failed to download $File" -ForegroundColor Red
    }
}

# Download modules
Write-Host ""
Write-Host "Downloading modules..." -ForegroundColor Green

$ModuleFiles = @(
    "Modules/ProfileSetup/ProfileSetup.psm1"
)

foreach ($ModulePath in $ModuleFiles) {
    $DestPath = Join-Path $ProfileDir $ModulePath
    $success = Get-FileFromAzure -FileName $ModulePath -DestinationPath $DestPath
    if (-not $success) {
        Write-Host "  Error: Failed to download $ModulePath" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Files installed to: " -NoNewline
Write-Host $ProfileDir -ForegroundColor Yellow
Write-Host ""
Write-Host "Loading profile..." -ForegroundColor Cyan

# Reload the profile
try {
    . $PROFILE.CurrentUserAllHosts
    Write-Host "Profile loaded successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Note: Profile will be loaded when you start a new PowerShell session." -ForegroundColor Yellow
}

Write-Host ""
