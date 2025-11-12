class FileManager {
    [string]$AzureBaseUrl

    FileManager([string]$baseUrl) {
        $this.AzureBaseUrl = $baseUrl
    }

    [bool] DownloadFile([string]$fileName, [string]$destinationPath) {
        Write-Host "  Downloading $fileName..." -ForegroundColor Cyan
        try {
            # Add cache buster to URL
            $cacheBuster = "v=$(Get-Date -Format 'yyyyMMddHHmmss')"
            $url = "$($this.AzureBaseUrl)/$fileName`?$cacheBuster"
            
            # Ensure the directory exists
            $parentDir = Split-Path -Parent $destinationPath
            if ($parentDir -and -not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            
            # Force download with no cache
            Invoke-WebRequest -Uri $url -OutFile $destinationPath -ErrorAction Stop -UseBasicParsing
            Write-Host "    Downloaded successfully" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "    Failed to download: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    [PSCustomObject] LoadConfiguration([string]$configPath, [string]$configFileName) {
        if (Test-Path $configPath) {
            Write-Host "Loading configuration from local file..." -ForegroundColor Cyan
            return Get-Content $configPath -Raw | ConvertFrom-Json
        }
        else {
            Write-Host "Downloading configuration from Azure..." -ForegroundColor Cyan
            $cacheBuster = "v=$(Get-Date -Format 'yyyyMMddHHmmss')"
            $tempConfig = Join-Path $env:TEMP $configFileName
            if ($this.DownloadFile($configFileName, $tempConfig)) {
                return Get-Content $tempConfig -Raw | ConvertFrom-Json
            }
            else {
                throw "Failed to load configuration file"
            }
        }
    }
}

Export-ModuleMember -Variable * -Function *
