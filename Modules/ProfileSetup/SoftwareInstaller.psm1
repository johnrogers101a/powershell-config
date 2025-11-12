using module ./PlatformInfo.psm1
using module ./PackageManager.psm1

class SoftwareInstaller {
    [object]$Platform
    [object]$PackageManager
    [PSCustomObject]$Config

    SoftwareInstaller([object]$platform, [PSCustomObject]$config) {
        $this.Platform = $platform
        $this.Config = $config
        $this.PackageManager = $this.InitializePackageManager()
    }

    [object] InitializePackageManager() {
        if ($this.Platform.IsWindows) {
            return [WinGetManager]::new()
        }
        elseif ($this.Platform.IsMacOS) {
            return [BrewManager]::new()
        }
        return $null
    }

    [void] InstallSoftware() {
        $softwareList = $this.Config.software.($this.Platform.OS)
        
        if (-not $softwareList) {
            Write-Host "No software configuration found for $($this.Platform.OS)" -ForegroundColor Yellow
            return
        }

        Write-Host ""
        Write-Host "Checking required software..." -ForegroundColor Green
        Write-Host ""

        foreach ($package in $softwareList) {
            # Check if already installed (idempotency)
            # Pass the full package object to allow packageId-based checking
            $isInstalled = $this.PackageManager.IsPackageInstalled($package)
            
            if ($isInstalled) {
                Write-Host "✓ $($package.name) is already installed" -ForegroundColor Green
                continue
            }

            Write-Host "Installing $($package.name)..." -ForegroundColor Yellow

            # Check if package manager is available
            if (-not $this.PackageManager.IsAvailable()) {
                Write-Host "  Error: $($this.PackageManager.Name) is not available" -ForegroundColor Red
                if ($this.PackageManager.Name -eq "brew") {
                    Write-Host "  Install Homebrew: https://brew.sh" -ForegroundColor Yellow
                }
                continue
            }

            # Install the package
            $success = $this.PackageManager.Install($package)
            
            if ($success) {
                Write-Host "  ✓ $($package.name) installed successfully" -ForegroundColor Green
                
                # Update environment if using Homebrew
                if ($this.PackageManager -is [BrewManager]) {
                    $this.PackageManager.UpdateEnvironment()
                }
            }
            else {
                Write-Host "  ✗ Failed to install $($package.name)" -ForegroundColor Red
            }
        }
    }

    [void] InstallFonts() {
        # Check if oh-my-posh is available
        if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
            Write-Host "Skipping font installation (oh-my-posh not available)" -ForegroundColor Yellow
            return
        }

        Write-Host ""
        Write-Host "Installing fonts..." -ForegroundColor Green
        
