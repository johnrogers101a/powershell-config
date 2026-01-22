#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs the PowerShell profile installer from Azure.

.DESCRIPTION
    Shortcut to run the one-line installer that downloads and executes
    install.ps1 from Azure Blob Storage. All parameters are passed through
    to install.ps1.

.EXAMPLE
    Invoke-Installer
    Invoke-Installer -Profile "dev-workstation"
    Invoke-Installer -No-Install

.OUTPUTS
    None
#>

# Pass all arguments through to install.ps1
$ErrorActionPreference = 'Stop'

Write-Host "Running PowerShell profile installer from Azure..." -ForegroundColor Cyan
Write-Host ""

# Set execution policy for this process
Set-ExecutionPolicy Bypass -Scope Process -Force

# Ensure TLS 1.2+
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# Download installer script
$installerUrl = "https://stprofilewus3.blob.core.windows.net/profile-config/install.ps1"
$installerScript = (New-Object System.Net.WebClient).DownloadString($installerUrl)

# Create script block and pass through all arguments
$scriptBlock = [scriptblock]::Create($installerScript)
& $scriptBlock @args
