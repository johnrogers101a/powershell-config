#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists user-installed software, excluding built-in and pre-installed packages.

.DESCRIPTION
    Cross-platform command that shows software explicitly installed by the user:
    - Windows: Uses winget, filters out MSIX Store apps, ARP entries, and system dependencies
    - macOS: Uses Homebrew (brew list) which inherently only shows user-installed packages
    
    Excludes common system/dependency packages like VCLibs, UI.Xaml, .NET Native, etc.

.PARAMETER Raw
    Returns raw output from the package manager instead of parsed objects.

.EXAMPLE
    Get-Software
    # Returns list of user-installed software as objects

.EXAMPLE
    Get-Software -Raw
    # Returns raw winget/brew output (filtered)

.OUTPUTS
    PSCustomObject[] with Name, Id, Version properties (default)
    String[] when -Raw is specified
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Raw
)

$ErrorActionPreference = 'Stop'

# Get platform info
$coreScriptsDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Core"
$platformScript = Join-Path $coreScriptsDir "Get-PlatformInfo.ps1"
$platform = & $platformScript

# Patterns for built-in/dependency packages to exclude (Windows)
$windowsExcludePatterns = @(
    'MSIX\\',                    # Store apps
    'ARP\\',                     # Pre-installed apps (Add/Remove Programs)
    'Microsoft\.UI\.Xaml',       # UI framework dependencies
    'Microsoft\.VCLibs',         # VC++ runtime libraries
    'Microsoft\.VCRedist',       # VC++ redistributables
    'Microsoft\.NET\.Native',    # .NET native packages
    'Microsoft\.AppInstaller',   # Winget itself
    'Microsoft\.OpenCL'          # Graphics compatibility layer
)

function Get-WindowsSoftware {
    param([switch]$RawOutput)
    
    $output = winget list --source winget 2>$null
    if (-not $output) {
        Write-Warning "No output from winget. Is winget installed?"
        return @()
    }
    
    $lines = $output -split "`n"
    
    # Find the separator line (---) to skip headers
    $separatorIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^-+$') {
            $separatorIndex = $i
            break
        }
    }
    
    if ($separatorIndex -lt 0) {
        Write-Warning "Could not parse winget output format"
        return @()
    }
    
    # Get header line to determine column positions
    $headerLine = $lines[$separatorIndex - 1]
    $idStart = $headerLine.IndexOf('Id')
    $versionStart = $headerLine.IndexOf('Version')
    
    # Build exclusion regex
    $excludeRegex = ($windowsExcludePatterns -join '|')
    
    # Process data lines
    $dataLines = $lines | Select-Object -Skip ($separatorIndex + 1)
    $results = @()
    
    foreach ($line in $dataLines) {
        # Skip empty lines and excluded patterns
        if (-not $line -or $line -match '^\s*$') { continue }
        if ($line -match $excludeRegex) { continue }
        
        if ($RawOutput) {
            $results += $line
        }
        else {
            # Parse fixed-width columns
            if ($line.Length -ge $versionStart) {
                $name = $line.Substring(0, [Math]::Min($idStart, $line.Length)).Trim()
                $id = $line.Substring($idStart, [Math]::Min($versionStart - $idStart, $line.Length - $idStart)).Trim()
                $version = $line.Substring($versionStart).Trim() -split '\s+' | Select-Object -First 1
                
                $results += [PSCustomObject]@{
                    Name    = $name
                    Id      = $id
                    Version = $version
                }
            }
        }
    }
    
    return $results
}

function Get-MacOSSoftware {
    param([switch]$RawOutput)
    
    $results = @()
    
    # Get formulae (command-line packages)
    $formulae = brew list --formula 2>$null
    if ($formulae) {
        foreach ($pkg in ($formulae -split "`n" | Where-Object { $_ })) {
            if ($RawOutput) {
                $results += "$pkg (formula)"
            }
            else {
                $version = (brew info --json=v2 $pkg 2>$null | ConvertFrom-Json).formulae[0].versions.stable
                $results += [PSCustomObject]@{
                    Name    = $pkg
                    Id      = $pkg
                    Version = $version
                }
            }
        }
    }
    
    # Get casks (GUI applications)
    $casks = brew list --cask 2>$null
    if ($casks) {
        foreach ($pkg in ($casks -split "`n" | Where-Object { $_ })) {
            if ($RawOutput) {
                $results += "$pkg (cask)"
            }
            else {
                $version = (brew info --json=v2 --cask $pkg 2>$null | ConvertFrom-Json).casks[0].version
                $results += [PSCustomObject]@{
                    Name    = $pkg
                    Id      = "$pkg (cask)"
                    Version = $version
                }
            }
        }
    }
    
    return $results
}

# Execute based on platform
if ($platform.IsWindows) {
    Get-WindowsSoftware -RawOutput:$Raw
}
elseif ($platform.IsMacOS) {
    Get-MacOSSoftware -RawOutput:$Raw
}
else {
    Write-Warning "Unsupported platform: $($platform.OS)"
}