        foreach ($font in $this.Config.fonts) {
            Write-Host "  Installing $($font.name)..." -ForegroundColor Cyan
            $installCmd = $font.installCommand -split ' '
            & $installCmd[0] @($installCmd[1..($installCmd.Length - 1)]) 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ $($font.name) installed successfully" -ForegroundColor Green
            }
            else {
                Write-Host "  Note: Font may already be installed or installation skipped" -ForegroundColor Yellow
            }
        }
    }

    [void] InstallVisualStudio() {
        if (-not $this.Platform.IsWindows) {
            return
        }

        # Check if Visual Studio is already installed using winget
        Write-Host "Checking for Visual Studio installation..." -ForegroundColor Cyan
        $vsCheck = winget list --id Microsoft.VisualStudio.2022.Enterprise 2>$null
        if ($LASTEXITCODE -eq 0 -and $vsCheck -match "Microsoft.VisualStudio.2022.Enterprise") {
            Write-Host "✓ Visual Studio is already installed" -ForegroundColor Green
            return
        }

        Write-Host ""
        Write-Host "Installing Visual Studio 2026 Enterprise..." -ForegroundColor Yellow
        Write-Host "  This may take several minutes..." -ForegroundColor Cyan

        # Download Visual Studio 2026 bootstrapper to user's Downloads folder (more reliable than TEMP)
        $vsBootstrapperUrl = "https://aka.ms/vs/18/release/vs_enterprise.exe"
        $downloadsPath = [Environment]::GetFolderPath('UserProfile')
        $vsBootstrapperPath = Join-Path $downloadsPath "vs_enterprise_installer.exe"
        
        try {
            # Remove existing installer if present
            if (Test-Path $vsBootstrapperPath) {
                Write-Host "  Removing existing installer..." -ForegroundColor Cyan
                Remove-Item $vsBootstrapperPath -Force -ErrorAction Stop
            }
            
            Write-Host "  Downloading Visual Studio installer..." -ForegroundColor Cyan
            Write-Host "  URL: $vsBootstrapperUrl" -ForegroundColor Gray
            Write-Host "  Destination: $vsBootstrapperPath" -ForegroundColor Gray
            
            # Download using .NET WebClient for better reliability
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($vsBootstrapperUrl, $vsBootstrapperPath)
            $webClient.Dispose()
            
            # Wait a moment for file system to sync
            Start-Sleep -Seconds 2
            
            # Verify the download completed successfully
            if (-not (Test-Path $vsBootstrapperPath)) {
                throw "Download failed: Installer file not found at $vsBootstrapperPath"
            }
            
            $fileInfo = Get-Item $vsBootstrapperPath
            $fileSize = $fileInfo.Length
            
            if ($fileSize -lt 1MB) {
                throw "Download failed: File size too small ($fileSize bytes) - expected at least 1 MB"
            }
            
            # Verify file is not corrupted by checking if it's a valid PE file
            $bytes = [System.IO.File]::ReadAllBytes($vsBootstrapperPath)
            if ($bytes.Length -lt 2 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
                throw "Downloaded file is not a valid executable (MZ header missing)"
            }
            
            Write-Host "  ✓ Downloaded installer ($([math]::Round($fileSize/1MB, 2)) MB)" -ForegroundColor Green
            Write-Host "  ✓ File integrity verified" -ForegroundColor Green
            
            # Define all workloads for a complete installation
            $workloads = @(
                "Microsoft.VisualStudio.Workload.ManagedDesktop"           # .NET desktop development
                "Microsoft.VisualStudio.Workload.NetWeb"                   # ASP.NET and web development
                "Microsoft.VisualStudio.Workload.Azure"                    # Azure development
                "Microsoft.VisualStudio.Workload.Data"                     # Data storage and processing
                "Microsoft.VisualStudio.Workload.Python"                   # Python development
                "Microsoft.VisualStudio.Workload.Node"                     # Node.js development
                "Microsoft.VisualStudio.Workload.Universal"                # Universal Windows Platform development
                "Microsoft.VisualStudio.Workload.NativeDesktop"            # Desktop development with C++
                "Microsoft.VisualStudio.Workload.NativeMobile"             # Mobile development with C++
                "Microsoft.VisualStudio.Workload.ManagedGame"              # Game development with Unity
                "Microsoft.VisualStudio.Workload.NativeGame"               # Game development with C++
                "Microsoft.VisualStudio.Workload.VisualStudioExtension"    # Visual Studio extension development
                "Microsoft.VisualStudio.Workload.Office"                   # Office/SharePoint development
                "Microsoft.VisualStudio.Workload.NetCrossPlat"             # .NET Multi-platform App UI development
            )
            
            # Build the install arguments
            $installArgs = @(
                "--quiet"
                "--norestart"
                "--wait"
                "--nocache"
            )
            
            # Add all workloads
            foreach ($workload in $workloads) {
                $installArgs += "--add"
                $installArgs += $workload
            }
            
            Write-Host "  Installing Visual Studio with all workloads..." -ForegroundColor Cyan
            Write-Host "  (This will run silently in the background)" -ForegroundColor Yellow
            
            # Run the installer with error handling
            $process = Start-Process -FilePath $vsBootstrapperPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop
            
            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                Write-Host "  ✓ Visual Studio installed successfully" -ForegroundColor Green
                if ($process.ExitCode -eq 3010) {
                    Write-Host "  Note: A restart may be required to complete the installation" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "  ✗ Visual Studio installation failed (Exit code: $($process.ExitCode))" -ForegroundColor Red
                Write-Host "  Common exit codes: -1 (error), -2147205120 (admin required), 740 (elevation required)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  ✗ Failed to install Visual Studio: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Installer location: $vsBootstrapperPath" -ForegroundColor Yellow
            Write-Host "  You can try running the installer manually if needed" -ForegroundColor Yellow
        }
        finally {
            # Clean up installer only if installation succeeded
            if (Test-Path $vsBootstrapperPath) {
                Write-Host "  Cleaning up installer..." -ForegroundColor Cyan
                Start-Sleep -Seconds 1
                Remove-Item $vsBootstrapperPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Export-ModuleMember -Variable * -Function *
