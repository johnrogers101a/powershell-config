# PowerShell Profile Configuration - AI Coding Agent Instructions

## Project Overview

This is a **PowerShell profile configuration system for Windows and macOS** that installs custom profiles, scripts, Oh My Posh theming, and required software. Key architecture:

- **Script-Based Architecture**: Individual PowerShell scripts with parameters (no modules = no caching issues)
- **SOLID, DRY, YAGNI, Idempotent**: Single responsibility scripts, reusable functions, no unnecessary complexity, safe to run multiple times
- **JSON Configuration**: Modular `install-config.json` drives script installation; software profiles in `profiles/*.json`
- **Software Profiles**: Named profiles (e.g., `default.json`) define software packages per platform, stored in `profiles/` directory
- **Cloud deployment**: Downloads from Azure Blob Storage with cache-busting
- **Profile files**: `Microsoft.PowerShell_profile.ps1` (main console) and `Microsoft.VSCode_profile.ps1` (VS Code terminal)
- **Script organization**: `Scripts/` directory with Core/, Install/, Profile/, Utils/ subdirectories
- **Theme config**: `omp.json` defines Oh My Posh prompt appearance

## Critical Installation Flow

`install.ps1` orchestrates the entire installation using script-based architecture:

1. **Bootstrap**: Downloads core installation scripts to temp directory with cache-busting
2. **Platform Detection**: `Get-PlatformInfo.ps1` returns platform object (Windows/macOS only, Linux not supported)
3. **Configuration Loading**: `Get-ConfigFromAzure.ps1` loads `install-config.json` (local or from Azure)
4. **Software Profile Loading**: Downloads profile JSON from `profiles/<name>.json` (default: `default`)
5. **Software Installation**: `Install-Software.ps1` installs packages from profile using winget/brew
6. **Font Installation**: `Install-Fonts.ps1` installs Meslo Nerd Font via oh-my-posh CLI
7. **Windows Updates** (Windows only): `Install-WindowsUpdates.ps1` runs OS and app updates
8. **Time Zone**: `Set-TimeZone.ps1` sets time zone from profile (e.g., "Pacific Standard Time")
9. **Windows Terminal**: `Configure-WindowsTerminal.ps1` sets PowerShell 7 as default, configures font
10. **Profile Installation**: `Install-ProfileFiles.ps1` downloads profile and script files (overwrites existing)
11. **Target directory**: `$PROFILE.CurrentUserAllHosts` parent directory (Windows: `~/Documents/PowerShell/`, macOS: `~/.config/powershell/`)
12. **Auto-reload**: Attempts to source the profile immediately after installation

**Parameters**:
- `-Profile <name>`: Install software from a specific profile (default: from `install-config.json` defaultProfile)
- `-No-Install`: Skip software installation, Windows Updates, and Visual Studio - only install profile files, fonts, and terminal config

**Note**: The script is designed for cloud installation. When executed via one-liner (iex/irm), all files are downloaded directly from Azure Blob Storage with cache-busting timestamps.

## Profile Architecture

Both profile files use identical initialization pattern:
```powershell
# Initialize PowerShell profile using script-based architecture
# No module caching issues - scripts are always fresh
$initScript = Join-Path $PSScriptRoot "Scripts/Profile/Initialize-PowerShellProfile.ps1"
& $initScript
```

`Initialize-PowerShellProfile.ps1`:
- Adds `~/bin` to PATH for git extensions
- Calls `Install-ModuleIfMissing.ps1` for Terminal-Icons and posh-git
- Sets PSReadLine tab completion to `MenuComplete`
- Initializes Oh My Posh with `omp.json` config
- Calls `Set-DefaultWorkingDirectory.ps1` to navigate to `~/code`
- Defines custom commands as functions (wrapping scripts in Scripts/Profile/)
- Displays available custom commands via `Show-Commands`

## Available Custom Commands

After profile loads, these commands are available:

