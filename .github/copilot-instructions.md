# PowerShell Profile Configuration - AI Coding Agent Instructions

## Project Overview

This is a **PowerShell profile configuration system for Windows and macOS** that installs custom profiles, scripts, Oh My Posh theming, and required software. Key architecture:

- **Script-Based Architecture**: Individual PowerShell scripts with parameters (no modules = no caching issues)
- **SOLID, DRY, YAGNI, Idempotent**: Single responsibility scripts, reusable functions, no unnecessary complexity, safe to run multiple times
- **JSON Configuration**: Modular `install-config.json` drives software and script installation
- **Cloud deployment**: Downloads from Azure Blob Storage with cache-busting
- **Profile files**: `Microsoft.PowerShell_profile.ps1` (main console) and `Microsoft.VSCode_profile.ps1` (VS Code terminal)
- **Script organization**: `Scripts/` directory with Core/, Install/, Profile/, Utils/ subdirectories
- **Theme config**: `omp.json` defines Oh My Posh prompt appearance

## Critical Installation Flow

`install.ps1` orchestrates the entire installation using script-based architecture:

1. **Bootstrap**: Downloads core installation scripts to temp directory with cache-busting
2. **Platform Detection**: `Get-PlatformInfo.ps1` returns platform object (Windows/macOS only, Linux not supported)
3. **Configuration Loading**: `Get-ConfigFromAzure.ps1` loads `install-config.json` (local or from Azure)
4. **Software Installation**: `Install-Software.ps1` delegates to `Install-WithWinGet.ps1` or `Install-WithBrew.ps1`
5. **Visual Studio**: `Install-VisualStudio.ps1` installs VS 2026 Enterprise on Windows only
6. **Font Installation**: `Install-Fonts.ps1` installs Meslo Nerd Font via oh-my-posh CLI
7. **Profile Installation**: `Install-ProfileFiles.ps1` downloads profile and script files (overwrites existing)
8. **Target directory**: `$PROFILE.CurrentUserAllHosts` parent directory (Windows: `~/Documents/PowerShell/`, macOS: `~/.config/powershell/`)
9. **Auto-reload**: Attempts to source the profile immediately after installation

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
- Displays available custom commands

## Script Organization

### Scripts/Core/
- **`Get-PlatformInfo.ps1`**: Detects OS and returns platform object with IsWindows/IsMacOS properties

### Scripts/Utils/
- **`Get-FileFromAzure.ps1`**: Downloads file from Azure Blob Storage with cache-busting
- **`Get-ConfigFromAzure.ps1`**: Loads configuration from local file or Azure

### Scripts/Install/
- **`Install-WithWinGet.ps1`**: Installs package using winget (Windows), checks if already installed
- **`Install-WithBrew.ps1`**: Installs package using Homebrew (macOS), updates environment
- **`Install-Software.ps1`**: Orchestrates software installation, delegates to platform-specific installers
- **`Install-VisualStudio.ps1`**: Installs Visual Studio 2026 Enterprise with all workloads (Windows only)
- **`Install-Fonts.ps1`**: Installs fonts via oh-my-posh CLI

### Scripts/Profile/
- **`Install-ProfileFiles.ps1`**: Downloads and installs profile files and scripts
- **`Initialize-PowerShellProfile.ps1`**: Main profile initialization script
- **`Install-ModuleIfMissing.ps1`**: Installs PowerShell module if not present, forces reload
- **`Get-GitBranches.ps1`**: Retrieves unique local and remote git branches (strips `origin/` prefix)
- **`Set-DefaultWorkingDirectory.ps1`**: Navigates to default directory if in $HOME

## Oh My Posh Theme Structure

`omp.json` defines a two-line prompt:
1. **Line 1**: Current directory path (green, full path style)
2. **Line 2**: Git branch and status indicators + lambda prompt character (orange)
   - Staging changes: green dot + count
   - Working changes: orange dot + count

## Configuration File Structure

`install-config.json` defines all installation behavior:

```json
{
  "software": {
    "windows": [{ "name", "command", "packageManager", "packageId", "installArgs" }],
    "macos": [{ "name", "command", "packageManager", "packageId", "installArgs", "isCask" }]
  },
  "profileFiles": ["Microsoft.PowerShell_profile.ps1", "Microsoft.VSCode_profile.ps1", "omp.json"],
  "scriptFiles": ["Scripts/Core/...", "Scripts/Install/...", "Scripts/Profile/..."],
  "fonts": [{ "name", "installCommand" }]
}
```

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

**Windows (PowerShell):**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://stprofilewus3.blob.core.windows.net/profile-config/install.ps1'))
```

**macOS (Terminal):**
```bash
pwsh -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://stprofilewus3.blob.core.windows.net/profile-config/install.ps1)"
```

These commands:
1. Set appropriate security settings for script execution
2. Download the installation script from Azure Blob Storage
3. Execute the script which handles software and profile installation
4. Configure the profile with all modules and themes

**Requirements**: Azure Blob Storage container must have anonymous read access enabled for public installation.

## Testing and Debugging

- **Cloud install test**: `pwsh -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://stprofilewus3.blob.core.windows.net/profile-config/install.ps1)"`
- **Profile reload**: `. $PROFILE.CurrentUserAllHosts` sources the current user profile
- **Module testing**: `Import-Module ./Modules/ProfileSetup -Force` reloads the module

## Conventions

- **Error handling**: Use `-ErrorAction SilentlyContinue` for existence checks, `$ErrorActionPreference = 'Stop'` for operations
- **Output coloring**: Green for success, Yellow for warnings, Red for errors, Cyan for informational
- **Script parameters**: Use `[CmdletBinding()]` and `[Parameter(Mandatory)]` for required parameters
- **Script invocation**: Use `& $scriptPath -Param1 $value1` for executing scripts with parameters
- **Return values**: Scripts return objects or primitives, not Write-Output (side-effect free)

## Common Development Tasks

**Adding new profile functionality**: Create new script in `Scripts/Profile/` and update `Initialize-PowerShellProfile.ps1` to call it

**Adding new installation feature**: Create script in `Scripts/Install/` with parameters, update `install.ps1` to call it

**Modifying theme**: Edit `omp.json` segments (path, git, text) - see Oh My Posh schema at https://ohmyposh.dev/docs/configuration/overview

**Adding scripts**: Create new `.ps1` file, add to `install-config.json` scriptFiles array, upload via `upload.ps1`

**Uploading changes**: Run `./upload.ps1` to recursively upload all repository files (except .git and README.md) to Azure
