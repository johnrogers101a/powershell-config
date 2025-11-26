#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configures Windows Terminal settings.

.DESCRIPTION
    Sets PowerShell 7 as the default profile.
    Sets Windows Terminal as the default terminal application (requires registry/admin).
    
    Note: Setting default terminal application programmatically is restricted in Windows 11.
    We can modify the settings.json for the default profile, but the OS-level "Default Terminal Application"
    setting usually requires user interaction or specific registry keys that might be protected.
    We will attempt to set the "defaultProfile" in settings.json.

.EXAMPLE
    & "$PSScriptRoot/Configure-WindowsTerminal.ps1"
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "Configuring Windows Terminal..." -ForegroundColor Cyan

# Path to Windows Terminal settings.json
# It can be in a few places depending on install (Store vs unpackaged)
$settingsPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
)

$settingsFile = $settingsPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $settingsFile) {
    Write-Warning "Windows Terminal settings.json not found. Is Windows Terminal installed?"
    return
}

try {
    $jsonContent = Get-Content -Path $settingsFile -Raw
    $settings = $jsonContent | ConvertFrom-Json

    # Handle both new (profiles.list) and old (profiles array) schemas
    $profilesList = if ($settings.profiles.list) { $settings.profiles.list } else { $settings.profiles }

    # Find PowerShell 7 profile GUID
    # We look for "pwsh.exe" or name "PowerShell" (not "Windows PowerShell")
    $pwshProfile = $profilesList | Where-Object { 
        ($_.commandline -like "*pwsh.exe*") -or ($_.name -eq "PowerShell") 
    } | Select-Object -First 1

    if ($pwshProfile) {
        $changesMade = $false
        $guid = $pwshProfile.guid
        
        # 1. Set Default Profile
        if ($settings.defaultProfile -ne $guid) {
            Write-Host "Setting default profile to PowerShell 7 ($($pwshProfile.name))..." -ForegroundColor Yellow
            $settings.defaultProfile = $guid
            $changesMade = $true
        } else {
            Write-Host "✓ PowerShell 7 is already the default profile" -ForegroundColor Green
        }

        # 2. Set Font
        $targetFont = "MesloLGM Nerd Font Mono"
        
        # Check if font object exists (newer schema) or fontFace property (older schema)
        if ($pwshProfile | Get-Member -Name "font") {
            if ($pwshProfile.font.face -ne $targetFont) {
                Write-Host "Setting font to $targetFont..." -ForegroundColor Yellow
                $pwshProfile.font.face = $targetFont
                $changesMade = $true
            } else {
                Write-Host "✓ Font is already $targetFont" -ForegroundColor Green
            }
        } elseif ($pwshProfile | Get-Member -Name "fontFace") {
            if ($pwshProfile.fontFace -ne $targetFont) {
                Write-Host "Setting fontFace to $targetFont..." -ForegroundColor Yellow
                $pwshProfile.fontFace = $targetFont
                $changesMade = $true
            } else {
                Write-Host "✓ Font is already $targetFont" -ForegroundColor Green
            }
        } else {
            # Create font object if missing (assuming newer schema preference)
            Write-Host "Adding font configuration..." -ForegroundColor Yellow
            $pwshProfile | Add-Member -MemberType NoteProperty -Name "font" -Value @{ face = $targetFont }
            $changesMade = $true
        }

        if ($changesMade) {
            # Save settings
            $settings | ConvertTo-Json -Depth 100 | Set-Content -Path $settingsFile
            Write-Host "✓ Windows Terminal settings updated" -ForegroundColor Green
        }
    } else {
        Write-Warning "PowerShell 7 profile not found in Windows Terminal settings."
        Write-Host "Available profiles:" -ForegroundColor Gray
        $profilesList | ForEach-Object { Write-Host "  - $($_.name) ($($_.commandline))" -ForegroundColor Gray }
    }

    # 3. Set Default Terminal Application (Registry)
    Write-Host "Setting Windows Terminal as default terminal application..." -ForegroundColor Cyan
    $regPath = "HKCU:\Console\%%Startup"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    # GUID for Windows Terminal
    $wtGuid = "{2EACA947-7F5F-4CFA-BA87-8F7FBEEF33F3}"
    
    Set-ItemProperty -Path $regPath -Name "DelegationConsole" -Value $wtGuid -Type String
    Set-ItemProperty -Path $regPath -Name "DelegationTerminal" -Value $wtGuid -Type String
    Write-Host "✓ Windows Terminal set as default terminal application" -ForegroundColor Green

} catch {
    Write-Host "✗ Failed to update Windows Terminal settings: $_" -ForegroundColor Red
}

# Setting "Default Terminal Application" programmatically is complex and often blocked by Windows for security.
# It modifies HKCU\Console\%%Startup\DelegationConsole and requires a specific GUID for the terminal app.
# {2EACA947-7F5F-4CFA-BA87-8F7FBEEF33F0} is often the ID for Windows Terminal.
# However, this is best left to the user or a specific registry tweak if we are sure.
# Let's try to set the registry key if we are Admin.

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "Attempting to set Windows Terminal as default terminal application..." -ForegroundColor Cyan
    try {
        $regPath = "HKCU:\Console\%%Startup"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        
        # GUID for Windows Terminal
        $wtGuid = "{2EACA947-7F5F-4CFA-BA87-8F7FBEEF33F0}"
        
        Set-ItemProperty -Path $regPath -Name "DelegationConsole" -Value $wtGuid -Type String -Force
        Set-ItemProperty -Path $regPath -Name "DelegationTerminal" -Value $wtGuid -Type String -Force
        
        Write-Host "✓ Registry keys updated for Default Terminal Application" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to set default terminal application via registry: $_"
    }
} else {
    Write-Warning "Administrator privileges required to set Windows Terminal as default system terminal."
}
