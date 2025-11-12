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

# Display loaded custom commands
Write-Host ""
Write-Host "Custom Commands Available:" -ForegroundColor Cyan
Write-Host "  Get-GitBranches           " -NoNewline -ForegroundColor Green
Write-Host "- Retrieve all git branches (local and remote)" -ForegroundColor Gray
Write-Host "  Set-DefaultWorkingDirectory " -NoNewline -ForegroundColor Green
Write-Host "- Navigate to default working directory" -ForegroundColor Gray
Write-Host "  Install-ModuleIfMissing   " -NoNewline -ForegroundColor Green
Write-Host "- Install PowerShell modules on-demand" -ForegroundColor Gray
Write-Host ""
