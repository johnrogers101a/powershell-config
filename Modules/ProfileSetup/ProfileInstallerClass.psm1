using module ./FileManager.psm1

# ProfileInstaller v2.0 - No backups, force overwrite
class ProfileInstaller {
    [string]$ProfileDir
    [string]$ModulesDir
    [object]$FileManager
    [PSCustomObject]$Config

    ProfileInstaller([object]$fileManager, [PSCustomObject]$config) {
        $this.ProfileDir = Split-Path -Parent $global:PROFILE.CurrentUserAllHosts
        $this.ModulesDir = Join-Path $this.ProfileDir "Modules"
        $this.FileManager = $fileManager
        $this.Config = $config
    }

    [void] Install() {
        Write-Host ""
        Write-Host "Installing profile configuration..." -ForegroundColor Green
        Write-Host "  [ProfileInstaller v2.0 - No backups, force overwrite]" -ForegroundColor Magenta
        Write-Host "Target Directory: " -NoNewline
        Write-Host $this.ProfileDir -ForegroundColor Yellow
        Write-Host ""

        # Create profile directory if it doesn't exist
        if (-not (Test-Path $this.ProfileDir)) {
            Write-Host "Creating profile directory..." -ForegroundColor Cyan
            New-Item -ItemType Directory -Path $this.ProfileDir -Force | Out-Null
        }

        # Install profile files (overwrite existing)
        Write-Host "Installing profile files..." -ForegroundColor Cyan
        foreach ($file in $this.Config.profileFiles) {
            $destPath = Join-Path $this.ProfileDir $file
            
            # Remove existing file if present
            if (Test-Path $destPath) {
                Remove-Item $destPath -Force -ErrorAction SilentlyContinue
            }
            
            $success = $this.FileManager.DownloadFile($file, $destPath)
            if (-not $success) {
                Write-Host "  Error: Failed to install $file" -ForegroundColor Red
            }
        }

        # Install modules
        Write-Host ""
        Write-Host "Installing modules..." -ForegroundColor Cyan
        foreach ($modulePath in $this.Config.moduleFiles) {
            $destPath = Join-Path $this.ProfileDir $modulePath
            $success = $this.FileManager.DownloadFile($modulePath, $destPath)
            if (-not $success) {
                Write-Host "  Error: Failed to install $modulePath" -ForegroundColor Red
            }
        }
    }

    [void] LoadProfile() {
        Write-Host ""
        Write-Host "Loading profile..." -ForegroundColor Cyan
        try {
            . $global:PROFILE.CurrentUserAllHosts
            Write-Host "Profile loaded successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host "Note: Profile will be loaded when you start a new PowerShell session." -ForegroundColor Yellow
        }
    }
}

Export-ModuleMember -Variable * -Function *
