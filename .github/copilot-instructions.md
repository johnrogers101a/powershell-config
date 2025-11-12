# PowerShell Profile Configuration - AI Coding Agent Instructions

## Project Overview

This is a **PowerShell profile configuration system for Windows and macOS** that installs custom profiles, modules, Oh My Posh theming, and required software. Key architecture:

- **SOLID Design**: Object-oriented with clear separation of concerns
- **JSON Configuration**: Modular `install-config.json` drives software installation
- **Two deployment modes**: Cloud install (downloads from Azure Blob Storage) and local install
- **Profile files**: `Microsoft.PowerShell_profile.ps1` (main console) and `Microsoft.VSCode_profile.ps1` (VS Code terminal)
- **Custom module**: `Modules/ProfileSetup/ProfileSetup.psm1` provides initialization functions
- **Theme config**: `omp.json` defines Oh My Posh prompt appearance

## Critical Installation Flow

`install.ps1` orchestrates the entire installation using class-based architecture:

1. **Platform Detection**: `PlatformInfo` class detects Windows or macOS (Linux not supported)
2. **Configuration Loading**: `FileManager` loads `install-config.json` (local or from Azure)
3. **Software Installation**: `SoftwareInstaller` installs PowerShell, Git, and Oh My Posh via platform-specific package managers
4. **Font Installation**: Installs Meslo Nerd Font via oh-my-posh CLI
5. **Profile Installation**: `ProfileInstaller` downloads and installs profile files
6. **Backup strategy**: Existing files backed up with timestamp suffix (e.g., `filename.backup.20231115_143022`)
7. **Target directory**: `$PROFILE.CurrentUserAllHosts` parent directory (Windows: `~/Documents/PowerShell/`, macOS: `~/.config/powershell/`)
8. **Auto-reload**: Attempts to source the profile immediately after installation

**Note**: The script is designed for cloud installation. When executed via one-liner (iex/irm), all files are downloaded directly from Azure Blob Storage.

## Profile Architecture

Both profile files use identical initialization pattern:
```powershell
Import-Module $PSScriptRoot/Modules/ProfileSetup
Initialize-PowerShellProfile
```

`Initialize-PowerShellProfile` (in `ProfileSetup.psm1`):
- Adds `~/bin` to PATH for git extensions
- Installs Terminal-Icons and posh-git modules if missing
- Sets PSReadLine tab completion to `MenuComplete`
- Initializes Oh My Posh with `omp.json` config
- Sets working directory to `~/code` if starting from `$HOME`

## Key Module Functions

In `Modules/ProfileSetup/ProfileSetup.psm1`:

- `Install-ModuleIfMissing`: Installs and imports PowerShell modules on-demand
- `Get-GitBranches`: Retrieves unique local and remote git branches (strips `origin/` prefix)
- `Test-GitSwitchCommand`: Pattern matches git switch/checkout commands for tab completion
- `Set-DefaultWorkingDirectory`: Navigates to `~/code` if in home directory

## Oh My Posh Theme Structure

`omp.json` defines a two-line prompt:
1. **Line 1**: Current directory path (green, full path style)
2. **Line 2**: Git branch and status indicators + lambda prompt character (orange)
   - Staging changes: green dot + count
   - Working changes: orange dot + count

## Class Architecture

The installer uses PowerShell classes following SOLID principles:

- **`PlatformInfo`**: Detects OS (Windows/macOS only), throws error for unsupported platforms
- **`FileManager`**: Handles Azure downloads, local file operations, config loading, backups
- **`PackageManagerBase`**: Abstract base class for package manager implementations
  - **`WinGetManager`**: Windows package management via winget
  - **`BrewManager`**: macOS package management via Homebrew
- **`SoftwareInstaller`**: Orchestrates software installation, checks for existing installs (idempotency)
- **`ProfileInstaller`**: Installs profile files and modules
- **`InstallationOrchestrator`**: Top-level coordinator, owns all dependencies

## Configuration File Structure

`install-config.json` defines all installation behavior:

```json
{
  "software": {
    "windows": [{ "name", "command", "packageManager", "packageId", "installArgs" }],
    "macos": [{ "name", "command", "packageManager", "packageId", "installArgs", "isCask" }]
  },
  "profileFiles": ["file1.ps1", "file2.ps1"],
  "moduleFiles": ["Modules/Module1/Module1.psm1"],
  "fonts": [{ "name", "installCommand" }]
}
```

## Platform-Specific Patterns

**Detection idiom**: Use `$IsMacOS` and `$IsWindows` built-in variables in `PlatformInfo` class

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
- **Backup recovery**: Timestamped backups in profile directory can be restored by removing `.backup.YYYYMMDD_HHMMSS` suffix

## Conventions

- **Error handling**: Use `-ErrorAction SilentlyContinue` for existence checks, never suppress errors on actual operations
- **Output coloring**: Green for success, Yellow for warnings, Red for errors, Cyan for informational
- **Backup naming**: `{filename}.backup.{timestamp}` where timestamp is `yyyyMMdd_HHmmss`
- **Module exports**: Explicitly export functions with `Export-ModuleMember -Function @(...)`
- **Parameter validation**: Use `[Parameter(Mandatory)]` for required parameters, provide defaults for optional ones

## Common Development Tasks

**Adding new profile functionality**: Extend `Initialize-PowerShellProfile` or add new exported functions to `ProfileSetup.psm1`

**Modifying theme**: Edit `omp.json` segments (path, git, text) - see Oh My Posh schema at https://ohmyposh.dev/docs/configuration/overview

**Adding Azure files**: Upload new files to Azure Blob Storage, then update `install-config.json` configuration