| Command | Description |
|---------|-------------|
| `Get-GitBranches` | Retrieves unique local and remote git branches |
| `Get-Software` | Lists user-installed software (excludes system packages) |
| `New-Profile` | Creates a new software profile from installed software |
| `Get-Profiles` | Lists all available profiles from Azure |
| `Get-Profile` | Gets details of a specific profile |
| `Set-Profile` | Modifies an existing profile |
| `Remove-Profile` | Deletes a profile from Azure |
| `Install-Profile` | Installs software from a profile |
| `Publish-Profile` | Uploads a profile to Azure |
| `Invoke-Installer` | Re-runs the full installation |
| `Show-Commands` | Displays this help message |

## Script Organization

### Scripts/Core/
- **`Get-PlatformInfo.ps1`**: Detects OS and returns platform object with IsWindows/IsMacOS properties

### Scripts/Utils/
- **`Get-FileFromAzure.ps1`**: Downloads file from Azure Blob Storage with cache-busting
- **`Get-ConfigFromAzure.ps1`**: Loads configuration from local file or Azure

### Scripts/Install/
- **`Install-WithWinGet.ps1`**: Installs package using winget (Windows), checks if already installed
- **`Install-WithBrew.ps1`**: Installs package using Homebrew (macOS), updates environment
- **`Install-Software.ps1`**: Orchestrates software installation from profile, delegates to platform-specific installers
- **`Install-VisualStudio.ps1`**: Installs Visual Studio 2026 Enterprise with all workloads (Windows only)
- **`Install-Fonts.ps1`**: Installs fonts via oh-my-posh CLI
- **`Install-WindowsUpdates.ps1`**: Installs Windows OS updates (PSWindowsUpdate) and app updates (winget upgrade)
- **`Set-TimeZone.ps1`**: Sets system time zone from profile configuration
- **`Configure-WindowsTerminal.ps1`**: Sets PowerShell 7 as default profile, configures Meslo font, sets as default terminal

### Scripts/Profile/
- **`Install-ProfileFiles.ps1`**: Downloads and installs profile files and scripts
- **`Initialize-PowerShellProfile.ps1`**: Main profile initialization script
- **`Install-ModuleIfMissing.ps1`**: Installs PowerShell module if not present, forces reload
- **`Get-GitBranches.ps1`**: Retrieves unique local and remote git branches (strips `origin/` prefix)
- **`Set-DefaultWorkingDirectory.ps1`**: Navigates to default directory if in $HOME
- **`Get-Software.ps1`**: Lists user-installed software, filtering out system/dependency packages
- **`New-Profile.ps1`**: Creates a software profile from currently installed software
- **`Get-Profiles.ps1`**: Lists all available profiles from Azure profiles-index.json
- **`Get-Profile.ps1`**: Gets details of a specific profile from Azure
- **`Set-Profile.ps1`**: Modifies an existing profile
- **`Remove-Profile.ps1`**: Deletes a profile from Azure
- **`Install-Profile.ps1`**: Downloads and installs software from a profile
- **`Publish-Profile.ps1`**: Uploads a profile to Azure and updates profiles-index.json
- **`Invoke-Installer.ps1`**: Re-runs the full cloud installer

## Oh My Posh Theme Structure

`omp.json` defines a two-line prompt:
1. **Line 1**: Current directory path (green, full path style)
2. **Line 2**: Git branch and status indicators + lambda prompt character (orange)
   - Staging changes: green dot + count
   - Working changes: orange dot + count

## Configuration File Structure

`install-config.json` defines profile files and scripts to install:

```json
{
  "profileFiles": ["Microsoft.PowerShell_profile.ps1", "Microsoft.VSCode_profile.ps1", "omp.json"],
  "scriptFiles": ["Scripts/Core/...", "Scripts/Install/...", "Scripts/Profile/..."],
  "defaultProfile": "default",
  "fonts": [{ "name": "Meslo Nerd Font", "installCommand": "oh-my-posh font install meslo" }]
}
```

## Software Profile Structure

Software profiles are stored in `profiles/<name>.json`:

```json
{
  "name": "default",
  "description": "Default development environment",
  "createdAt": "2026-01-22T19:00:00Z",
  "updatedAt": "2026-01-22T19:00:00Z",
  "timezone": "Pacific Standard Time",
  "software": {
    "windows": ["Microsoft.PowerShell", "Git.Git", "JanDeDobbeleer.OhMyPosh", "Microsoft.VisualStudioCode", "VisualStudio2026"],
    "macos": {
      "formulae": ["git", "oh-my-posh"],
      "casks": ["powershell", "visual-studio-code"]
    }
  }
}
```

