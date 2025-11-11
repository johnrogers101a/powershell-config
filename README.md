# PowerShell Profile Configuration

A cross-platform PowerShell profile configuration with custom modules and Oh My Posh theming.

## Quick Installation

### Cloud Install (Recommended)

**Simple one-liner installation - just copy and paste!**

> **Note:** Make sure your Azure Blob Storage container has anonymous read access enabled for public installation.

#### Windows (PowerShell)
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://stprofilewus3.blob.core.windows.net/profile-config/install.ps1?v=' + (Get-Date -Format 'yyyyMMddHHmmss')))
```

#### macOS/Linux (Terminal)
```bash
pwsh -NoProfile -ExecutionPolicy Bypass -Command "iex (irm 'https://stprofilewus3.blob.core.windows.net/profile-config/install.ps1?v='(Get-Date -Format yyyyMMddHHmmss))"
```

**Don't have PowerShell installed?** The installer will detect this and install it automatically for your platform!

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

#### Linux (Ubuntu/Debian)
```bash
command -v pwsh >/dev/null 2>&1 || (sudo apt-get update && sudo apt-get install -y wget apt-transport-https software-properties-common && wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" && sudo dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb && sudo apt-get update && sudo apt-get install -y powershell); pwsh -NoProfile -ExecutionPolicy Bypass -Command "Set-Location '$(pwd)'; & './install.ps1'"
```

#### Linux (Fedora/RHEL/CentOS)
```bash
command -v pwsh >/dev/null 2>&1 || (sudo dnf install -y https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm && sudo dnf install -y powershell); pwsh -NoProfile -ExecutionPolicy Bypass -Command "Set-Location '$(pwd)'; & './install.ps1'"
```

## What Gets Installed

- `Microsoft.PowerShell_profile.ps1` - Main PowerShell profile
- `Microsoft.VSCode_profile.ps1` - VS Code integrated terminal profile
- `omp.json` - Oh My Posh theme configuration
- `Modules/ProfileSetup/` - Custom PowerShell module

## Manual Installation

If you already have PowerShell installed, simply run:

```powershell
./install.ps1
```

## What It Does

The installation script:
1. Checks if PowerShell is installed (and installs it if needed)
2. Copies profile files to your PowerShell profile directory
3. Backs up any existing profile files with timestamps
4. Creates necessary directories if they don't exist
5. Installs custom modules
6. Automatically loads the new profile

That's it! Everything is configured and ready to use.

## File Locations

After installation, files will be located at:

- **Windows**: `$HOME\Documents\PowerShell\`
- **macOS/Linux**: `~/.config/powershell/`

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

To remove the configuration, delete the installed files from your PowerShell profile directory. Timestamped backups of your original files are created during installation.

## Requirements

- PowerShell 7.0 or later (automatically installed by the one-line commands)
- Oh My Posh (if using the theme - install separately)

## Troubleshooting

If you encounter permission issues on Linux/macOS, you may need to make the script executable:

```bash
chmod +x install.ps1
```

## License

Use freely and modify as needed.
