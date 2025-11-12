using module ./PlatformInfo.psm1
using module ./FileManager.psm1
using module ./SoftwareInstaller.psm1
using module ./ProfileInstallerClass.psm1

function Invoke-Install {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AzureBaseUrl,
        
        [Parameter(Mandatory)]
        [string]$TempDirectory
    )

    try {
        # Load configuration
        $configPath = Join-Path $TempDirectory "install-config.json"
        $config = Get-Content $configPath -Raw | ConvertFrom-Json

        # Initialize components
        $platform = [PlatformInfo]::new()
        $fileManager = [FileManager]::new($AzureBaseUrl)
        $softwareInstaller = [SoftwareInstaller]::new($platform, $config)
        $profileInstaller = [ProfileInstaller]::new($fileManager, $config)

        # Show header
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "PowerShell Profile Configuration Installer" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Platform: " -NoNewline
        Write-Host $platform.OS -ForegroundColor Yellow
        Write-Host "Installation Mode: " -NoNewline
        Write-Host "Cloud (Azure Blob Storage)" -ForegroundColor Yellow

        # Execute installation
        $softwareInstaller.InstallSoftware()
        $softwareInstaller.InstallVisualStudio()
        $softwareInstaller.InstallFonts()
        $profileInstaller.Install()
        $profileInstaller.LoadProfile()

        # Show footer
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Installation Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor Cyan
        Write-Host "  1. Restart your terminal or run: " -NoNewline
        Write-Host ". `$PROFILE" -ForegroundColor Yellow
        Write-Host "  2. Configure your terminal to use the Meslo Nerd Font" -ForegroundColor White
        Write-Host ""
    }
    catch {
        Write-Host ""
        Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        throw
    }
}

Export-ModuleMember -Function Invoke-Install
