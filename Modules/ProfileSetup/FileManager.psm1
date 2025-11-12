class FileManager {
    [string]$AzureBaseUrl

    FileManager([string]$baseUrl) {
        $this.AzureBaseUrl = $baseUrl
    }

    [bool] DownloadFile([string]$fileName, [string]$destinationPath) {
        Write-Host "  Downloading $fileName..." -ForegroundColor Cyan
        try {
            $url = "$($this.AzureBaseUrl)/$fileName"
            
            # Ensure the directory exists
            $parentDir = Split-Path -Parent $destinationPath
            if ($parentDir -and -not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            
            Invoke-WebRequest -Uri $url -OutFile $destinationPath -ErrorAction Stop
            Write-Host "    Downloaded successfully" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "    Failed to download: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    [void] BackupFile([string]$filePath) {
        if (Test-Path $filePath) {
            $backupPath = "$filePath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Write-Host "  Backing up existing $(Split-Path -Leaf $filePath)..." -ForegroundColor Yellow
            Copy-Item -Path $filePath -Destination $backupPath -Force
        }
    }

    [PSCustomObject] LoadConfiguration([string]$configPath, [string]$configFileName) {
        if (Test-Path $configPath) {
            Write-Host "Loading configuration from local file..." -ForegroundColor Cyan
            return Get-Content $configPath -Raw | ConvertFrom-Json
        }
        else {
            Write-Host "Downloading configuration from Azure..." -ForegroundColor Cyan
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