**Profile Management**:
- `profiles-index.json`: Index of all available profiles with name, description, and updatedAt
- Profiles are uploaded to Azure via `Publish-Profile` command
- `New-Profile` captures currently installed software into a new profile

## Script Design Principles

**SOLID**: Each script has a single, well-defined responsibility
**DRY**: Shared functionality in reusable scripts (e.g., `Get-FileFromAzure.ps1`)
**YAGNI**: No unnecessary abstraction or complexity
**Idempotent**: Scripts check state and skip work if already done

**Parameter-based**: All scripts accept parameters for flexibility and testability
**No side effects**: Scripts don't modify global state except where explicitly intended
**Error handling**: `$ErrorActionPreference = 'Stop'` for fail-fast behavior
**Cache-busting**: All Azure downloads include timestamp query parameter

## Platform-Specific Patterns

**Detection**: `Get-PlatformInfo.ps1` returns object with `OS`, `IsWindows`, `IsMacOS` properties

**Package managers**:
- **macOS**: `brew install --cask powershell` (handles both Homebrew paths: `/opt/homebrew/bin` and `/usr/local/bin`)
- **Windows**: `winget install -e --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements`

**Path handling**: Always use `Join-Path` for cross-platform compatibility, never string concatenation

## One-Line Installation Commands

**Windows (PowerShell - Run as Administrator):**
```powershell
iex (irm https://stprofilewus3.blob.core.windows.net/profile-config/bootstrap.ps1)
```

The bootstrap script detects PowerShell version, installs PowerShell 7+ if needed, then runs the full installer.

**macOS (Terminal):**
```bash
pwsh -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://stprofilewus3.blob.core.windows.net/profile-config/install.ps1)"
```

These commands:
1. Download the installation script from Azure Blob Storage
2. Install required software from the default profile
3. Configure fonts, Windows Terminal (on Windows), and profile files
4. Load the profile with all modules and themes

**Requirements**: Azure Blob Storage container must have anonymous read access enabled for public installation.

## Testing and Debugging

- **Cloud install test**: `pwsh -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://stprofilewus3.blob.core.windows.net/profile-config/install.ps1)"`
- **Profile-only install**: `./install.ps1 -No-Install`
- **Specific profile**: `./install.ps1 -Profile "my-workstation"`
- **Profile reload**: `. $PROFILE.CurrentUserAllHosts` sources the current user profile
- **List available profiles**: `Get-Profiles`
- **Create new profile**: `New-Profile -Name "my-setup" -Description "My dev environment"`

## Conventions

- **Error handling**: Use `-ErrorAction SilentlyContinue` for existence checks, `$ErrorActionPreference = 'Stop'` for operations
- **Output coloring**: Green for success, Yellow for warnings, Red for errors, Cyan for informational
- **Script parameters**: Use `[CmdletBinding()]` and `[Parameter(Mandatory)]` for required parameters
- **Script invocation**: Use `& $scriptPath -Param1 $value1` for executing scripts with parameters
- **Return values**: Scripts return objects or primitives, not Write-Output (side-effect free)

## Common Development Tasks

**Adding new profile functionality**: Create new script in `Scripts/Profile/`, add function wrapper in `Initialize-PowerShellProfile.ps1`, add to `scriptFiles` in `install-config.json`

**Adding new installation feature**: Create script in `Scripts/Install/` with parameters, update `install.ps1` to call it, add to `ScriptsToDownload` in install.ps1

**Modifying theme**: Edit `omp.json` segments (path, git, text) - see Oh My Posh schema at https://ohmyposh.dev/docs/configuration/overview

**Adding scripts**: Create new `.ps1` file, add to `install-config.json` scriptFiles array, upload via `upload.ps1`

**Creating a new software profile**:
1. Install desired software manually
2. Run `New-Profile -Name "my-profile" -Description "My setup"`
3. Run `Publish-Profile -Name "my-profile"` to upload to Azure

**Uploading changes**: Run `./upload.ps1` to recursively upload all repository files (except .git and README.md) to Azure
