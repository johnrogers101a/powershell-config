class PackageManagerBase {
    [string]$Name
    
    PackageManagerBase([string]$name) {
        $this.Name = $name
    }

    [bool] IsAvailable() {
        return $null -ne (Get-Command $this.Name -ErrorAction SilentlyContinue)
    }

    [bool] Install([PSCustomObject]$package) {
        throw "Install method must be implemented by derived class"
    }

    [bool] IsPackageInstalled([PSCustomObject]$package) {
        return $null -ne (Get-Command $package.command -ErrorAction SilentlyContinue)
    }
}

class WinGetManager : PackageManagerBase {
    WinGetManager() : base("winget") {}

    [bool] IsPackageInstalled([PSCustomObject]$package) {
        # Use winget list to check if package is installed (fast and reliable)
        try {
            $null = winget list --id $package.packageId --exact --accept-source-agreements 2>&1
            return $LASTEXITCODE -eq 0
        }
        catch {
            # If winget fails, fall back to command check
            return $null -ne (Get-Command $package.command -ErrorAction SilentlyContinue)
        }
    }

    [bool] Install([PSCustomObject]$package) {
        Write-Host "  Installing $($package.name) via winget..." -ForegroundColor Cyan
        $result = winget install $package.installArgs 2>&1
        return $LASTEXITCODE -eq 0
    }
}

class BrewManager : PackageManagerBase {
    BrewManager() : base("brew") {}

    [bool] Install([PSCustomObject]$package) {
        Write-Host "  Installing $($package.name) via Homebrew..." -ForegroundColor Cyan
        $result = & brew @($package.installArgs) 2>&1
        return $LASTEXITCODE -eq 0
    }

    [void] UpdateEnvironment() {
        # Update PATH for current session
        if (Test-Path "/opt/homebrew/bin/brew") {
            $env:PATH = "/opt/homebrew/bin:$env:PATH"
            & /opt/homebrew/bin/brew shellenv | Invoke-Expression
        }
        elseif (Test-Path "/usr/local/bin/brew") {
            $env:PATH = "/usr/local/bin:$env:PATH"
            & /usr/local/bin/brew shellenv | Invoke-Expression
        }
    }
}

Export-ModuleMember -Variable * -Function *
