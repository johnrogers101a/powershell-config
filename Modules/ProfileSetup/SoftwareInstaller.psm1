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

        # Check if Visual Studio is already installed (VS 2026 Enterprise)
        $vsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vsWherePath) {
            $vsInstalled = & $vsWherePath -version "[18.0,19.0)" -property productPath 2>$null
            if ($vsInstalled) {
                Write-Host "✓ Visual Studio is already installed" -ForegroundColor Green
                return
            }
        }

        Write-Host ""
        Write-Host "Installing Visual Studio 2026 Enterprise..." -ForegroundColor Yellow
        Write-Host "  This may take several minutes..." -ForegroundColor Cyan

        # Download Visual Studio 2026 bootstrapper
        $vsBootstrapperUrl = "https://aka.ms/vs/18/release/vs_enterprise.exe"
        $vsBootstrapperPath = Join-Path $env:TEMP "vs_enterprise_$(Get-Date -Format 'yyyyMMddHHmmss').exe"
        
        try {
            Write-Host "  Downloading Visual Studio installer..." -ForegroundColor Cyan
            
            # Clean up any old installers first
            Get-ChildItem -Path $env:TEMP -Filter "vs_enterprise*.exe" -ErrorAction SilentlyContinue | 
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-1) } |
                Remove-Item -Force -ErrorAction SilentlyContinue
            
            # Download with progress
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $vsBootstrapperUrl -OutFile $vsBootstrapperPath -ErrorAction Stop -UseBasicParsing
            $ProgressPreference = 'Continue'
            
            # Verify the download
            if (-not (Test-Path $vsBootstrapperPath)) {
                throw "Download failed: Installer file not found"
            }
            
            $fileSize = (Get-Item $vsBootstrapperPath).Length
            if ($fileSize -lt 1MB) {
                throw "Download failed: File size too small ($fileSize bytes)"
            }
            
            Write-Host "  ✓ Downloaded installer ($([math]::Round($fileSize/1MB, 2)) MB)" -ForegroundColor Green
            
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
            
            # Verify the file is not corrupted before running
            try {
                $fileStream = [System.IO.File]::OpenRead($vsBootstrapperPath)
                $fileStream.Close()
            }
            catch {
                throw "Installer file is corrupted or locked: $($_.Exception.Message)"
            }
            
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
        }
        finally {
            # Clean up installer
            if (Test-Path $vsBootstrapperPath) {
                Remove-Item $vsBootstrapperPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Export-ModuleMember -Variable * -Function *
