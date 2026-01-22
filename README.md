# PowerShell Profile Configuration

A cross-platform PowerShell profile configuration with custom modules and Oh My Posh theming for Windows and macOS. 🚀

## Features

- 🚀 **Automated Installation** - One-line install for Windows and macOS with cache busting
- 📦 **Software Management** - Automatically installs PowerShell, Git, Oh My Posh, VS Code, and VS 2026 Enterprise
- 🎨 **Oh My Posh Theming** - Beautiful terminal prompt with git integration
- 🔤 **Nerd Fonts** - Automatic Meslo Nerd Font installation
- 🔄 **Auto-Sync** - GitHub Actions automatically syncs changes to Azure
- ⚙️ **Modular Configuration** - JSON-driven installation config
- � **Force Reload** - Always gets the latest code (no backups)
- 🔄 **Idempotent** - Run multiple times safely

## Quick Installation

### Cloud Install (Recommended)

**Simple one-liner installation - just copy and paste!**

> **Note:** Make sure your Azure Blob Storage container has anonymous read access enabled for public installation.

#### Windows (PowerShell 5.1 or later)

> **Important:** Run Windows Terminal as **Administrator** for the installation to succeed.

```powershell
iex (irm https://stprofilewus3.blob.core.windows.net/profile-config/bootstrap.ps1)
```

**Works on fresh Windows installs!** The bootstrap script will:
- Detect your PowerShell version
- Install PowerShell 7+ if you're on PowerShell 5.x
- Run the full installer in PowerShell 7+

#### macOS (Terminal - requires PowerShell 7+)
```bash
pwsh -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://stprofilewus3.blob.core.windows.net/profile-config/install.ps1)"
```

**Don't have PowerShell on macOS?** Install it first:
```bash
brew install --cask powershell
```

---

### Local Installation (If You Have the Files)

Copy and paste the appropriate command for your operating system:

#### macOS
```bash
command -v pwsh >/dev/null 2>&1 || (brew install --cask powershell && eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null); pwsh -NoProfile -ExecutionPolicy Bypass -Command "Set-Location '$(pwd)'; & './install.ps1'"
```

#### Windows (Command Prompt)
```cmd
pwsh -NoProfile -ExecutionPolicy Bypass -Command "if (!(Get-Command pwsh -ErrorAction SilentlyContinue)) { winget install -e --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements }; Set-Location '%CD%'; & '.\install.ps1'"
```

#### Windows (PowerShell)
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "if (!(Get-Command pwsh -ErrorAction SilentlyContinue)) { winget install -e --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements }; Set-Location '$PWD'; & '.\install.ps1'"
```

## What Gets Installed

### Software (automatically installed if not present)
- **PowerShell** - Latest version via winget (Windows) or Homebrew (macOS)
- **Git** - Version control system
- **Oh My Posh** - Terminal prompt theming engine
- **Visual Studio Code** - Code editor
- **Visual Studio 2026 Enterprise** - Full IDE with all workloads (Windows only)
- **Meslo Nerd Font** - Required for prompt icons and symbols

### Configuration Files
- `Microsoft.PowerShell_profile.ps1` - Main PowerShell profile
- `Microsoft.VSCode_profile.ps1` - VS Code integrated terminal profile
- `omp.json` - Oh My Posh theme configuration
- `Modules/ProfileSetup/` - Custom PowerShell module
- `install-config.json` - Modular installation configuration

## Manual Installation

If you already have PowerShell installed, simply run:

```powershell
# Full installation (software, updates, and profile)
./install.ps1

# Profile-only installation (skip software, updates, and Visual Studio)
./install.ps1 -No-Install
```

### Installation Parameters

| Parameter | Description |
|-----------|-------------|
| `-No-Install` | Skips software installation, Windows Updates, and Visual Studio installation. Only installs profile files, fonts, and terminal configuration. |

## What It Does

The installation script follows SOLID principles and provides:

1. **Software Installation** - Installs PowerShell, Git, Oh My Posh, and Visual Studio 2026 Enterprise (Windows only) if not present
2. **Font Installation** - Installs Meslo Nerd Font via Oh My Posh
3. **Profile Configuration** - Overwrites profile files in your PowerShell directory (no backups)
4. **Module Setup** - Force reloads custom PowerShell modules to ensure latest code
5. **Idempotent** - Can be run multiple times safely (skips already-installed software)
6. **Automatic Loading** - Loads the new profile immediately

## Architecture

The installer uses a modular, object-oriented design following SOLID principles:

- **Single Responsibility** - Each class handles one concern (Platform detection, File operations, Package management, etc.)
- **Open/Closed** - Easy to extend with new package managers or platforms
- **Liskov Substitution** - Package managers are interchangeable via base class
- **Dependency Inversion** - High-level orchestrator depends on abstractions
- **DRY** - Configuration externalized to JSON, no code duplication
- **YAGNI** - Only implements what's needed for Windows and macOS
- **Idempotency** - Checks before installing, safe to run repeatedly

## File Locations

After installation, files will be located at:

- **Windows**: `$HOME\Documents\PowerShell\`
- **macOS**: `~/.config/powershell/`

## Uploading Updates

If you make changes to the profile files and want to update the cloud version:

```powershell
./upload.ps1
```

This will upload all files to Azure Blob Storage. Make sure you're logged into Azure CLI first:
```powershell
az login
```

## For Maintainers

### Uploading Changes to Azure

After making changes to the profile configuration, upload the updated files to Azure Blob Storage:

```powershell
./upload.ps1
```

**Requirements:**
- Azure CLI installed (`az`)
- Authenticated to Azure (`az login`)
- Appropriate permissions on the storage account

The script will:
- Upload all profile files and modules to Azure Blob Storage
- Overwrite existing files
- Verify container public access settings

## Uninstall

To remove the configuration, delete the installed files from your PowerShell profile directory.

## Requirements

### For Cloud Installation
- Internet connection to Azure Blob Storage
- **Windows**: PowerShell or Command Prompt (winget will be used)
- **macOS**: Terminal with bash/zsh (Homebrew will be used)

### For Local Installation
- PowerShell 7.0+ (script can install it if missing)
- **Windows**: winget package manager (included in Windows 11, Windows 10 requires App Installer)
- **macOS**: Homebrew package manager

## Configuration

The `install-config.json` file drives the entire installation process:

```json
{
  "software": {
    "windows": [...],  // Software to install on Windows
    "macos": [...]     // Software to install on macOS
  },
  "profileFiles": [...],  // Profile files to install
  "moduleFiles": [...],   // Modules to install
  "fonts": [...]          // Fonts to install via oh-my-posh
}
```

To add new software or change installation behavior, simply edit the JSON configuration.

## Troubleshooting

### Windows
- **winget not found**: Install the App Installer from the Microsoft Store
- **Execution policy errors**: The one-liner bypasses this, but for manual runs use `Set-ExecutionPolicy Bypass -Scope Process`

### macOS
- **Homebrew not found**: Install from https://brew.sh
- **Permission issues**: Make sure you have admin privileges

### Both Platforms
- **Font not displaying**: Configure your terminal to use "Meslo Nerd Font" after installation
- **Profile not loading**: Restart your terminal or run `. $PROFILE`

## Supported Platforms

- ✅ Windows 10/11
- ✅ macOS (Intel and Apple Silicon)
- ❌ Linux (not supported)

## License

Use freely and modify as needed.
