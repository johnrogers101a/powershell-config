#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Initializes PowerShell profile with custom settings and modules.

.DESCRIPTION
    Sets up complete profile environment:
    - Adds ~/bin to PATH for git extensions
    - Installs required modules (Terminal-Icons, posh-git)
    - Configures PSReadLine for menu completion
    - Initializes oh-my-posh prompt with theme
    - Sets default working directory
    - Displays available custom commands
    
    Idempotent - safe to run multiple times.

.PARAMETER OhMyPoshConfig
    Path to oh-my-posh config file (default: omp.json in profile directory)

.PARAMETER DefaultWorkingDirectory
    Default working directory to navigate to (default: ~/code)

.PARAMETER ProfileScriptsDir
    Path to profile scripts directory (default: Scripts/Profile in profile directory)

.EXAMPLE
    & "$PSScriptRoot/Scripts/Profile/Initialize-PowerShellProfile.ps1"
    & "$PSScriptRoot/Scripts/Profile/Initialize-PowerShellProfile.ps1" -OhMyPoshConfig "./custom-omp.json"

.OUTPUTS
    None (configures environment and prints status)
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OhMyPoshConfig,
    
    [Parameter()]
    [string]$DefaultWorkingDirectory = '~/code',
    
    [Parameter()]
    [string]$ProfileScriptsDir
)

$ErrorActionPreference = 'Stop'

# Determine default paths relative to profile directory
$profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
if (-not $ProfileScriptsDir) {
    $ProfileScriptsDir = Join-Path $profileDir "Scripts/Profile"
}
if (-not $OhMyPoshConfig) {
    $OhMyPoshConfig = Join-Path $profileDir "omp.json"
}

# Add ~/bin to PATH for git extensions
$binPath = Join-Path $HOME "bin"
if ((Test-Path $binPath) -and ($env:PATH -notlike "*$binPath*")) {
    $env:PATH = $binPath + [IO.Path]::PathSeparator + $env:PATH
}

# Install required modules using helper script
$installModuleScript = Join-Path $ProfileScriptsDir "Install-ModuleIfMissing.ps1"
& $installModuleScript -ModuleName 'Terminal-Icons'
& $installModuleScript -ModuleName 'posh-git'

# Configure PSReadLine for better tab completion
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Initialize oh-my-posh
if (Test-Path $OhMyPoshConfig) {
    oh-my-posh init pwsh --config $OhMyPoshConfig | Invoke-Expression
}

# Set default working directory
$setDirScript = Join-Path $ProfileScriptsDir "Set-DefaultWorkingDirectory.ps1"
& $setDirScript -DefaultPath $DefaultWorkingDirectory

# Define custom commands as functions
function Get-GitBranches {
    $scriptPath = Join-Path $PSScriptRoot "Get-GitBranches.ps1"
    & $scriptPath @args
}

function Set-DefaultWorkingDirectory {
    $scriptPath = Join-Path $PSScriptRoot "Set-DefaultWorkingDirectory.ps1"
    & $scriptPath @args
}

function Install-ModuleIfMissing {
    $scriptPath = Join-Path $PSScriptRoot "Install-ModuleIfMissing.ps1"
    & $scriptPath @args
}

function Get-Software {
    $scriptPath = Join-Path $PSScriptRoot "Get-Software.ps1"
    & $scriptPath @args
}

# Profile management commands
function New-Profile {
    $scriptPath = Join-Path $PSScriptRoot "New-Profile.ps1"
    & $scriptPath @args
}

function Get-Profiles {
    $scriptPath = Join-Path $PSScriptRoot "Get-Profiles.ps1"
    & $scriptPath @args
}

function Get-Profile {
    $scriptPath = Join-Path $PSScriptRoot "Get-Profile.ps1"
    & $scriptPath @args
}

function Set-Profile {
    $scriptPath = Join-Path $PSScriptRoot "Set-Profile.ps1"
    & $scriptPath @args
}

function Remove-Profile {
    $scriptPath = Join-Path $PSScriptRoot "Remove-Profile.ps1"
    & $scriptPath @args
}

function Install-Profile {
    $scriptPath = Join-Path $PSScriptRoot "Install-Profile.ps1"
    & $scriptPath @args
}

function Publish-Profile {
    $scriptPath = Join-Path $PSScriptRoot "Publish-Profile.ps1"
    & $scriptPath @args
}

function Show-Commands {
    $profileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
    $scriptsDir = Join-Path $profileDir "Scripts/Profile"
    
    # Get all scripts, exclude Initialize, Install-ProfileFiles, and any backup copies
    $scripts = Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -ErrorAction SilentlyContinue |
        Where-Object { 
            $_.Name -notmatch '^Initialize-PowerShellProfile\.ps1$' -and
            $_.Name -notmatch '^Install-ProfileFiles\.ps1$' -and
            $_.Name -notmatch ' - Copy'
        }
    
    if (-not $scripts) {
        Write-Host "No custom commands found." -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "Custom Commands Available:" -ForegroundColor Cyan
    
    # Calculate max command name length for alignment
    $maxLen = ($scripts | ForEach-Object { $_.BaseName.Length } | Measure-Object -Maximum).Maximum + 2
    
    foreach ($script in $scripts | Sort-Object Name) {
        $cmdName = $script.BaseName
        $synopsis = ""
        
        # Extract .SYNOPSIS from script file
        $content = Get-Content $script.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match '\.SYNOPSIS\s*\r?\n\s*(.+?)(?:\r?\n\s*\r?\n|\.DESCRIPTION|\.PARAMETER|\.EXAMPLE)') {
            $synopsis = $Matches[1].Trim()
        }
        
        $padding = ' ' * ($maxLen - $cmdName.Length)
        Write-Host "  $cmdName$padding" -NoNewline -ForegroundColor Green
        Write-Host "- $synopsis" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "  Show-Commands$(' ' * ($maxLen - 13))" -NoNewline -ForegroundColor Green
    Write-Host "- Display this help message" -ForegroundColor Gray
    Write-Host ""
}

# Display loaded custom commands
Show-Commands
